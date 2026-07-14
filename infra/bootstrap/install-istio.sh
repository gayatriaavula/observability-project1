#!/usr/bin/env bash
# Installs Istio's control plane (istiod) into istio-system and a dedicated
# ingress gateway into istio-ingress, matching the namespace layout used by
# the manifests in k8s/base. Requires: helm, kubectl pointed at the cluster.
set -euo pipefail

ISTIO_VERSION="${ISTIO_VERSION:-1.30.2}"

helm repo add istio https://istio-release.storage.googleapis.com/charts
helm repo update

# CRDs + shared cluster resources
helm upgrade --install istio-base istio/base \
  --namespace istio-system --create-namespace \
  --version "${ISTIO_VERSION}" \
  --wait

# Control plane (istiod)
helm upgrade --install istiod istio/istiod \
  --namespace istio-system \
  --version "${ISTIO_VERSION}" \
  --set meshConfig.accessLogFile=/dev/stdout \
  --wait

# Dedicated ingress gateway, kept in its own namespace so it can be scaled
# and upgraded independently from istiod.
kubectl create namespace istio-ingress --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace istio-ingress istio-injection=enabled --overwrite

helm upgrade --install istio-ingressgateway istio/gateway \
  --namespace istio-ingress \
  --version "${ISTIO_VERSION}" \
  --wait

# Enable sidecar injection for the application namespace.
kubectl create namespace orders-backend --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace orders-backend istio-injection=enabled --overwrite

echo "Istio control plane and ingress gateway installed."
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
kubectl get svc istio-ingressgateway -n istio-ingress
