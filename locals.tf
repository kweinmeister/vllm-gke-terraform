locals {
  name_prefix = var.name_prefix

  cluster_name = "${var.name_prefix}-cluster"
  pvc_name     = "${var.name_prefix}-model-cache-pvc"
  secret_name  = "${var.name_prefix}-hf-secret"
  job_name     = "${local.name_prefix}-model-downloader"

  app_label       = "vllm-${var.name_prefix}"
  deployment_name = local.app_label
  service_name    = local.app_label

  # Simple env vars (with value = string)
  vllm_simple_env = [
    {
      name  = "PYTORCH_CUDA_ALLOC_CONF"
      value = "expandable_segments:True"
    },
    {
      name  = "LD_LIBRARY_PATH"
      value = "/usr/local/nvidia/lib64"
    },
    {
      name  = "MODEL_ID"
      value = var.model_id
    },
    {
      name  = "SPECULATIVE_MODEL_ID"
      value = var.speculative_model_id
    },
    {
      name  = "ENABLE_SPECULATIVE_DECODING"
      value = tostring(var.enable_speculative_decoding)
    },
    {
      name  = "PYTHONUNBUFFERED"
      value = "1"
    },
    var.vllm_use_flashinfer_moe ? {
      name  = "VLLM_USE_FLASHINFER_MOE_FP16"
      value = "1"
    } : null,
  ]

  # Secret env vars (with value_from)
  vllm_secret_env = [
    {
      name = "HF_TOKEN"
      value_from = {
        secret_key_ref = {
          name = kubernetes_secret.hf_token.metadata[0].name
          key  = "token"
        }
      }
    },
  ]

  # Filter out nulls
  vllm_env_vars_simple = [for env in local.vllm_simple_env : env if env != null]
  vllm_env_vars_secret = [for env in local.vllm_secret_env : env if env != null]

  machine_type_specs = {
    "a3-highgpu-8g" = {
      local_ssd_count = 16
      cpu             = "208"
      memory          = "1872Gi"
    },
    "g2-standard-48" = {
      local_ssd_count = 0
      cpu             = "48"
      memory          = "192Gi"
    },
    "e2-standard-4" = {
      local_ssd_count = 0
      cpu             = "4"
      memory          = "16Gi"
    }
  }

  # Defines all available GPU node pool configurations
  all_gpu_node_pools = {
    h100 = {
      "${local.name_prefix}-h100-spot-pool" = {
        pool_type            = "h100-spot"
        is_spot              = true
        machine_type         = "a3-highgpu-8g"
        accelerator_type     = "nvidia-h100-80gb"
        accelerator_count    = 8
        tensor_parallel_size = 8
      }
      "${local.name_prefix}-h100-ondemand-pool" = {
        pool_type            = "h100-ondemand"
        is_spot              = false
        machine_type         = "a3-highgpu-8g"
        accelerator_type     = "nvidia-h100-80gb"
        accelerator_count    = 8
        tensor_parallel_size = 8
      }
    },
    l4 = {
      "${local.name_prefix}-l4-spot-pool" = {
        pool_type            = "l4-spot"
        is_spot              = true
        machine_type         = "g2-standard-48"
        accelerator_type     = "nvidia-l4"
        accelerator_count    = 4
        tensor_parallel_size = 4
      }
      "${local.name_prefix}-l4-ondemand-pool" = {
        pool_type            = "l4-ondemand"
        is_spot              = false
        machine_type         = "g2-standard-48"
        accelerator_type     = "nvidia-l4"
        accelerator_count    = 4
        tensor_parallel_size = 4
      }
    }
  }

  # Selects the appropriate GPU node pool based on the gpu_type variable
  gpu_node_pools = local.all_gpu_node_pools[var.gpu_type]

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
      "g2-standard-48" = {
        requests = {
          cpu    = "8"
          memory = "64Gi"
        }
      },
      "a3-highgpu-8g" = {
        requests = {
          cpu    = "8"
          memory = "128Gi"
        }
      },
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
    accelerator_type  = values(local.gpu_node_pools)[0].accelerator_type
    accelerator_count = values(local.gpu_node_pools)[0].accelerator_count
  }

  main_container_requests = local.kubernetes_resources.main_container_resources_by_machine_type[values(local.gpu_node_pools)[0].machine_type].requests
}