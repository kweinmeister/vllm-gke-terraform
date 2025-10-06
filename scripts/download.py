import os
import sys
import shutil
from pathlib import Path
from huggingface_hub import snapshot_download

HF_HOME = os.environ.get("HF_HOME", "/root/.cache/huggingface")
os.makedirs(HF_HOME, exist_ok=True)


def download_and_validate(model_id, model_name, token, cache_dir):
    """Downloads a model and creates a success file upon completion."""
    print(f"🚀 Starting model download for {model_name}: {model_id}...")
    try:
        # 🔥 Optimize: Parallel downloads (if supported by the huggingface_hub version)
        snapshot_path = snapshot_download(
            repo_id=model_id,
            token=token,
            cache_dir=cache_dir,
            allow_patterns=[
                "*.json",
                "*.safetensors",
                "*.bin",
                "*.py",
                "*.md",
                "tokenizer.model",
            ],
        )

        # 🔥 Atomic move: Avoid partial cache corruption
        final_dir = Path(cache_dir) / "hub" / f"models--{model_id.replace('/', '--')}"
        temp_dir = Path(snapshot_path)

        final_dir.parent.mkdir(parents=True, exist_ok=True)
        if final_dir.exists():
            shutil.rmtree(final_dir)
        shutil.move(str(temp_dir), str(final_dir))

        # Only create .success AFTER atomic move
        success_file_path = final_dir / ".success"
        success_file_path.touch()

        print(
            f"✅ Model download complete for {model_id}. Success marker created at {success_file_path}"
        )
        return True
    except Exception as e:
        print(f"❌ Download failed for {model_id}: {e}", file=sys.stderr)
        return False


# --- Main Execution ---
hf_token = os.environ.get("HF_TOKEN")
base_model_id = os.environ.get("MODEL_ID")

if not base_model_id:
    print("❌ ERROR: MODEL_ID environment variable not set.", file=sys.stderr)
    sys.exit(1)

if not download_and_validate(base_model_id, "Base Model", hf_token, HF_HOME):
    sys.exit(1)

if os.environ.get("ENABLE_SPECULATIVE", "").lower() == "true":
    spec_model_id = os.environ.get("SPECULATIVE_MODEL_ID")
    if spec_model_id:
        if not download_and_validate(
            spec_model_id, "Speculative Model", hf_token, HF_HOME
        ):
            print(
                f"⚠️ WARNING: Speculative download failed for {spec_model_id}. The main container may fail if it requires this model.",
                file=sys.stderr,
            )
    else:
        print(
            "ℹ️  Speculative decoding enabled but no model ID specified, skipping.",
            file=sys.stderr,
        )
else:
    print("ℹ️  Speculative decoding not enabled, skipping.", file=sys.stderr)

print("--- All downloads attempted. Job finished. ---")
