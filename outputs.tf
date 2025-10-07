output "cluster_endpoint" {
  value = google_container_cluster.qwen_cluster.endpoint
}

output "node_pool_names" {
  description = "Names of all node pools including GPU pools"
  value = concat(
    [google_container_node_pool.default_pool.name],
    keys(local.gpu_node_pools)
  )
}

output "pvc_name" {
  description = "The name of the model cache PVC"
  value       = local.pvc_name
}

output "service_name" {
  description = "The name of the Kubernetes service"
  value       = local.service_name
}

output "deployment_name" {
  description = "The name of the Kubernetes deployment"
  value       = local.deployment_name
}


output "cluster_ca_certificate" {
  description = "Cluster CA certificate"
  value       = google_container_cluster.qwen_cluster.master_auth[0].cluster_ca_certificate
  sensitive   = true
}

output "model_downloader_job_status" {
  description = "Status information for the model downloader job"
  value       = "Job ${local.job_name} is running. Check status with: kubectl get job -n ${local.name_prefix} ${local.job_name}"
}

output "scale_up_command" {
  description = "Run this after model download completes to start vLLM:"
  value       = "kubectl scale deployment -n ${local.name_prefix} ${local.deployment_name} --replicas=1"
}

output "namespace" {
  description = "The Kubernetes namespace for the deployment"
  value       = local.name_prefix
}

output "cluster_name" {
  description = "The name of the GKE cluster"
  value       = local.cluster_name
}

output "region" {
  description = "The GCP region of the GKE cluster"
  value       = var.region
}


output "port_forward_command" {
  description = "Run this command to access the vLLM API locally:"
  value       = "kubectl port-forward svc/${local.service_name} -n ${local.name_prefix} 8000:8000"
}

output "model_id" {
  description = "The Hugging Face model ID being used."
  value       = var.model_id
}

output "job_name" {
  description = "The name of the model downloader Kubernetes job."
  value       = local.job_name
}

output "tensor_parallel_size" {
  description = "The actual tensor parallel size used (inferred from the GPU node pool)"
  value       = local.gpu_config.accelerator_count
}
