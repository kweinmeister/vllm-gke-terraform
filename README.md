# vLLM on GKE with Terraform

Deploy vLLM-powered LLM inference on Google Kubernetes Engine (GKE) with automated model downloading, GPU autoscaling, and secure Hugging Face token handling — using Terraform.

> **Default model**: `Qwen/Qwen3-32B` — easily replaceable with any Hugging Face model.

---

## 📌 Overview

This Terraform module provisions:

- A GKE cluster with **two GPU node pools**:  
  - `spot` (cost-optimized, may be terminated)  
  - `on-demand` (always available, fallback)  
- A persistent volume (PVC) for caching Hugging Face models  
- A Kubernetes Job to securely download models using your Hugging Face token  
- A vLLM deployment with speculative decoding support  
- An **internal-only** service, accessible via `kubectl port-forward`

Each resource is named using your `name_prefix`, enabling safe multi-model deployments.

> ⚠️ **Hardware**: The default configuration uses either:
> - `a3-highgpu-8g` nodes with **8x NVIDIA H100 80GB GPUs** (for `gpu_type = "h100"`)
> - `g2-standard-48` nodes with **4x NVIDIA L4 24GB GPUs** (for `gpu_type = "l4"`)
> This is a **high-cost** infrastructure. Proceed with caution.

---

## ✅ Prerequisites

1. **Google Cloud Project** with:
   - Billing enabled
   - The Container Engine API enabled: `container.googleapis.com`

2. **gcloud CLI** installed and authenticated:
   ```bash
   gcloud auth login
   gcloud config set project YOUR_PROJECT_ID
   ```

3. **Terraform** installed (v1.5+):
   → Install from: https://developer.hashicorp.com/terraform/install

