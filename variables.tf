variable "project_id" {
  description = "The GCP project ID."
  type        = string
  validation {
    condition     = length(var.project_id) > 0
    error_message = "Project ID must not be empty."
  }
}

variable "region" {
  description = "The GCP region for the GKE cluster."
  type        = string
  default     = "us-east1"
}

variable "zone" {
  description = "The GCP zone for the GKE cluster."
  type        = string
  default     = "us-east1-c"
}


variable "hf_token" {
  description = "Your Hugging Face token."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.hf_token) > 10
    error_message = "HF token must be longer than 10 characters."
  }
}

variable "model_cache_size" {
  description = "Size of the model cache PVC"
  type        = string
  default     = "150Gi"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "qwen3-32b"
}

variable "replicas" {
  description = "Number of replicas for the vLLM deployment. Set to 0 to start scaled down, then use the scale_up_command output to scale up when ready."
  type        = number
  default     = 1
  validation {
    condition     = var.replicas >= 0
    error_message = "Replicas must be a non-negative integer."
  }
}

variable "min_gpu_nodes" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 0
}

variable "model_id" {
  description = "The Hugging Face model ID to deploy (e.g., Qwen/Qwen2-235B-Instruct)."
  type        = string
  default     = "Qwen/Qwen3-32B"
}

variable "max_gpu_nodes" {
  description = "Maximum number of GPU nodes"
  type        = number
  default     = 2
}

variable "max_model_len" {
  description = "The maximum model length."
  type        = number
  default     = 8192
}

variable "enable_speculative_decoding" {
  description = "Enable speculative decoding with a draft model."
  type        = bool
  default     = false
}

variable "speculative_model_id" {
  description = "The Hugging Face model ID for the speculative draft model (e.g., 'nvidia/Qwen3-235B-A22B-Eagle3')."
  type        = string
  default     = "Zhihu-ai/Zhi-Create-Qwen3-32B-Eagle3"
  validation {
    condition     = !var.enable_speculative_decoding || (var.enable_speculative_decoding && length(var.speculative_model_id) > 0)
    error_message = "When enable_speculative_decoding is true, speculative_model_id must not be empty."
  }
}

variable "num_speculative_tokens" {
  description = "The number of speculative tokens to generate."
  type        = number
  default     = 5
}


variable "gpu_memory_utilization" {
  description = "GPU memory utilization ratio"
  type        = number
  default     = 0.9
}

variable "gpu_type" {
  description = "The type of GPU to use for the node pools. Supported values: 'h100', 'l4'."
  type        = string
  default     = "l4"
  validation {
    condition     = contains(["h100", "l4"], var.gpu_type)
    error_message = "Supported GPU types are 'h100' and 'l4'."
  }
}

variable "dshm_size" {
  description = "Size of the /dev/shm volume for the vLLM container."
  type        = string
  default     = "64Gi"
}

# -----------------------------------------------------------------------------
# VLLM PERFORMANCE TUNING VARIABLES
# -----------------------------------------------------------------------------

variable "vllm_dtype" {
  description = "The data type for model weights. 'bfloat16' is recommended for optimal performance on modern GPUs."
  type        = string
  default     = "bfloat16"
}


variable "vllm_enable_chunked_prefill" {
  description = "If true, enables chunked prefill, which helps manage memory for long prompts and improves batching."
  type        = bool
  default     = true
}

variable "vllm_max_num_seqs" {
  description = "The maximum number of sequences (requests) to batch together. Higher values can increase throughput but also use more memory."
  type        = number
  default     = 256
}

variable "vllm_enable_expert_parallel" {
  description = "If true, enables expert parallelism."
  type        = bool
  default     = false
}

variable "vllm_compilation_level" {
  description = "The compilation level for vLLM."
  type        = number
  default     = 3
}

variable "vllm_hf_overrides" {
  description = "A JSON string of Hugging Face configuration overrides."
  type        = string
  default     = "{}"
}

variable "trust_remote_code" {
  description = "Set to true to trust remote code from the Hugging Face model repository. Required for some models, but should be enabled with caution."
  type        = bool
  default     = true
}

variable "vllm_use_flashinfer_moe" {
  description = "Enable the FlashInfer CUTLASS MoE kernel for Mixture of Experts models."
  type        = bool
  default     = false
}
