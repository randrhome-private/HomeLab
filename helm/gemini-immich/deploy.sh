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

echo "📄 Creating PV and PVC manifests..."
cat <<EOF > pv.yaml
apiVersion: v1
kind: PersistentVolume
metadata:
  name: immich-library-pv
spec:
  capacity:
    storage: 1000Gi
  accessModes:
    - ReadWriteOnce
  persistentVolumeReclaimPolicy: Retain
  storageClassName: local-path
  hostPath:
    path: "$LIBRARY_PATH"
EOF

cat <<EOF > pvc.yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: immich-library-pvc
  namespace: immich
spec:
  accessModes:
    - ReadWriteOnce
  resources:
    requests:
      storage: 1000Gi
  storageClassName: local-path
EOF

echo "📄 Creating CNPG PostgreSQL Cluster manifest..."
cat <<EOF > postgres-values.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: immich-postgres
  namespace: immich
spec:
  imageName: ghcr.io/tensorchord/cloudnative-pgvecto.rs:16.5-v0.3.0
  instances: 1
  postgresql:
    shared_preload_libraries:
      - "vectors.so"
  managed:
    roles:
      - name: immich
        superuser: true
        login: true
  bootstrap:
    initdb:
      database: immich
      owner: immich
      secret:
        name: immich-postgres-user
      postInitSQL:
        - CREATE EXTENSION IF NOT EXISTS "vectors";
        - CREATE EXTENSION IF NOT EXISTS "cube" CASCADE;
        - CREATE EXTENSION IF NOT EXISTS "earthdistance" CASCADE;
  storage:
    size: 20Gi
    storageClass: local-path
EOF

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
kubectl create secret generic immich-postgres-user \
  --from-literal=username=immich \
  --from-literal=password=strongPassword \
  -n immich

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


echo "📥 Adding Immich Helm repo..."
helm repo add immich https://charts.immich.app || true
helm repo update

echo "📄 Creating Immich values.yaml..."
cat <<EOF > immich-values.yaml
postgresql:
  enabled: false

redis:
  enabled: true
  architecture: standalone
  auth:
    enabled: false
  master:
    persistence:
      enabled: false

env:
  DB_HOSTNAME: "immich-postgres-rw.immich.svc.cluster.local"
  DB_USERNAME: "immich"
  DB_DATABASE_NAME: "immich"
  DB_PASSWORD: "strongPassword"

immich:
  persistence:
    enabled: true
    library:
      existingClaim: immich-library-pvc

  ingress:
    enabled: false

  database:
    host: immich-postgres-rw.immich.svc.cluster.local
    port: 5432
    username: immich
    password: strongPassword
    databaseName: immich

EOF

echo "🚀 Installing Immich..."
helm install immich immich/immich -n immich -f immich-values.yaml

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
