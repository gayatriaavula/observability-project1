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

# replicaCount=2 (one per node) so both AZs have a local backend --
# otherwise, with cross-zone load balancing off by default on the classic
# ELB this Service provisions, whichever AZ doesn't have the single replica
# is unreachable through that AZ's ELB IP. The cross-zone annotation closes
# the same gap from the other side (belt and suspenders): even a future
# single-replica window (rollout, node drain) stays reachable through every
# AZ's IP instead of only the one hosting the pod.
helm upgrade --install istio-ingressgateway istio/gateway \
  --namespace istio-ingress \
  --version "${ISTIO_VERSION}" \
  --set replicaCount=2 \
  --set-string 'service.annotations.service\.beta\.kubernetes\.io/aws-load-balancer-cross-zone-load-balancing-enabled=true' \
  --set 'service.ports[0].name=status-port' --set 'service.ports[0].port=15021' --set 'service.ports[0].targetPort=15021' \
  --set 'service.ports[1].name=http2' --set 'service.ports[1].port=80' --set 'service.ports[1].targetPort=80' \
  --set 'service.ports[2].name=https' --set 'service.ports[2].port=443' --set 'service.ports[2].targetPort=443' \
  --set 'service.ports[3].name=argocd' --set 'service.ports[3].port=8443' --set 'service.ports[3].targetPort=8443' \
  --set 'service.ports[4].name=grafana' --set 'service.ports[4].port=3000' --set 'service.ports[4].targetPort=3000' \
  --set 'service.ports[5].name=prometheus' --set 'service.ports[5].port=9090' --set 'service.ports[5].targetPort=9090' \
  --wait

# The chart's own HPA (default minReplicas: 1) fights the replicaCount above
# once metrics-server -- not installed in this cluster -- would normally
# drive it; without metrics-server it just falls back to minReplicas
# unconditionally. Raise the floor so autoscaling can never shrink back
# below the redundancy this script just set up.
kubectl -n istio-ingress patch hpa istio-ingressgateway --type merge -p '{"spec":{"minReplicas":2}}'

# Enable sidecar injection for the application namespace.
kubectl create namespace orders-backend --dry-run=client -o yaml | kubectl apply -f -
kubectl label namespace orders-backend istio-injection=enabled --overwrite

# Public routes for the admin consoles (ArgoCD/Grafana/Prometheus), each on
# its own port on the same Load Balancer rather than a path prefix -- these
# tools assume they're served from "/", and Grafana in particular needs
# extra root_url config to work correctly behind a subpath. ArgoCD
# terminates its own TLS internally, so its port is a passthrough; Grafana
# and Prometheus don't, so theirs terminate TLS at the gateway using the
# same cert as the app.
kubectl apply -f "$(dirname "${BASH_SOURCE[0]}")/platform-gateway.yaml"

echo "Istio control plane and ingress gateway installed."
kubectl get pods -n istio-system
kubectl get pods -n istio-ingress
kubectl get svc istio-ingressgateway -n istio-ingress