4. **kubectl** installed and configured:
   → [Install kubectl](https://kubernetes.io/docs/tasks/tools/)

5. **Hugging Face Token** with read access to your model:
   → Learn how to create one: https://huggingface.co/docs/hub/en/security-tokens

---

## 🚀 Quick Start

### 1. Clone the repo

```bash
git clone https://github.com/kweinmeister/vllm-gke-terraform.git
cd vllm-gke-terraform
```

### 2. Make scripts executable

```bash
chmod +x scripts/validate-cache.sh
```

> ⚠️ Required: The init container executes this script directly. Without `chmod +x`, `validate-cache.sh` will fail.

### 3. Configure the Terraform Backend

Terraform uses a remote backend to store state securely. The following steps will help you create a GCS bucket and configure the backend.

1. **Set Environment Variables**

   First, export your Google Cloud Project ID and a unique name for your Terraform state bucket. This avoids being prompted later.

   ```bash
   export PROJECT_ID=$(gcloud config get-value project)
   export TF_STATE_BUCKET=$PROJECT_ID-tf-state
   ```

2. **Create the GCS Bucket**

   Create and version the GCS bucket for your Terraform state:

   ```bash
   gsutil mb gs://$TF_STATE_BUCKET
   gsutil versioning set on gs://$TF_STATE_BUCKET
   ```

### 4. Configure with `terraform.tfvars` (Optional)

While you can create `terraform.tfvars` to override defaults, it's recommended to use environment variables for sensitive information like `hf_token`:

```bash
export TF_VAR_hf_token="hf_abcdefghijklmnopqrstuvwxyz123456"
```

If you'd like to override deployment defaults, you can enter non-sensitive variables in a `terraform.tfvars` file.

```hcl
project_id = "your-gcp-project-id"

name_prefix = "qwen3-32b"

model_id = "Qwen/Qwen3-32B"
enable_speculative_decoding = false
speculative_model_id = "Zhihu-ai/Zhi-Create-Qwen3-32B-Eagle3"
model_cache_size = "150Gi"
gpu_type = "l4"
replicas = 1
```

> 💡 **All other variables** (e.g., `gpu_memory_utilization`, `vllm_dtype`, `max_model_len`) have **default values** defined in `variables.tf`.
> Override only what you need.
> See [vLLM CLI options](https://docs.vllm.ai/en/stable/) for full documentation on all parameters.
>
> 💡 **To start scaled down**, set `replicas = 0` and use the `scale_up_command` output after model download completes.


### 5. Deploy

```bash
terraform init -backend-config="bucket=$TF_STATE_BUCKET"
terraform plan
terraform apply
```
> This creates:
> - A GKE cluster with spot/on-demand node pools
> - A PVC for model caching
> - A Kubernetes Job to download your model
> - A vLLM deployment (scaled to the number of replicas specified by the `replicas` variable, default 1)
> - An internal Kubernetes service (no public IP)

### 5a. Configure `kubectl`

After the cluster is created, configure `kubectl`:

```bash
gcloud container clusters get-credentials $(terraform output -raw cluster_name) --region $(terraform output -raw region)
```

### 6. Wait for model download to finish

Check the job status:

```bash
kubectl get jobs -n $(terraform output -raw namespace)
```

Wait until `COMPLETIONS` shows `1/1`.

> ⏱️ Downloading large models (e.g., 32B) may take 10–30 minutes.

### 7. Scale up the vLLM deployment

Once the model is downloaded, start the inference server:

```bash
# Copy-paste this exact command from outputs (recommended)
terraform output scale_up_command
```

```bash
# Or manually:
kubectl scale deployment -n $(terraform output -raw namespace) $(terraform output -raw deployment_name) --replicas=1
```

> 🔍 **Why scale up?**
> The vLLM deployment can be created with `replicas = 0` to avoid starting before the model is fully downloaded and validated.
> If you set `replicas = 0`, use the scale_up_command output to scale to `1` which triggers the init container to verify the `.success` marker file in the PVC — ensuring the model is complete — before launching the inference server.
> If you set `replicas > 0`, the deployment will start immediately after model download completes.

### 8. Test the API via Port-Forward

This deployment is designed for secure, internal access. Use `kubectl port-forward` to connect to the vLLM API.

1.  **Get the Port-Forward Command**

    Terraform provides the exact command as an output:

    ```bash
    terraform output -raw port_forward_command
    ```

2.  **Run the Command**

    Copy and paste the output from the previous step into your terminal. It will look like this:

    ```bash
    kubectl port-forward svc/vllm-qwen3-32b -n qwen3-32b 8000:8000
    ```
    
    > This command forwards your local port `8000` to the service's port `8000` in the cluster. Keep this terminal running.

3.  **Test the API**

    In a **new terminal**, send a request to `localhost`:

```bash
curl -X POST \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"$(terraform output -raw model_id)\",
    \"prompt\": \"Explain quantum computing in one sentence.\",
    \"max_tokens\": 50
  }" \
  http://localhost:8000/v1/completions
```

---

## 💰 Cost Warning

> ⚠️ **This deployment uses either:**
> - `a3-highgpu-8g` nodes with 8x NVIDIA H100 80GB GPUs (for H100 configuration)
> - `g2-standard-48` nodes with 4x NVIDIA L4 24GB GPUs (for L4 configuration)
> Leaving this running overnight or unattended **will result in charges**.

✅ **Before deploying:**
- Check your **GCP quota** for GPUs in your zone:  
  → https://console.cloud.google.com/iam-admin/quotas
- Set up **billing alerts** in your GCP project.
- Never use this in production without cost monitoring.

---

## 🔄 Customize Your Deployment

All variables are defined in `variables.tf`. Override any in `terraform.tfvars`.

| Category | Variable | Purpose | Default |
|--------|----------|---------|---------|
| **Infrastructure** | `project_id` | Your GCP Project ID | (required) |
| | `region` | GCP region for cluster | `us-central1` |
| | `zone` | GCP zone for cluster | `us-central1-c` |
| | `min_gpu_nodes` | Minimum GPU nodes (autoscale) | `0` |
| | `max_gpu_nodes` | Maximum GPU nodes (autoscale) | `2` |
| | `model_cache_size` | Size of model cache PVC | `150Gi` |
| | `gpu_type` | Type of GPU nodes (`h100` or `l4`) | `l4` |
| | `replicas` | Number of vLLM deployment replicas (set to 0 to start scaled down) | `1` |
| **Model & vLLM** | `model_id` | Hugging Face model to deploy | `Qwen/Qwen3-32B` |
| | `enable_speculative_decoding` | Enable draft model for faster inference | `false` |
| | `speculative_model_id` | Draft model ID (required if enabled) | `Zhihu-ai/Zhi-Create-Qwen3-32B-Eagle3` |
| | `num_speculative_tokens` | Number of speculative tokens | `5` |
| | `max_model_len` | Maximum model length | `8192` |
| | `gpu_memory_utilization` | GPU memory utilization ratio | `0.9` |
| | `vllm_dtype` | Data type for weights | `bfloat16` |
| | `vllm_enable_chunked_prefill` | Enable chunked prefill for long prompts | `true` |
| | `vllm_max_num_seqs` | Max concurrent sequences (batch size) | `256` |
| | `vllm_enable_expert_parallel` | Enable expert parallelism | `false` |
| | `vllm_compilation_level` | Compilation level for vLLM | `3` |
| | `vllm_hf_overrides` | JSON string of Hugging Face config overrides | `{}` |
| | `trust_remote_code` | Allow custom code from Hugging Face (risky!) | `true` |
| | `vllm_use_flashinfer_moe` | Enable FlashInfer CUTLASS MoE kernel | `false` |

> 🔗 **Learn all vLLM options**: https://docs.vllm.ai/en/stable/

---

## 🧹 Cleanup

To destroy all resources and avoid ongoing charges:

```bash
terraform destroy
```

> This removes:
> - The GKE cluster and all node pools  
> - The persistent volume (PVC)  
> - The ingress and service  
> - All associated networking and IAM resources

> 💡 **Your GCS bucket and its state files are NOT deleted** — this is intentional for audit and recovery.  
> Clean it manually if needed:  
> ```bash
> gsutil rm -r gs://your-bucket-name-1712345678/terraform/state/vllm-gke
> ```

---

## 🛠️ Troubleshooting

### Q: My vLLM pod is stuck in `Pending` state.

**A**: Most likely:
- You've hit your **GPU quota** (GPUs are limited).  
  → Check quota at: https://console.cloud.google.com/iam-admin/quotas  
- Spot instances are unavailable. The on-demand pool should automatically scale up — wait 5–10 minutes.

### Q: The model download job is failing.

**A**: Check logs:
```bash
kubectl logs -n $(terraform output -raw namespace) -l job-name=$(terraform output -raw job_name)
```
Common causes:
- Invalid `hf_token` (missing permissions)
- Model requires special access (e.g., gated model — request access on Hugging Face)

### Q: I'm getting a `404` or `502` from the ingress IP.

**A**: It can take **5–15 minutes** for the GCE load balancer to initialize and pass health checks.  
Verify the vLLM pod is running:
```bash
kubectl get pods -n $(terraform output -raw namespace)
```
Wait for status `Running` and `Ready: 1/1`.

---

## 📜 License

Apache License 2.0 — see [LICENSE](LICENSE)
