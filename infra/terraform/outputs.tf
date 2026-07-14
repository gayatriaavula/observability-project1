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
  value = aws_ecr_repository.orders_backend.repository_url
}

output "github_actions_role_arn" {
  description = "Put this in the GitHub Actions workflow / repo variables as AWS_ROLE_ARN"
  value       = aws_iam_role.github_actions.arn
}
