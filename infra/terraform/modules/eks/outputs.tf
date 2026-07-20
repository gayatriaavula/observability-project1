output "cluster_name" {
  value = module.eks.cluster_name
}

output "cluster_endpoint" {
  value = module.eks.cluster_endpoint
}

output "cluster_certificate_authority_data" {
  value = module.eks.cluster_certificate_authority_data
}

output "node_security_group_id" {
  value = module.eks.node_security_group_id
}

output "cluster_security_group_id" {
  value = module.eks.cluster_security_group_id
}

output "node_iam_role_arn" {
  description = "ARN of the default node group's IAM role -- named by the upstream module's own convention (default-eks-node-group-<suffix>), not the orders-eks-* pattern modules/terraform-ci-role's IAM permissions are scoped to, so this needs to be threaded through as an explicit exception."
  value       = module.eks.eks_managed_node_groups["default"].iam_role_arn
}
