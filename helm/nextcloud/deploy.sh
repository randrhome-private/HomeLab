#!/bin/bash
set -euo pipefail

# 1. Prep the volume directory on the host BEFORE Helm sees it
echo "📁 Ensuring permissions on postgres host path..."
sudo mkdir -p /mnt/data/nextcloud/postgres
sudo chown -R 1001:1001 /mnt/data/nextcloud/postgres

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
