locals {
  name = "${var.project}-eks-${var.environment}"

  tags = {
    Project     = var.project
    Environment = var.environment
    ManagedBy   = "terraform"
  }
}

module "vpc" {
  source = "../../modules/vpc"

  name         = local.name
  cluster_name = local.name

  vpc_cidr        = var.vpc_cidr
  private_subnets = var.private_subnets
  public_subnets  = var.public_subnets
  excluded_azs    = var.excluded_azs

  # Cost over resilience for dev: one shared NAT gateway instead of one per AZ.
  single_nat_gateway = true

  tags = local.tags
}

module "eks" {
  source = "../../modules/eks"

  cluster_name    = local.name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  cluster_endpoint_public_access       = true
  cluster_endpoint_public_access_cidrs = var.cluster_endpoint_public_access_cidrs

  node_instance_types = var.node_instance_types
  node_min_size       = var.node_min_size
  node_max_size       = var.node_max_size
  node_desired_size   = var.node_desired_size

  tags = local.tags
}

module "ecr" {
  source = "../../modules/ecr"

  name = "orders-backend-${var.environment}"
  tags = local.tags
}

# Installed as soon as the cluster is up -- see the helm provider block in
# versions.tf for how this authenticates without a manual kubeconfig step.
module "argocd" {
  source = "../../modules/argocd"

  depends_on = [module.eks]
}

module "github_oidc" {
  source = "../../modules/github-oidc"

  create_oidc_provider = var.create_github_oidc_provider
  github_repo          = var.github_repo
  role_name            = "${local.name}-github-actions"
  ecr_repository_arns  = [module.ecr.repository_arn]

  tags = local.tags
}

# Separate role/policy from module.github_oidc's app-image-push role above --
# this one is assumed by the infra pipeline (.github/workflows/infra.yml) and
# needs a very different, much broader set of permissions (VPC/EKS/IAM), so
# keeping it isolated limits the blast radius if either pipeline is compromised.
module "terraform_ci_role" {
  source = "../../modules/terraform-ci-role"

  oidc_provider_arn            = module.github_oidc.oidc_provider_arn
  github_repo                  = var.github_repo
  github_environment           = "infra-${var.environment}"
  role_name                    = "${local.name}-terraform-ci"
  project                      = var.project
  additional_managed_role_arns = [module.eks.node_iam_role_arn]

  state_bucket_name = var.state_bucket_name
  lock_table_name   = var.lock_table_name

  tags = local.tags
}
