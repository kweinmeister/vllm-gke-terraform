#!/bin/sh
set -eu
export HF_HUB_ENABLE_HF_TRANSFER=1 # 🔥 Enables 3–5x faster downloads

# Redirect stdout to stderr (duplicating output) using a portable approach
# We'll use a file descriptor redirection that works in POSIX sh
exec 3>&1 # Save original stdout
exec 1>&2 # Redirect stdout to stderr

# Function to validate a model
validate_model() {
    MODEL_DIR="$1"
    MODEL_ID="$2"
    MODEL_TYPE="$3" # "base" or "speculative"

    # Validate model directory exists
    if [ ! -d "$MODEL_DIR" ]; then
        echo "❌ ERROR: ${MODEL_TYPE} model directory $MODEL_DIR does not exist."
        exit 1
    fi

    MAX_WAIT=7200 # 2 hours
    WAIT_INTERVAL=30
    count=0

    echo "⏳ Waiting for ${MODEL_TYPE} model download to complete..."
    while [ $count -lt $MAX_WAIT ]; do
        if [ -f "$MODEL_DIR/.success" ]; then
            echo "✅ ${MODEL_TYPE} model validation successful for $MODEL_ID."
            return 0
        fi
        # Only show waiting messages if DEBUG_LOGS is set to true
        if [ "${DEBUG_LOGS:-false}" = "true" ]; then
            echo "Still waiting for ${MODEL_TYPE} .success file... (${count}s / $MAX_WAIT)"
        fi
        sleep $WAIT_INTERVAL
        count=$((count + WAIT_INTERVAL))
    done

    echo "❌ ERROR: ${MODEL_TYPE} model download did not complete within $MAX_WAIT seconds."
    exit 1
}

# Validate required environment variables are set
if [ -z "${MODEL_ID:-}" ]; then
    echo "❌ ERROR: MODEL_ID environment variable is not set"
    exit 1
fi

if [ -z "${ENABLE_SPECULATIVE_DECODING:-}" ]; then
    echo "❌ ERROR: ENABLE_SPECULATIVE_DECODING environment variable is not set"
    exit 1
fi

# Validate base model
MODEL_DIR="/root/.cache/huggingface/hub/models--$(echo "$MODEL_ID" | sed 's/\//--/g')"
validate_model "$MODEL_DIR" "$MODEL_ID" "base"

# Validate speculative model if enabled
if [ "$ENABLE_SPECULATIVE_DECODING" = "true" ]; then
    if [ -z "${SPECULATIVE_MODEL_ID:-}" ]; then
        echo "❌ ERROR: SPECULATIVE_MODEL_ID environment variable is not set but speculative decoding is enabled"
        exit 1
    fi
    SPEC_MODEL_DIR="/root/.cache/huggingface/hub/models--$(echo "$SPECULATIVE_MODEL_ID" | sed 's/\//--/g')"
    validate_model "$SPEC_MODEL_DIR" "$SPECULATIVE_MODEL_ID" "speculative"
else
    echo "ℹ️  Speculative decoding not enabled, skipping its validation."
fi

echo "--- Cache Validation Complete. Starting main container. ---"
exit 0
