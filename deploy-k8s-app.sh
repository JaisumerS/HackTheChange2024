#!/usr/bin/env bash
set -euo pipefail

IMAGE="docjaisumers/web-project:v1"
DEPLOYMENT="empowernest-web"
SERVICE="empowernest-web"
SECRET="empowernest-env"

# Replace with the public IPv4 of ansible-node2
PUBLIC_HOST="54.187.161.82"

command -v kubectl >/dev/null || {
  echo "kubectl is not installed" >&2
  exit 1
}

# STEP 1: Verify Kubernetes cluster connectivity
echo "=== Kubernetes cluster information ==="
kubectl cluster-info
kubectl get nodes

# Additional: Verify environment variables are configured
echo "=== Verify Kubernetes Secret ==="
kubectl get secret "$SECRET" >/dev/null

# STEP 2: Create the Deployment using Docker Hub image
echo "=== Create or update Deployment ==="

if kubectl get deployment "$DEPLOYMENT" >/dev/null 2>&1; then
  kubectl set image "deployment/$DEPLOYMENT" \
    "$DEPLOYMENT=$IMAGE"
else
  kubectl create deployment "$DEPLOYMENT" \
    --image="$IMAGE" \
    --port=80
fi

# Ensure the latest v1 image is pulled
kubectl patch deployment "$DEPLOYMENT" \
  --type=strategic \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"empowernest-web","imagePullPolicy":"Always"}]}}}}'

# STEP 3: Expose the Deployment using NodePort
echo "=== Create NodePort Service ==="

if ! kubectl get service "$SERVICE" >/dev/null 2>&1; then
  kubectl expose deployment "$DEPLOYMENT" \
    --type=NodePort \
    --port=80 \
    --target-port=80
fi

# Additional: Inject environment variables from Kubernetes Secret
echo "=== Configure environment variables ==="

kubectl set env "deployment/$DEPLOYMENT" \
  --from="secret/$SECRET"

# Get the NodePort assigned by Kubernetes
NODEPORT=$(kubectl get service "$SERVICE" \
  -o jsonpath='{.spec.ports[0].nodePort}')

if [[ "$PUBLIC_HOST" == "REPLACE_WITH_NODE2_PUBLIC_IP" ]]; then
  echo "ERROR: Set PUBLIC_HOST to the node2 public IPv4" >&2
  exit 1
fi

PUBLIC_URL="http://${PUBLIC_HOST}:${NODEPORT}"

kubectl set env "deployment/$DEPLOYMENT" \
  NEXTAUTH_URL="$PUBLIC_URL"

# STEP 4: Scale to at least three replicas
echo "=== Scale Deployment to three replicas ==="
kubectl scale deployment "$DEPLOYMENT" --replicas=3

# Restart to apply current image and configuration
kubectl rollout restart "deployment/$DEPLOYMENT"

kubectl rollout status "deployment/$DEPLOYMENT" \
  --timeout=300s

# STEP 5: Display final verification
echo "=== Verification ==="

kubectl get pods -l "app=$DEPLOYMENT" -o wide
kubectl get deployments "$DEPLOYMENT"
kubectl get services "$SERVICE"

echo "=== Application URL ==="
echo "$PUBLIC_URL"