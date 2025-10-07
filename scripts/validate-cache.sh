#!/bin/sh
set -eu
export HF_HUB_ENABLE_HF_TRANSFER=1

# Redirect stdout to stderr
exec 3>&1
exec 1>&2

# --- CONFIG ---
MAX_WAIT=7200   # 2 hours total for BOTH models
WAIT_INTERVAL=30
DEBUG_LOGS="${DEBUG_LOGS:-false}"

# --- MODEL PATHS ---
BASE_MODEL_ID="${MODEL_ID}"
SPEC_MODEL_ID="${SPECULATIVE_MODEL_ID}"
ENABLE_SPEC="${ENABLE_SPECULATIVE_DECODING:-false}"

BASE_MODEL_DIR="/root/.cache/huggingface/hub/models--$(echo "$BASE_MODEL_ID" | sed 's/\//--/g')"
SPEC_MODEL_DIR="/root/.cache/huggingface/hub/models--$(echo "$SPEC_MODEL_ID" | sed 's/\//--/g')"

# --- FUNCTION: Wait for a model dir to appear ---
wait_for_model_dir() {
    dir="$1"
    label="$2"
    count=0

    while [ $count -lt $MAX_WAIT ]; do
        if [ -d "$dir" ]; then
            echo "✅ $label model directory found: $dir"
            return 0
        fi
        if [ "$DEBUG_LOGS" = "true" ]; then
            echo "⏳ Still waiting for $label model directory... (${count}s / $MAX_WAIT)"
        fi
        sleep $WAIT_INTERVAL
        count=$((count + WAIT_INTERVAL))
    done

    echo "❌ ERROR: $label model directory $dir was not created within $MAX_WAIT seconds."
    exit 1
}

# --- VALIDATION LOGIC ---
echo "⏳ Waiting for model directories to be created..."

# Check base model
wait_for_model_dir "$BASE_MODEL_DIR" "base"

# If speculative enabled, check speculative model
if [ "$ENABLE_SPEC" = "true" ]; then
    if [ -z "$SPEC_MODEL_ID" ]; then
        echo "❌ ERROR: ENABLE_SPECULATIVE_DECODING=true but SPECULATIVE_MODEL_ID is empty"
        exit 1
    fi
    wait_for_model_dir "$SPEC_MODEL_DIR" "speculative"
fi

# Now wait for both .success files (still sequential, but fast)
echo "⏳ Waiting for .success files..."

# Base .success
count=0
while [ $count -lt $MAX_WAIT ]; do
    if [ -f "$BASE_MODEL_DIR/.success" ]; then
        echo "✅ base model .success file found."
        break
    fi
    if [ "$DEBUG_LOGS" = "true" ]; then
        echo "⏳ Still waiting for base .success file... (${count}s / $MAX_WAIT)"
    fi
    sleep $WAIT_INTERVAL
    count=$((count + WAIT_INTERVAL))
done

if [ $count -ge $MAX_WAIT ]; then
    echo "❌ ERROR: base model .success file not found within $MAX_WAIT seconds."
    exit 1
fi

# Speculative .success (if enabled)
if [ "$ENABLE_SPEC" = "true" ]; then
    count=0
    while [ $count -lt $MAX_WAIT ]; do
        if [ -f "$SPEC_MODEL_DIR/.success" ]; then
            echo "✅ speculative model .success file found."
            break
        fi
        if [ "$DEBUG_LOGS" = "true" ]; then
            echo "⏳ Still waiting for speculative .success file... (${count}s / $MAX_WAIT)"
        fi
        sleep $WAIT_INTERVAL
        count=$((count + WAIT_INTERVAL))
    done

    if [ $count -ge $MAX_WAIT ]; then
        echo "❌ ERROR: speculative model .success file not found within $MAX_WAIT seconds."
        exit 1
    fi
fi

echo "--- Cache Validation Complete. Starting main container. ---"
exit 0
