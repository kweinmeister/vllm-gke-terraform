# kubernetes_jobs.tf

# 1. ConfigMap to hold the Python download script
resource "kubernetes_config_map" "model_downloader_script" {
  metadata {
    name      = "${local.name_prefix}-download-script"
    namespace = local.name_prefix
  }

  data = {
    "download.py" = file("${path.module}/scripts/download.py")
  }
}

# 2. Kubernetes Job to execute the download script.
resource "null_resource" "model_downloader_job_trigger" {
  depends_on = [
    kubernetes_namespace.qwen,
    kubernetes_persistent_volume_claim.model_cache,
    kubernetes_secret.hf_token,
    kubernetes_config_map.model_downloader_script
  ]

  triggers = {
    script_hash               = filemd5("${path.module}/scripts/download.py")
    model_id_hash             = md5(var.model_id)
    speculative_model_id_hash = md5(var.speculative_model_id)
  }

  provisioner "local-exec" {
    command = <<EOT
      set -e
      export JOB_NAME="${local.name_prefix}-model-downloader"
      export NAMESPACE="${local.name_prefix}"
      export PVC_NAME="${kubernetes_persistent_volume_claim.model_cache.metadata[0].name}"
      export CONFIGMAP_NAME="${kubernetes_config_map.model_downloader_script.metadata[0].name}"
      export SECRET_NAME="${kubernetes_secret.hf_token.metadata[0].name}"
      export MODEL_ID="${var.model_id}"
      export SPECULATIVE_MODEL_ID="${var.speculative_model_id}"
      ${path.module}/scripts/apply-model-download-job.sh
    EOT
  }
}