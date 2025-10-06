#!/bin/bash
set -euo pipefail
export HF_HUB_ENABLE_HF_TRANSFER=1  # 🔥 Enables 3–5x faster downloads
exec > >(tee -a /dev/stderr) 2>&1

# Function to validate a model
validate_model() {
    local MODEL_DIR="$1"
    local MODEL_ID="$2"
    local MODEL_TYPE="$3"  # "base" or "speculative"

    # Validate model directory exists
    if [[ ! -d "$MODEL_DIR" ]]; then
        echo "❌ ERROR: ${MODEL_TYPE^} model directory $MODEL_DIR does not exist." >&2
        exit 1
    fi

    local MAX_WAIT=3600  # 1 hour
    local WAIT_INTERVAL=30
    local count=0

    echo "⏳ Waiting for ${MODEL_TYPE} model download to complete..."
    while [[ $count -lt $MAX_WAIT ]]; do
        if [[ -n $(find "$MODEL_DIR" -type f -name '.success' 2>/dev/null) ]]; then
            echo "✅ ${MODEL_TYPE^} model validation successful for $MODEL_ID."
            return 0
        fi
        echo "Still waiting for ${MODEL_TYPE} .success file... ($((count))s / $MAX_WAIT)"
        sleep $WAIT_INTERVAL
        count=$((count + WAIT_INTERVAL))
    done

    echo "❌ ERROR: ${MODEL_TYPE^} model download did not complete within $MAX_WAIT seconds." >&2
    exit 1
}

# Validate base model
MODEL_DIR="/root/.cache/huggingface/hub/models--${MODEL_ID//\//--}"
validate_model "$MODEL_DIR" "$MODEL_ID" "base"

# Validate speculative model if enabled
if [[ "$ENABLE_SPECULATIVE_DECODING" == "true" ]]; then
    SPEC_MODEL_DIR="/root/.cache/huggingface/hub/models--${SPECULATIVE_MODEL_ID//\//--}"
    validate_model "$SPEC_MODEL_DIR" "$SPECULATIVE_MODEL_ID" "speculative"
else
    echo "ℹ️  Speculative decoding not enabled, skipping its validation."
fi

echo "--- Cache Validation Complete. Starting main container. ---"
