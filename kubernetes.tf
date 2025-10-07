data "google_client_config" "default" {}

provider "kubernetes" {
  host                   = "https://${google_container_cluster.primary.endpoint}"
  token                  = data.google_client_config.default.access_token
  cluster_ca_certificate = base64decode(google_container_cluster.primary.master_auth[0].cluster_ca_certificate)
}

resource "kubernetes_namespace" "qwen" {
  depends_on = [google_container_cluster.primary]

  metadata {
    name = local.name_prefix
  }
}

resource "kubernetes_persistent_volume_claim" "model_cache" {
  depends_on = [kubernetes_namespace.qwen]

  metadata {
    name      = local.pvc_name
    namespace = local.name_prefix
  }
  spec {
    access_modes = ["ReadWriteOnce"]
    resources {
      requests = {
        storage = var.model_cache_size # "2000Gi"
      }
    }
    storage_class_name = "premium-rwo"
  }

  wait_until_bound = false
}
resource "kubernetes_service" "vllm" {
  depends_on = [kubernetes_namespace.qwen]

  metadata {
    name      = local.service_name
    namespace = local.name_prefix
  }
  spec {
    selector = {
      app = local.app_label
    }
    port {
      port        = 8000
      target_port = 8000
    }
    # Expose the service internally. The GKE Ingress will route traffic to this service.
    type = "ClusterIP"
  }
}

resource "kubernetes_config_map" "validate_cache_script" {
  metadata {
    name      = "${local.name_prefix}-validate-cache-script"
    namespace = local.name_prefix
  }
  data = {
    "validate-cache.sh" = file("${path.module}/scripts/validate-cache.sh")
  }
}

resource "kubernetes_deployment" "vllm" {
  depends_on = [
    kubernetes_namespace.qwen,
    kubernetes_secret.hf_token,
    kubernetes_persistent_volume_claim.model_cache,
  ]

  timeouts {
    create = "20m"
    update = "20m"
    delete = "20m"
  }

  metadata {
    name      = local.deployment_name
    namespace = local.name_prefix
    labels = {
      app = local.app_label
    }
  }
  spec {
    replicas = 0
    strategy {
      type = "Recreate"
    }
    selector {
      match_labels = {
        app = local.app_label
      }
    }
    template {
      metadata {
        labels = {
          app = local.app_label
        }
      }
      spec {
        node_selector = {
          "cloud.google.com/gke-accelerator" = local.gpu_config.accelerator_type
        }
        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "${local.gpu_config.accelerator_type}-spot"
          effect   = "NoSchedule"
        }
        toleration {
          key      = "dedicated"
          operator = "Equal"
          value    = "${local.gpu_config.accelerator_type}-ondemand"
          effect   = "NoSchedule"
        }
        affinity {
          node_affinity {
            preferred_during_scheduling_ignored_during_execution {
              weight = 100
              preference {
                match_expressions {
                  key      = "cloud.google.com/gke-spot"
                  operator = "In"
                  values   = ["true"]
                }
              }
            }
          }
        }
        init_container {
          name    = "validate-model-cache"
          image   = "busybox:1.36"
          command = ["/bin/sh", "-c"]
          args    = ["/validate-cache.sh"]

          resources {
            requests = {
              cpu    = local.kubernetes_resources.init_container.requests.cpu
              memory = local.kubernetes_resources.init_container.requests.memory
            }
            limits = {
              cpu    = local.kubernetes_resources.init_container.limits.cpu
              memory = local.kubernetes_resources.init_container.limits.memory
            }
          }

          env {
            name  = "MODEL_ID"
            value = var.model_id
          }
          env {
            name  = "ENABLE_SPECULATIVE_DECODING"
            value = tostring(var.enable_speculative_decoding)
          }
          env {
            name  = "SPECULATIVE_MODEL_ID"
            value = var.speculative_model_id
          }

          volume_mount {
            name       = "model-cache"
            mount_path = "/root/.cache/huggingface"
          }
          volume_mount {
            name       = "validate-script"
            mount_path = "/validate-cache.sh"
            sub_path   = "validate-cache.sh"
          }
        }
        container {
          name  = "vllm-container"
          image = "vllm/vllm-openai:v0.11.0"
          dynamic "env" {
            for_each = local.vllm_env_vars_simple
            content {
              name  = env.value.name
              value = env.value.value
            }
          }
          dynamic "env" {
            for_each = local.vllm_env_vars_secret
            content {
              name = env.value.name

              value_from {
                secret_key_ref {
                  name = env.value.value_from.secret_key_ref.name
                  key  = env.value.value_from.secret_key_ref.key
                }
              }
            }
          }
          args = compact([
            # --- Base Model Arguments ---
            "--model",
            var.model_id,
            "--tensor-parallel-size",
            tostring(local.gpu_config.accelerator_count),
            "--gpu-memory-utilization",
            tostring(var.gpu_memory_utilization),
            "--max-model-len",
            tostring(var.max_model_len),

            # --- Performance Tuning from Variables ---
            "--dtype",
            var.vllm_dtype,
            "--max-num-seqs",
            tostring(var.vllm_max_num_seqs),
            var.vllm_enable_chunked_prefill ? "--enable-chunked-prefill" : "",
            var.vllm_enable_expert_parallel ? "--enable-expert-parallel" : "",
            "--compilation-config",
            jsonencode({ "level" : var.vllm_compilation_level }),

            # --- Functional & Security Arguments ---
            var.trust_remote_code ? "--trust-remote-code" : "",
            "--hf-overrides",
            var.vllm_hf_overrides,

            # --- Speculative Decoding Arguments ---
            var.enable_speculative_decoding ? "--speculative_config" : "",
            var.enable_speculative_decoding ? jsonencode({
              "model"                      = var.speculative_model_id,
              "num_speculative_tokens"     = var.num_speculative_tokens,
              "draft_tensor_parallel_size" = 1
            }) : ""
          ])
          port {
            container_port = 8000
          }
          resources {
            requests = {
              cpu    = local.main_container_requests.cpu
              memory = local.main_container_requests.memory
            }
            limits = {
              "nvidia.com/gpu" = local.gpu_config.accelerator_count
            }
          }
          liveness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 300
            period_seconds        = 30
          }
          readiness_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 600
            period_seconds        = 30
            failure_threshold     = 5
          }
          startup_probe {
            http_get {
              path = "/health"
              port = 8000
            }
            initial_delay_seconds = 60
            period_seconds        = 30
            failure_threshold     = 120
          }
          volume_mount {
            name       = "model-cache"
            mount_path = "/root/.cache/huggingface"
          }
        }
        volume {
          name = "model-cache"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.model_cache.metadata[0].name
          }
        }
        volume {
          name = "validate-script"
          config_map {
            name         = kubernetes_config_map.validate_cache_script.metadata[0].name
            default_mode = "0755"
          }
        }
      }
    }
  }
}

resource "kubernetes_secret" "hf_token" {
  depends_on = [kubernetes_namespace.qwen]

  metadata {
    name      = local.secret_name
    namespace = local.name_prefix
  }
  data = {
    token = var.hf_token
  }
}
