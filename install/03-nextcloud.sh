#!/bin/bash
set -e

echo "[*] Adding NextCloud Helm repo..."
helm repo add nextcloud https://nextcloud.github.io/helm/
helm repo update

echo "[*] Creating namespace 'nextcloud'..."
kubectl create namespace nextcloud || true

echo "[*] Deploying NextCloud via Helm..."
helm upgrade --install nextcloud nextcloud/nextcloud \
  --namespace nextcloud \
  --values helm/nextcloud/values.yaml

echo "[*] Waiting for NextCloud pod..."
kubectl rollout status deployment/nextcloud -n nextcloud
