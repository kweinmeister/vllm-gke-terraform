import os
import shutil
from pathlib import Path
from huggingface_hub import snapshot_download

os.environ["HF_HUB_ENABLE_HF_TRANSFER"] = "1"

HF_HOME = os.environ.get("HF_HOME", "/root/.cache/huggingface")
hf_token = os.environ.get("HF_TOKEN")
base_model_id = os.environ.get("MODEL_ID")
spec_model_id = os.environ.get("SPECULATIVE_MODEL_ID")
enable_spec = os.environ.get("ENABLE_SPECULATIVE_DECODING", "false").lower() == "true"


def download_and_validate(model_id, token, cache_dir):
    final_dir = Path(cache_dir) / "hub" / f"models--{model_id.replace('/', '--')}"
    temp_dir = final_dir.with_name(final_dir.name + ".tmp")

    # Clean up any stale temp dir
    if temp_dir.exists():
        shutil.rmtree(temp_dir)

    # Download
    snapshot_download(
        repo_id=model_id,
        token=token,
        cache_dir=cache_dir,
        local_dir=temp_dir,
        local_dir_use_symlinks=False,  # Avoid symlink issues in containers
    )

    # Atomic move
    if temp_dir.exists():
        temp_dir.rename(final_dir)
        (final_dir / ".success").touch()
        print(f"✅ Successfully downloaded {model_id} to {final_dir}")
    else:
        raise RuntimeError(f"Download failed: {temp_dir} not created")


# Download base model
download_and_validate(base_model_id, hf_token, HF_HOME)

# Download speculative model if enabled
if enable_spec and spec_model_id:
    download_and_validate(spec_model_id, hf_token, HF_HOME)
