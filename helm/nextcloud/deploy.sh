#!/bin/bash
set -euo pipefail


REPO_NAME="nextcloud"
REPO_URL="https://nextcloud.github.io/helm/"

# Check if Helm repo is already added
if ! helm repo list | grep -q "^${REPO_NAME}[[:space:]]"; then
  echo "[*] Adding NextCloud Helm repo..."
  helm repo add "$REPO_NAME" "$REPO_URL"
else
  echo "[+] Helm repo '$REPO_NAME' already exists. Skipping add."
fi

# Update repo index to get latest chart info
echo "[*] Updating Helm repo..."
helm repo update

# Check for local chart directory and pull if not present
if [ ! -d "$REPO_NAME" ]; then
  echo "[*] 'nextcloud/' directory not found. Pulling chart to local dir..."
  helm pull "$REPO_NAME/nextcloud" --untar
else
  echo "[+] 'nextcloud/' directory already exists. Skipping pull."
fi

# 1. Prep the volume directory on the host BEFORE Helm sees it
echo "📁 Ensuring permissions on postgres host path..."
sudo mkdir -p /mnt/data/nextcloud/postgres
sudo chown -R 1001:1001 /mnt/data/nextcloud/postgres

mkdir -p /mnt/data/nextcloud/data
chown -R 33:33 /mnt/data/nextcloud/data
chmod -R 775 /mnt/data/nextcloud/data

# 2. Create K8s objects and namespace
echo "📦 Creating namespace and persistent volumes..."
kubectl create namespace nextcloud --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -f ../../k8s/nextcloud/postgres-pv.yaml
kubectl apply -f ../../k8s/nextcloud/postgres-pvc.yaml
kubectl apply -f ../../k8s/nextcloud/nextcloud-pv.yaml
kubectl apply -f ../../k8s/nextcloud/nextcloud-pvc.yaml


# 3. Deploy Helm release
echo "🚀 Installing Nextcloud Helm chart..."
helm upgrade --install nextcloud ./nextcloud --namespace nextcloud -f values.yaml

echo "✅ Deployment complete. Pods will initialize shortly."
