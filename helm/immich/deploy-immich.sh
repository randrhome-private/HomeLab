#!/bin/bash
set -euo pipefail

# IMMICH Chart Setup
IMMICH_REPO_NAME="immich"
IMMICH_REPO_URL="https://immich-app.github.io/immich-charts/"

# POSTGRES (Immich-recommended) chart setup
POSTGRES_REPO_NAME="bitnami"
POSTGRES_REPO_URL="https://charts.bitnami.com/bitnami"

# Add Immich repo if missing
if ! helm repo list | grep -q "^${IMMICH_REPO_NAME}[[:space:]]"; then
  echo "[*] Adding Immich Helm repo..."
  helm repo add "$IMMICH_REPO_NAME" "$IMMICH_REPO_URL"
else
  echo "[+] Helm repo '$IMMICH_REPO_NAME' already exists. Skipping add."
fi

# Add Bitnami repo for PostgreSQL if missing
if ! helm repo list | grep -q "^${POSTGRES_REPO_NAME}[[:space:]]"; then
  echo "[*] Adding Bitnami Helm repo (for Postgres)..."
  helm repo add "$POSTGRES_REPO_NAME" "$POSTGRES_REPO_URL"
else
  echo "[+] Helm repo '$POSTGRES_REPO_NAME' already exists. Skipping add."
fi

# Update repos
echo "[*] Updating Helm repos..."
helm repo update

# Pull Immich chart if needed
if [ ! -d "$IMMICH_REPO_NAME" ]; then
  echo "[*] 'immich/' directory not found. Pulling chart to local dir..."
  helm pull "$IMMICH_REPO_NAME/immich" --untar
else
  echo "[+] 'immich/' directory already exists. Skipping pull."
fi

# Pull Bitnami Postgres chart if needed
if [ ! -d "postgresql" ]; then
  echo "[*] 'postgresql/' directory not found. Pulling Postgres chart to local dir..."
  helm pull "$POSTGRES_REPO_NAME/postgresql" --untar
else
  echo "[+] 'postgresql/' directory already exists. Skipping pull."
fi

# -----------------------------------------------------------------------------
# Prepare host directories and permissions
echo "📁 Setting up host paths and permissions..."

# PostgreSQL (runs as UID 1001)
sudo mkdir -p /mnt/data/immich/postgres
sudo chown -R 1001:1001 /mnt/data/immich/postgres

# Immich media library (runs as UID 33)
sudo mkdir -p /mnt/data/immich/data
sudo chown -R 33:33 /mnt/data/immich/data
sudo chmod -R 775 /mnt/data/immich/data

# ML Cache (UID 1000 is common default)
sudo mkdir -p /mnt/data/immich/ml-cache
sudo chown -R 1000:1000 /mnt/data/immich/ml-cache

# -----------------------------------------------------------------------------
# Create namespace and apply PV/PVCs
echo "📦 Creating namespace and applying PV/PVCs..."
kubectl create namespace immich --dry-run=client -o yaml | kubectl apply -f -

kubectl apply -f ../../k8s/immich/postgres-pv.yaml
kubectl apply -f ../../k8s/immich/postgres-pvc.yaml
kubectl apply -f ../../k8s/immich/immich-pv.yaml
kubectl apply -f ../../k8s/immich/immich-pvc.yaml
kubectl apply -f ../../k8s/immich/machine-learning-pv.yaml
kubectl apply -f ../../k8s/immich/machine-learning-pvc.yaml

# -----------------------------------------------------------------------------
# Install Postgres FIRST
echo "🐘 Installing PostgreSQL chart..."
helm upgrade --install postgres postgresql/ \
  --namespace immich \
  -f ./postgres-values.yaml

# -----------------------------------------------------------------------------
# Deploy Immich
echo "🚀 Installing Immich Helm chart..."
helm upgrade --install immich immich/ \
  --namespace immich \
  -f ./immich-values.yaml

echo "✅ Immich deployment complete. Pods will initialize shortly."
