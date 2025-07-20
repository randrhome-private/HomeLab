#!/bin/bash
set -e

LIBRARY_PATH="/mnt/data/immich-library"

echo "🔁 Cleaning up any existing Immich or Postgres deployments..."

helm uninstall immich -n immich 2>/dev/null || echo "ℹ️ Immich release not found."
helm uninstall cnpg -n immich 2>/dev/null || echo "ℹ️ CNPG release not found."
kubectl delete cluster immich-postgres -n immich --ignore-not-found
kubectl delete secret immich-postgres-user -n immich --ignore-not-found
kubectl delete pvc -n immich immich-library-pvc --ignore-not-found
kubectl delete pv immich-library-pv --ignore-not-found
kubectl delete namespace immich --ignore-not-found --wait=true --timeout=300s

echo "✅ Cleanup complete."

echo "📁 Creating hostPath directory for Immich library..."
sudo mkdir -p "$LIBRARY_PATH"
echo "🔧 Setting correct ownership for hostPath directory..."
sudo chown -R 26:26 "$LIBRARY_PATH"

echo "📦 Creating namespace 'immich'..."
kubectl create namespace immich

echo "📥 Adding CloudNativePG Helm repo..."
helm repo add cnpg https://cloudnative-pg.github.io/charts || true
helm repo update

echo "📦 Installing CloudNativePG controller in 'immich'..."
helm install cnpg cnpg/cloudnative-pg \
  --namespace immich \
  --set controllerManager.watchNamespace=immich

echo "⏳ Waiting for CNPG controller pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=cloudnative-pg -n immich --timeout=180s

echo "🔐 Creating PostgreSQL user secret..."
kubectl apply -f secret.yaml

echo "📄 Applying PV and PVC..."
kubectl apply -f pv.yaml
kubectl apply -f pvc.yaml

echo "🚀 Applying CNPG PostgreSQL Cluster..."
kubectl apply -f postgres-values.yaml

echo "⏳ Waiting for PostgreSQL cluster pod to be ready..."
kubectl wait --for=condition=ready pod -l cnpg.io/cluster=immich-postgres -n immich --timeout=180s || echo "⚠️ Postgres pod not ready yet. Check logs below:"
kubectl get pods -n immich
kubectl logs -l cnpg.io/cluster=immich-postgres -n immich --tail=50

echo "✅ Deployment complete."
echo "🔍 Status:"
kubectl get pods -n immich
kubectl get pvc -n immich
kubectl get pv
kubectl get cluster -n immich

echo "🧩 Use this Postgres host in Immich config:"
echo "  immich-postgres-rw.immich.svc.cluster.local"

echo "🚀 Installing Immich..."
helm install --namespace immich immich oci://ghcr.io/immich-app/immich-charts/immich -f immich-values.yaml
echo "⏳ Waiting for Immich pod to be ready..."
kubectl wait --for=condition=ready pod -l app.kubernetes.io/name=immich -n immich --timeout=180s || echo "⚠️ Immich pod not ready yet. Check logs."

kubectl get pods -n immich

echo "⏳ Waiting for Immich server pod to be ready..."

sleep 15
kubectl patch svc immich-server -n immich \
  --type='merge' \
  -p '{
    "spec": {
      "type": "NodePort",
      "ports": [{
        "port": 2283,
        "targetPort": 2283,
        "protocol": "TCP",
        "nodePort": 32283,
        "name": "http"
      }]
    }
  }'
