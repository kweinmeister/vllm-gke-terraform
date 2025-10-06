resource "google_container_cluster" "qwen_cluster" {
  name     = local.cluster_name
  location = var.zone
  project  = var.project_id

  remove_default_node_pool = true
  initial_node_count       = 1
}

resource "google_container_node_pool" "default_pool" {
  name       = "${local.name_prefix}-default-pool"
  cluster    = google_container_cluster.qwen_cluster.name
  location   = var.zone
  node_count = 1

  node_config {
    machine_type = "e2-standard-4"
  }
}

resource "google_container_node_pool" "h100_spot_pool" {
  name     = "${local.name_prefix}-h100-spot-pool"
  cluster  = google_container_cluster.qwen_cluster.name
  location = var.zone
  project  = var.project_id

  autoscaling {
    min_node_count = var.min_gpu_nodes
    max_node_count = var.max_gpu_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "a3-highgpu-8g"
    spot         = true
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    service_account = "default"
    labels = {
      pool-type = "h100-spot"
      model     = var.name_prefix
    }
    taint {
      key    = "dedicated"
      value  = "h100-spot"
      effect = "NO_SCHEDULE"
    }
    guest_accelerator {
      type  = "nvidia-h100-80gb"
      count = 8
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }
    shielded_instance_config {
      enable_secure_boot = true
    }
    ephemeral_storage_local_ssd_config {
      local_ssd_count = 16
    }
  }
}

resource "google_container_node_pool" "h100_ondemand_pool" {
  name     = "${local.name_prefix}-h100-ondemand-pool"
  cluster  = google_container_cluster.qwen_cluster.name
  location = var.zone
  project  = var.project_id

  autoscaling {
    min_node_count = var.min_gpu_nodes
    max_node_count = var.max_gpu_nodes
  }

  management {
    auto_repair  = true
    auto_upgrade = true
  }

  node_config {
    machine_type = "a3-highgpu-8g"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
    service_account = "default"
    labels = {
      pool-type = "h100-ondemand"
      model     = var.name_prefix
    }
    taint {
      key    = "dedicated"
      value  = "h100-ondemand"
      effect = "NO_SCHEDULE"
    }
    guest_accelerator {
      type  = "nvidia-h100-80gb"
      count = 8
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }
    shielded_instance_config {
      enable_secure_boot = true
    }
    ephemeral_storage_local_ssd_config {
      local_ssd_count = 16
    }
  }
}