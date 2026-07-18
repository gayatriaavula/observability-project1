# Installs Argo CD via the upstream Helm chart as soon as the cluster it's
# passed (through the root module's helm provider config) is ready -- no
# separate manual `install-argocd.sh` step needed. Replaces the initial
# admin password print that script used to do: fetch it with
#   kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d
resource "helm_release" "argocd" {
  name             = "argocd"
  namespace        = var.namespace
  create_namespace = true

  repository = "https://argoproj.github.io/argo-helm"
  chart      = "argo-cd"
  version    = var.chart_version

  values = [yamlencode(var.values)]

  wait    = true
  timeout = 600
}
