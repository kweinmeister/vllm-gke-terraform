# kubernetes_jobs.tf

# 1. ConfigMap to hold the Python download script
resource "kubernetes_config_map" "model_downloader_script" {
  depends_on = [kubernetes_namespace.vllm]

  metadata {
    name      = "${local.name_prefix}-download-script"
    namespace = local.name_prefix
  }

  data = {
    "download.py" = file("${path.module}/scripts/download.py")
  }
}

# A null_resource to capture triggers that aren't tied to another resource.
# This resource will be replaced if the model configuration variables change,
# which in turn will trigger the replacement of the kubernetes_job.
resource "null_resource" "job_triggers" {
  triggers = {
    model_config_hash = sha256("${var.model_id}${var.speculative_model_id}${var.enable_speculative_decoding}")
  }
}

# 2. Kubernetes Job to execute the download script.
resource "kubernetes_job" "model_downloader_job" {
  wait_for_completion = false
  metadata {
    name      = local.job_name
    namespace = local.name_prefix
  }

  spec {
    ttl_seconds_after_finished = 86400
    backoff_limit              = 3
    template {
      metadata {}
      spec {
        restart_policy                   = "OnFailure"
        termination_grace_period_seconds = 60

        volume {
          name = "model-cache"
          persistent_volume_claim {
            claim_name = kubernetes_persistent_volume_claim.model_cache.metadata[0].name
          }
        }
        volume {
          name = "download-script"
          config_map {
            name         = kubernetes_config_map.model_downloader_script.metadata[0].name
            default_mode = "0755"
          }
        }
        container {
          name              = "downloader"
          image             = "python:3.13-slim"
          image_pull_policy = "IfNotPresent"
          command           = ["/bin/sh", "-c", "pip install -q huggingface-hub && python /scripts/download.py"]
          # ✅ Simple env vars
          dynamic "env" {
            for_each = local.vllm_env_vars_simple
            content {
              name  = env.value.name
              value = env.value.value
            }
          }

          # ✅ Secret env vars
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
          volume_mount {
            name       = "model-cache"
            mount_path = "/root/.cache/huggingface"
          }
          volume_mount {
            name       = "download-script"
            mount_path = "/scripts"
            read_only  = true
          }
          resources {
            requests = {
              cpu    = "1"
              memory = "4Gi"
            }
            limits = {
              cpu    = "2"
              memory = "8Gi"
            }
          }
        }
      }
    }
  }

  lifecycle {
    # Trigger replacement when the download script (via the ConfigMap) or
    # the model configuration (via the null_resource) changes.
    replace_triggered_by = [
      kubernetes_config_map.model_downloader_script,
      null_resource.job_triggers,
    ]

    precondition {
      condition     = !var.enable_speculative_decoding || var.speculative_model_id != ""
      error_message = "When speculative decoding is enabled, `speculative_model_id` must be provided and cannot be empty."
    }
  }

  depends_on = [
    kubernetes_namespace.vllm,
    kubernetes_persistent_volume_claim.model_cache,
    kubernetes_secret.hf_token,
    kubernetes_config_map.model_downloader_script,
  ]
}