#!/bin/bash
set -euo pipefail
exec > >(tee -a /dev/stderr) 2>&1

MODEL_DIR="/root/.cache/huggingface/hub/models--${MODEL_ID//\//--}"

# Validate base model directory exists
if [[ ! -d "$MODEL_DIR" ]]; then
    echo "❌ ERROR: Model directory $MODEL_DIR does not exist." >&2
    exit 1
fi

if [[ -n $(find "$MODEL_DIR" -type f -name '.success' 2>/dev/null) ]]; then
    echo "✅ Base model validation successful for $MODEL_ID."
else
    echo "❌ ERROR: Base model validation FAILED for $MODEL_ID at $MODEL_DIR." >&2
    echo "The '.success' marker file was not found. The download job may have failed. Aborting pod startup." >&2
    exit 1
fi

if [[ "$ENABLE_SPECULATIVE_DECODING" == "true" ]]; then
    SPEC_MODEL_DIR="/root/.cache/huggingface/hub/models--${SPECULATIVE_MODEL_ID//\//--}"

    # Validate speculative model directory exists
    if [[ ! -d "$SPEC_MODEL_DIR" ]]; then
        echo "❌ ERROR: Speculative model directory $SPEC_MODEL_DIR does not exist." >&2
        exit 1
    fi

    if [[ -n $(find "$SPEC_MODEL_DIR" -type f -name '.success' 2>/dev/null) ]]; then
        echo "✅ Speculative model validation successful for $SPECULATIVE_MODEL_ID."
    else
        echo "❌ ERROR: Speculative model validation FAILED for $SPECULATIVE_MODEL_ID at $SPEC_MODEL_DIR." >&2
        echo "The download job may have failed to get the speculative model. Aborting pod startup." >&2
        exit 1
    fi
else
    echo "ℹ️  Speculative decoding not enabled, skipping its validation."
fi

echo "--- Cache Validation Complete. Starting main container. ---"
