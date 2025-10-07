#!/bin/sh
set -eu
export HF_HUB_ENABLE_HF_TRANSFER=1

# Redirect stdout to stderr
exec 3>&1
exec 1>&2

# --- CONFIG ---
MAX_WAIT=7200   # 2 hours per model
WAIT_INTERVAL=30
DEBUG_LOGS="${DEBUG_LOGS:-false}"

# --- MODEL PATHS ---
BASE_MODEL_ID="${MODEL_ID:-}"
SPEC_MODEL_ID="${SPECULATIVE_MODEL_ID:-}"
ENABLE_SPEC="${ENABLE_SPECULATIVE_DECODING:-false}"

BASE_MODEL_DIR="/root/.cache/huggingface/hub/models--$(echo "$BASE_MODEL_ID" | sed 's/\//--/g')"
SPEC_MODEL_DIR="/root/.cache/huggingface/hub/models--$(echo "$SPEC_MODEL_ID" | sed 's/\//--/g')"

# --- FUNCTION: Wait for a .success file to appear ---
wait_for_success_file() {
    dir="$1"
    label="$2"
    count=0

    echo "⏳ Waiting for $label model download to complete..."
    while [ $count -lt $MAX_WAIT ]; do
        if [ -f "$dir/.success" ]; then
            echo "✅ $label model .success file found."
            return 0
        fi
        if [ "$DEBUG_LOGS" = "true" ]; then
            echo "⏳ Still waiting for $label .success file... (${count}s / $MAX_WAIT)"
        fi
        sleep $WAIT_INTERVAL
        count=$((count + WAIT_INTERVAL))
    done

    echo "❌ ERROR: $label model .success file not found within $MAX_WAIT seconds."
    exit 1
}

# --- VALIDATION LOGIC ---
echo "⏳ Starting cache validation..."

# Check for required MODEL_ID
if [ -z "$BASE_MODEL_ID" ]; then
    echo "❌ ERROR: MODEL_ID environment variable is not set."
    exit 1
fi

# Wait for base model .success file
wait_for_success_file "$BASE_MODEL_DIR" "base"

# If speculative decoding is enabled, wait for its .success file
if [ "$ENABLE_SPEC" = "true" ]; then
    if [ -z "$SPEC_MODEL_ID" ]; then
        echo "❌ ERROR: ENABLE_SPECULATIVE_DECODING=true but SPECULATIVE_MODEL_ID is empty"
        exit 1
    fi
    wait_for_success_file "$SPEC_MODEL_DIR" "speculative"
else
    echo "ℹ️  Speculative decoding not enabled, skipping its validation."
fi

echo "--- Cache Validation Complete. Starting main container. ---"
exit 0
