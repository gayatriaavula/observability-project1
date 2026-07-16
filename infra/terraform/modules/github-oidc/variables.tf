variable "create_oidc_provider" {
  description = "Whether to create the token.actions.githubusercontent.com OIDC provider. Only one is allowed per AWS account -- set this to true in exactly one environment and false in the others, which will just reference the one already created."
  type        = bool
  default     = true
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI role, in \"org/repo\" form"
  type        = string
}

variable "github_ref" {
  description = "Git ref allowed to assume the role, e.g. refs/heads/main"
  type        = string
  default     = "refs/heads/main"
}

variable "role_name" {
  description = "Name of the IAM role CI assumes via OIDC"
  type        = string
}

variable "ecr_repository_arns" {
  description = "ECR repository ARNs the CI role is allowed to push/pull images to"
  type        = list(string)
}

variable "tags" {
  type    = map(string)
  default = {}
}
