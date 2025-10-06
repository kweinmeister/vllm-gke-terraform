locals {
  # This local simply makes the variable easier to reference if needed, but is optional.
  name_prefix = var.name_prefix

  # --- Resource Names ---
  # Define all resource names here, based on the single name_prefix variable.
  cluster_name = "${var.name_prefix}-cluster"
  pvc_name     = "${var.name_prefix}-model-cache-pvc"
  secret_name  = "${var.name_prefix}-hf-secret"

  # For Kubernetes, it's good practice to have a consistent app label.
  # We will derive the deployment and service names from this.
  app_label       = "vllm-${var.name_prefix}"
  deployment_name = local.app_label # The deployment name and app label are often the same
  service_name    = local.app_label # The service name can also be the same for simplicity
}