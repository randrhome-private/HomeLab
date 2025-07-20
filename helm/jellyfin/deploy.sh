#!/bin/bash
set -e

LIBRARY_PATH="/mnt/data/jellyfin/media/"

echo "🔁 Cleaning up any existing jellyfin."

helm uninstall jellyfin -n jellyfin 2>/dev/null || echo "ℹ️ jellyfin release not found."
kubectl delete pvc -n jellyfin jellyfin-media-pvc --ignore-not-found
kubectl delete pv jellyfin-media-pv --ignore-not-found
kubectl delete pvc -n jellyfin jellyfin-config-pvc --ignore-not-found
kubectl delete pv jellyfin-config-pv --ignore-not-found
kubectl delete namespace jellyfin --ignore-not-found --wait=true --timeout=300s

echo "✅ Cleanup complete."

helm repo add jellyfin https://jellyfin.github.io/jellyfin-helm
helm repo update

# echo "📁 Creating hostPath directory for jellyfin library..."
# sudo mkdir -p "$LIBRARY_PATH"
# echo "🔧 Setting correct ownership for hostPath directory..."
# sudo chown -R 26:26 "$LIBRARY_PATH"

echo "📦 Creating namespace 'jellyfin'..."
kubectl create namespace jellyfin

echo "📄 Applying PV and PVC..."
kubectl apply -f jellyfin-media-pv.yaml
kubectl apply -f jellyfin-config-pv.yaml
kubectl apply -f jellyfin-media-pvc.yaml
kubectl apply -f jellyfin-config-pvc.yaml


echo "✅ Deployment complete."
echo "🔍 Status:"
kubectl get pods -n jellyfin
kubectl get pvc -n jellyfin
kubectl get pv
kubectl get cluster -n jellyfin

echo "🚀 Installing jellyfin..."
helm install jellyfin jellyfin/jellyfin -n jellyfin -f jellyfin-values.yaml
echo "⏳ Waiting for jellyfin pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=jellyfin -n jellyfin --timeout=180s || echo "⚠️ jellyfin pod not ready yet. Check logs."

kubectl get pods -n jellyfin

echo "⏳ Waiting for jellyfin server pod to be ready..."

sleep 15
kubectl patch svc jellyfin -n jellyfin \
  --type='merge' \
  -p '{
    "spec": {
      "type": "NodePort",
      "ports": [{
        "port": 8096,
        "targetPort": 8096,
        "protocol": "TCP",
        "nodePort": 30096,
        "name": "http"
      }]
    }
  }'
