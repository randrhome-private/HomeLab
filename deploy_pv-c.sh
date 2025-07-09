#!/bin/bash
kubectl apply -f k8s/nextcloud/postgres-pv.yaml
kubectl apply -f k8s/nextcloud/postgres-pvc.yaml
kubectl apply -f k8s/nextcloud/nextcloud-pv.yaml
kubectl apply -f k8s/nextcloud/nextcloud-pvc.yaml 