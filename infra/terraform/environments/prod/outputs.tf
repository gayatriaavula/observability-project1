output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "configure_kubectl" {
  description = "Run this after apply to point kubectl at the new cluster"
  value       = "aws eks update-kubeconfig --region ${var.region} --name ${module.eks.cluster_name}"
}

output "ecr_repository_url" {
  value = module.ecr.repository_url
}

output "github_actions_role_arn" {
  description = "Put this in the GitHub Actions workflow / repo variables as AWS_ROLE_ARN"
  value       = module.github_oidc.role_arn
}

output "terraform_ci_role_arn" {
  description = "Put this in the repo's Actions variables as TERRAFORM_CI_ROLE_ARN_PROD (see .github/workflows/infra.yml)"
  value       = module.terraform_ci_role.role_arn
}
