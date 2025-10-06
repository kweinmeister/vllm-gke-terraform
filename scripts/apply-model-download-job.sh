#!/bin/bash
set -euo pipefail
exec > >(tee -a /dev/stderr) 2>&1

# Validate required environment variables
required_vars=("JOB_NAME" "NAMESPACE" "PVC_NAME" "CONFIGMAP_NAME" "SECRET_NAME" "MODEL_ID" "SPECULATIVE_MODEL_ID")
for var in "${required_vars[@]}"; do
  if [[ -z "${!var}" ]]; then
    echo "❌ ERROR: Environment variable $var is required but not set." >&2
    exit 1
  fi
done

if kubectl get job "$JOB_NAME" -n "$NAMESPACE" >/dev/null 2>&1; then
  echo "⚠️  Deleting existing Job..."
  kubectl delete job "$JOB_NAME" -n "$NAMESPACE" --force --grace-period=0 >/dev/null 2>&1 || true
  sleep 2
fi

kubectl apply -n "$NAMESPACE" -f - <<EOF
apiVersion: batch/v1
kind: Job
metadata:
  name: $JOB_NAME
spec:
  ttlSecondsAfterFinished: 86400
  backoffLimit: 3
  template:
    spec:
      restartPolicy: OnFailure
      volumes:
      - name: model-cache
        persistentVolumeClaim:
          claimName: $PVC_NAME
      - name: download-script
        configMap:
          name: $CONFIGMAP_NAME
          defaultMode: 0755
      containers:
      - name: downloader
        image: python:3.13-slim
        imagePullPolicy: IfNotPresent
        command: ["/bin/sh", "-c", "pip install -q huggingface-hub && python /scripts/download.py"]
        env:
        - name: HF_HOME
          value: /root/.cache/huggingface
        - name: HF_TOKEN
          valueFrom:
            secretKeyRef:
              name: $SECRET_NAME
              key: token
        - name: MODEL_ID
          value: "$MODEL_ID"
        - name: SPECULATIVE_MODEL_ID
          value: "$SPECULATIVE_MODEL_ID"
        - name: PYTHONUNBUFFERED
          value: "1"
        volumeMounts:
        - name: model-cache
          mountPath: /root/.cache/huggingface
        - name: download-script
          mountPath: /scripts
          readOnly: true
        resources:
          requests:
            cpu: "1"
            memory: "4Gi"
          limits:
            cpu: "2"
            memory: "8Gi"
EOF

echo "✅ Job applied successfully."
