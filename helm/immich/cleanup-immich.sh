#!/bin/bash
set -euo pipefail

NAMESPACE="immich"
IMMICH_RELEASE="immich"
POSTGRES_RELEASE="postgres"

PVC_NAMES=(
  "immich-data"
  "postgres-immich-pvc"
  "ml-cache-pvc"
)

PV_NAMES=(
  "immich-data"
  "postgres-immich-pv"
  "ml-cache-pv"
)

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

echo "🧨 Deleting Helm releases..."
helm uninstall "$IMMICH_RELEASE" -n "$NAMESPACE" || true
helm uninstall "$POSTGRES_RELEASE" -n "$NAMESPACE" || true

echo "🧼 Deleting namespace: $NAMESPACE"
kubectl delete namespace "$NAMESPACE" --ignore-not-found || true

echo "🧹 Cleaning up local data directories..."
LOCAL_PATH="/mnt/data/immich"
if [ -d "$LOCAL_PATH" ]; then
  echo "  - Removing $LOCAL_PATH"
  sudo rm -rf "$LOCAL_PATH"
fi

echo "🗑️ Deleting PersistentVolumes..."
for pv in "${PV_NAMES[@]}"; do
  kubectl delete pv "$pv" --ignore-not-found || true
done

echo "✅ Immich cleanup complete."
