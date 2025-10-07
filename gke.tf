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

resource "google_container_node_pool" "gpu_pools" {
  for_each = local.gpu_node_pools

  name     = each.key
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
    machine_type = each.value.machine_type
    spot         = each.value.is_spot

    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

    service_account = "default"

    labels = {
      "cloud.google.com/gke-accelerator" = each.value.accelerator_type,
      "pool-type"                        = each.value.pool_type
      "model"                            = local.name_prefix
      "cloud.google.com/gke-spot"        = tostring(each.value.is_spot)
    }

    taint {
      key    = "dedicated"
      value  = each.value.is_spot ? "${each.value.accelerator_type}-spot" : "${each.value.accelerator_type}-ondemand"
      effect = "NO_SCHEDULE"
    }

    guest_accelerator {
      type  = each.value.accelerator_type
      count = each.value.accelerator_count
      gpu_driver_installation_config {
        gpu_driver_version = "LATEST"
      }
    }

    ephemeral_storage_local_ssd_config {
      local_ssd_count = local.machine_type_specs[each.value.machine_type].local_ssd_count
    }

    shielded_instance_config {
      enable_secure_boot = true
    }
  }
}