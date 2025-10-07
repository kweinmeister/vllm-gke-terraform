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
  default     = "us-central1"
}

variable "zone" {
  description = "The GCP zone for the GKE cluster."
  type        = string
  default     = "us-central1-c"
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
  default     = "2000Gi"
}

variable "name_prefix" {
  description = "Prefix for all resource names"
  type        = string
  default     = "qwen3-235b"
}

variable "min_gpu_nodes" {
  description = "Minimum number of GPU nodes"
  type        = number
  default     = 0
}

variable "model_id" {
  description = "The Hugging Face model ID to deploy (e.g., Qwen/Qwen2-235B-Instruct)."
  type        = string
  default     = "Qwen/Qwen3-235B-A22B"
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
  default     = "lmsys/Qwen3-235B-A22B-EAGLE3"
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

variable "tensor_parallel_size" {
  description = "Tensor parallel size for model sharding"
  type        = number
  default     = 8
}

variable "gpu_memory_utilization" {
  description = "GPU memory utilization ratio"
  type        = number
  default     = 0.9
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
  default     = true
}

variable "vllm_compilation_level" {
  description = "The compilation level for vLLM."
  type        = number
  default     = 3
}

variable "vllm_hf_overrides" {
  description = "A JSON string of Hugging Face configuration overrides."
  type        = string
  default     = "{\"num_experts\": 128}"
}

variable "trust_remote_code" {
  description = "Set to true to trust remote code from the Hugging Face model repository. Required for some models, but should be enabled with caution."
  type        = bool
  default     = false
}

variable "vllm_use_flashinfer_moe" {
  description = "Enable the FlashInfer CUTLASS MoE kernel for Mixture of Experts models."
  type        = bool
  default     = false
}
