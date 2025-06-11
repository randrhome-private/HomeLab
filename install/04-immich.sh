#!/bin/bash
set -e

echo "[*] Adding Helm repos..."
helm repo add immich https://immich-app.github.io/immich-charts || true
helm repo add bitnami https://charts.bitnami.com/bitnami || true
helm repo update

echo "[*] Creating namespace 'immich'..."
kubectl create namespace immich || true

echo "[*] Installing PostgreSQL (external DB for Immich)..."
helm upgrade --install immich-postgresql bitnami/postgresql \
  --namespace immich \
  --set auth.postgresPassword=immichpass \
  --set auth.username=immich \
  --set auth.password=immichpass \
  --set auth.database=immich

echo "[*] Deploying Immich..."
helm upgrade --install immich immich/immich \
  --namespace immich \
  --values helm/immich/values.yaml

echo "[*] Waiting for Immich rollout..."
kubectl rollout status deployment/immich-server -n immich
