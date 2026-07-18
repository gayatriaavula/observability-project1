variable "namespace" {
  description = "Namespace Argo CD is installed into (created if it doesn't exist)"
  type        = string
  default     = "argocd"
}

variable "chart_version" {
  description = "argo-helm/argo-cd chart version -- check https://github.com/argoproj/argo-helm/releases before bumping"
  type        = string
  default     = "7.7.11"
}

variable "values" {
  description = "Extra Helm values, merged over the chart defaults (e.g. to tweak server.service.type)"
  type        = any
  default     = {}
}
