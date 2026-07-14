module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 20.8"

  cluster_name    = var.cluster_name
  cluster_version = var.cluster_version

  vpc_id     = module.vpc.vpc_id
  subnet_ids = module.vpc.private_subnets

  # Public access is convenient for a demo/first deployment; restrict
  # cluster_endpoint_public_access_cidrs to your office/VPN CIDR in production.
  cluster_endpoint_public_access = true

  enable_cluster_creator_admin_permissions = true

  eks_managed_node_group_defaults = {
    ami_type = "AL2023_x86_64_STANDARD"
  }

  eks_managed_node_groups = {
    default = {
      instance_types = var.node_instance_types
      min_size       = var.node_min_size
      max_size       = var.node_max_size
      desired_size   = var.node_desired_size
      capacity_type  = "ON_DEMAND"
    }
  }

  # istiod's mutating webhook and the Prometheus/Grafana stack both need
  # room to schedule alongside your application pods.
  cluster_tags = {
    Application = "orders-backend"
  }
}

# The EKS module's default node security group rules cover the generic
# webhook ports several admission controllers use (443, 4443, 6443, 8443,
# 9443) but not istiod's webhook, which listens on 15017. Without this, the
# API server times out calling the sidecar-injector and validation webhooks
# and pods in injected namespaces never get created.
resource "aws_security_group_rule" "node_istiod_webhook" {
  description              = "Cluster API to istiod webhook (15017)"
  type                     = "ingress"
  from_port                = 15017
  to_port                  = 15017
  protocol                 = "tcp"
  security_group_id        = module.eks.node_security_group_id
  source_security_group_id = module.eks.cluster_security_group_id
}
