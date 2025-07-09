#!/bin/bash
set -euo pipefail

NAMESPACE="nextcloud"
RELEASE_NAME="nextcloud"
PVC_NAMES=("nextcloud-data" "postgres-nextcloud-pvc" "nextcloud-pvc" "nextcloud-postgresql")

echo "🔄 Deleting PVCs..."
for pvc in "${PVC_NAMES[@]}"; do
  echo "  - Deleting PVC: $pvc"
  kubectl delete pvc "$pvc" -n "$NAMESPACE" --ignore-not-found --wait=false || true
done

# Wait briefly, then forcibly remove finalizers if needed
sleep 5

for pvc in "${PVC_NAMES[@]}"; do
  phase=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath="{.metadata.deletionTimestamp}" 2>/dev/null || echo "")
  if [[ -n "$phase" ]]; then
    echo "  ⚠️ PVC $pvc is stuck deleting — removing finalizers"
    kubectl patch pvc "$pvc" -n "$NAMESPACE" -p '{"metadata":{"finalizers":[]}}' --type=merge
  fi
done

echo "🧨 Deleting Helm release: $RELEASE_NAME"
helm uninstall "$RELEASE_NAME" -n "$NAMESPACE" || true

echo "🧼 Deleting namespace: $NAMESPACE"
kubectl delete namespace "$NAMESPACE" --ignore-not-found || true

echo "🧹 Cleaning up local data directories..."
LOCAL_PATHS=(
  "/mnt/data/nextcloud"
  "/mnt/data/postgres"
  "/mnt/data/postgresql"
  "/mnt/data/postgres-nextcloud"
)

for path in "${LOCAL_PATHS[@]}"; do
  if [ -d "$path" ]; then
    echo "  - Removing $path"
    rm -rf "$path"
  fi
done
kubectl delete pv postgres-nextcloud-pv
kubectl delete pv nextcloud-data

echo "✅ Cleanup complete."
