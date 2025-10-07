locals {
  name_prefix = var.name_prefix

  cluster_name = "${var.name_prefix}-cluster"
  pvc_name     = "${var.name_prefix}-model-cache-pvc"
  secret_name  = "${var.name_prefix}-hf-secret"
  job_name     = "${local.name_prefix}-model-downloader"

  app_label       = "vllm-${var.name_prefix}"
  deployment_name = local.app_label
  service_name    = local.app_label

  vllm_env_vars = concat(
    [
      {
        name  = "LD_LIBRARY_PATH"
        value = "/usr/local/nvidia/lib64"
      },
      {
        name = "HF_TOKEN"
        value_from = {
          secret_key_ref = {
            name = kubernetes_secret.hf_token.metadata[0].name
            key  = "token"
          }
        }
      }
    ],
    var.vllm_use_flashinfer_moe ? [{
      name  = "VLLM_USE_FLASHINFER_MOE_FP16"
      value = "1"
    }] : []
  )

  machine_type_specs = {
    "a3-highgpu-8g" = {
      local_ssd_count = 16
      cpu             = "208"
      memory          = "1872Gi"
    },
    "e2-standard-4" = {
      local_ssd_count = 0
      cpu             = "4"
      memory          = "16Gi"
    }
  }

  gpu_node_pools = {
    "${local.name_prefix}-h100-spot-pool" = {
      pool_type         = "h100-spot"
      is_spot           = true
      machine_type      = "a3-highgpu-8g"
      accelerator_type  = "nvidia-h100-80gb"
      accelerator_count = 8
    }
    "${local.name_prefix}-h100-ondemand-pool" = {
      pool_type         = "h100-ondemand"
      is_spot           = false
      machine_type      = "a3-highgpu-8g"
      accelerator_type  = "nvidia-h100-80gb"
      accelerator_count = 8
    }
  }

  # Resource configurations for Kubernetes deployment
  kubernetes_resources = {
    init_container = {
      requests = {
        cpu    = "100m"
        memory = "256Mi"
      }
      limits = {
        cpu    = "200m"
        memory = "512Mi"
      }
    }
    # Main container resources are associated with machine types
    main_container_resources_by_machine_type = {
      "a3-highgpu-8g" = {
        requests = {
          cpu    = "8"
          memory = "128Gi"
        }
      }
      "e2-standard-4" = {
        requests = {
          cpu    = "2"
          memory = "4Gi"
        }
      }
    }
  }

  # Extract common GPU configuration for use in Kubernetes deployment
  # Assumes all GPU node pools have the same accelerator type and count
  gpu_config = {
    accelerator_type  = one([for p in values(local.gpu_node_pools) : p.accelerator_type])
    accelerator_count = one([for p in values(local.gpu_node_pools) : p.accelerator_count])
  }

  main_container_requests = local.kubernetes_resources.main_container_resources_by_machine_type[one([for p in values(local.gpu_node_pools) : p.machine_type])].requests
}