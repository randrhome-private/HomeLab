
# Jellyfin Helm Deployment Guide

This markdown file outlines all the essential commands used to deploy Jellyfin via Helm with custom persistent volumes.

---

## 🧱 Step 1: Add the Helm Repository

```bash
helm repo add jellyfin https://jellyfin.github.io/jellyfin-helm
helm repo update
```

---

## 📦 Step 2: Pull Down the Helm Chart Locally

```bash
helm pull jellyfin/jellyfin --untar
```

This creates a local `jellyfin/` folder with the full chart contents.

---

## 📋 Step 3: Extract Default Values to Customize

```bash
helm show values jellyfin/jellyfin > helm/jellyfin/values.yaml
```

---

## 📁 Step 4: Create Persistent Volumes

Create a file `k8s/jellyfin/pvc.yaml` and define your persistent volume and claim. Then apply it:

```bash
kubectl create namespace jellyfin
kubectl apply -f k8s/jellyfin/pvc.yaml
```

---

## ⚙️ Step 5: Customize Your values.yaml

Edit `helm/jellyfin/values.yaml` and configure:

```yaml
persistence:
  media:
    enabled: true
    existingClaim: jellyfin-media
  config:
    enabled: true
    existingClaim: jellyfin-config
```

---

## 🚀 Step 6: Deploy with Helm

```bash
helm upgrade --install jellyfin jellyfin/jellyfin   --namespace jellyfin   --values helm/jellyfin/values.yaml
```

---

## 🧪 Optional: Render to YAML for Debugging

```bash
helm template jellyfin jellyfin/jellyfin   --namespace jellyfin   --values helm/jellyfin/values.yaml > rendered/jellyfin.yaml

kubectl apply -f rendered/jellyfin.yaml
```

---

## ✅ You're Done!

Jellyfin should now be running in your cluster with persistent media/config storage.
