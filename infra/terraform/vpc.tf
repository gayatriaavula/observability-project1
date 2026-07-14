data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  azs = slice(data.aws_availability_zones.available.names, 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs             = local.azs
  private_subnets = ["10.0.0.0/19", "10.0.32.0/19", "10.0.64.0/19"]
  public_subnets  = ["10.0.96.0/20", "10.0.112.0/20", "10.0.128.0/20"]

  enable_nat_gateway   = true
  single_nat_gateway   = true
  enable_dns_hostnames = true

  # Required tags so the AWS Load Balancer Controller / EKS know which
  # subnets to use for public ALBs/NLBs and internal pod-to-node routing.
  public_subnet_tags = {
    "kubernetes.io/role/elb"                    = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
  private_subnet_tags = {
    "kubernetes.io/role/internal-elb"           = "1"
    "kubernetes.io/cluster/${var.cluster_name}" = "shared"
  }
}
