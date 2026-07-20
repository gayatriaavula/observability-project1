variable "oidc_provider_arn" {
  description = "ARN of the existing token.actions.githubusercontent.com OIDC provider (from modules/github-oidc)"
  type        = string
}

variable "github_repo" {
  description = "GitHub repo allowed to assume this role, in \"org/repo\" form"
  type        = string
}

variable "github_ref" {
  description = "Git ref allowed to run terraform apply, e.g. refs/heads/main"
  type        = string
  default     = "refs/heads/main"
}

variable "github_environment" {
  description = "GitHub Environment name the apply job runs under (e.g. \"infra-dev\"). When a job declares `environment:`, its OIDC token's sub claim becomes \"repo:ORG/REPO:environment:NAME\" instead of the ref-based form, so this needs its own trust condition."
  type        = string
}

variable "role_name" {
  description = "Name of the IAM role the infra CI pipeline assumes via OIDC"
  type        = string
}

variable "project" {
  description = "Project name prefix shared by resources these modules create (e.g. \"orders\" -> orders-eks-* IAM roles, orders-backend-* ECR repos), used to scope iam:*, ecr:*, and PassRole so this role can't touch unrelated resources"
  type        = string
}

variable "state_bucket_name" {
  description = "S3 bucket holding this environment's Terraform state"
  type        = string
}

variable "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking"
  type        = string
}

variable "tags" {
  type    = map(string)
  default = {}
}

variable "additional_managed_role_arns" {
  description = "IAM roles this CI role needs to manage that fall outside the project-eks-* naming pattern -- e.g. the EKS node group's IAM role, which the upstream terraform-aws-modules/eks module names by its own convention (default-eks-node-group-<suffix>). Granted by exact ARN, never a wildcard, so this doesn't reopen the cross-project blast-radius the naming-pattern scoping exists to prevent."
  type        = list(string)
  default     = []
}
