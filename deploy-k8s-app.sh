
#!/bin/bash
set -euo pipefail

IMAGE="docjaisumers/web-project:v1"
DEPLOYMENT="empowernest-web"
SERVICE="empowernest-web"
SECRET="empowernest-env"
PUBLIC_HOST="54.187.161.82"

# STEP 1: Verify Kubernetes cluster connectivity
echo "=== Kubernetes cluster information ==="
kubectl cluster-info
kubectl get nodes

# Verify Kubernetes Secret exists
echo "=== Verify Kubernetes Secret ==="
kubectl get secret "$SECRET"

# STEP 2: Create the Deployment using Docker Hub image
echo "=== Create or update Deployment ==="

if kubectl get deployment "$DEPLOYMENT" >/dev/null 2>&1; then
  kubectl set image "deployment/$DEPLOYMENT" \
    "web-project=$IMAGE"
else
  kubectl create deployment "$DEPLOYMENT" \
    --image="$IMAGE" \
    --port=80
fi

# Always pull the latest image when a pod starts
kubectl patch deployment "$DEPLOYMENT" \
  --type=json \
  -p='[{"op":"add","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Always"}]'

# STEP 3: Expose the Deployment using NodePort
echo "=== Create NodePort Service ==="

if ! kubectl get service "$SERVICE" >/dev/null 2>&1; then
  kubectl expose deployment "$DEPLOYMENT" \
    --type=NodePort \
    --port=80 \
    --target-port=80
fi

# Configure environment variables
echo "=== Configure environment variables ==="
kubectl set env "deployment/$DEPLOYMENT" \
  --from="secret/$SECRET"

# Set the public application URL
NODEPORT=$(kubectl get service "$SERVICE" \
  -o jsonpath='{.spec.ports[0].nodePort}')

PUBLIC_URL="http://${PUBLIC_HOST}:${NODEPORT}"

kubectl set env "deployment/$DEPLOYMENT" \
  NEXTAUTH_URL="$PUBLIC_URL"

# STEP 4: Scale the Deployment to three replicas
echo "=== Scale Deployment ==="
kubectl scale deployment "$DEPLOYMENT" --replicas=3

kubectl rollout restart "deployment/$DEPLOYMENT"
kubectl rollout status "deployment/$DEPLOYMENT" --timeout=300s

# STEP 5: Display final verification
echo "=== Verification ==="
kubectl get pods -l "app=$DEPLOYMENT" -o wide
kubectl get deployments "$DEPLOYMENT"
kubectl get services "$SERVICE"

echo "=== Application URL ==="
echo "$PUBLIC_URL"
