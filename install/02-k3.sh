#!/bin/bash
set -e

echo "[*] Installing K3s (single-node cluster)..."
curl -sfL https://get.k3s.io | sh -

echo "[*] Exporting kubeconfig for kubectl..."
mkdir -p ~/.kube
cp /etc/rancher/k3s/k3s.yaml ~/.kube/config
chown $(id -u):$(id -g) ~/.kube/config
export KUBECONFIG=~/.kube/config

echo "[*] Verifying K3s cluster status..."
kubectl get nodes

echo "[*] Installing Helm..."
curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash

echo "[*] Done. K3s and Helm are installed and ready."
