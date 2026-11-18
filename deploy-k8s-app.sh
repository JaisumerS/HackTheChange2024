#!/usr/bin/env bash
set -euo pipefail

IMAGE="docjaisumers/web-project:v1"
DEPLOYMENT="empowernest-web"
SERVICE="empowernest-web"

command -v kubectl >/dev/null || { echo "kubectl is not installed" >&2; exit 1; }

echo "=== Kubernetes cluster information ==="
kubectl cluster-info
kubectl get nodes

echo "=== Create or update deployment ==="
kubectl create deployment "$DEPLOYMENT" \
  --image="$IMAGE" --port=80 --dry-run=client -o yaml | kubectl apply -f -

echo "=== Create or update NodePort service ==="
kubectl expose deployment "$DEPLOYMENT" \
  --type=NodePort --port=80 --target-port=80 \
  --dry-run=client -o yaml | kubectl apply -f -

echo "=== Scale deployment to three replicas ==="
kubectl scale deployment "$DEPLOYMENT" --replicas=3
kubectl rollout status "deployment/$DEPLOYMENT" --timeout=180s

echo "=== Verification ==="
kubectl get deployments "$DEPLOYMENT"
kubectl get pods -l "app=$DEPLOYMENT" -o wide
kubectl get services "$SERVICE"
