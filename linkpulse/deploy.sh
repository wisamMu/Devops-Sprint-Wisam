#!/bin/bash
# Runs ON THE EC2 (started by the workflow through SSM).
# Usage: deploy.sh <registry>/linkpulse:<git-sha>
set -euo pipefail

IMAGE="$1"
REGISTRY="${IMAGE%%/*}"   # part before the first /
SHA="${IMAGE##*:}"        # part after the last :
RAW="https://raw.githubusercontent.com/wisamMu/Devops-Sprint-Wisam/$SHA/linkpulse/k8s"
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml

echo "1. ECR password for k3s (from the EC2's own role, valid 12 h)"
kubectl create secret docker-registry ecr-pull \
  --docker-server="$REGISTRY" \
  --docker-username=AWS \
  --docker-password="$(aws ecr get-login-password --region us-east-1)" \
  --dry-run=client -o yaml | kubectl apply -f -

echo "2. Apply the manifests of this commit, with the new image"
curl -fsSL "$RAW/deployment.yaml" | sed "s|IMAGE_PLACEHOLDER|$IMAGE|" | kubectl apply -f -
curl -fsSL "$RAW/service.yaml" | kubectl apply -f -

echo "3. Wait for the rolling update; roll back if it fails"
if ! kubectl rollout status deployment/linkpulse --timeout=120s; then
  echo "rollout FAILED - rolling back"
  kubectl rollout undo deployment/linkpulse
  exit 1
fi

echo "4. Health check through the Service"
curl -fsS --retry 10 --retry-delay 2 --retry-all-errors localhost/health.html
echo "deployed $IMAGE"
