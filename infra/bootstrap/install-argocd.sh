#!/usr/bin/env bash
# Installs Argo CD into the argocd namespace and prints the initial admin
# password. Requires: kubectl pointed at the cluster.
set -euo pipefail

ARGOCD_VERSION="${ARGOCD_VERSION:-v2.11.4}"

kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "Waiting for Argo CD server to become ready..."
kubectl -n argocd wait --for=condition=available --timeout=300s deployment/argocd-server

echo
echo "Argo CD installed. Initial admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath='{.data.password}' | base64 -d
echo
echo
echo "Port-forward the UI with:"
echo "  kubectl -n argocd port-forward svc/argocd-server 8080:443"
echo
echo "Then clone observability-project1-gitops and apply its root-app.yaml to register this repo."
