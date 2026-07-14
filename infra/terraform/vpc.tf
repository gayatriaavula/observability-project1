data "aws_availability_zones" "available" {
  filter {
    name   = "opt-in-status"
    values = ["opt-in-not-required"]
  }
}

locals {
  # us-east-1a is excluded: this account already has other, unrelated VPCs
  # sitting at the NAT-gateway-per-AZ quota there.
  azs = slice([for az in data.aws_availability_zones.available.names : az if az != "us-east-1a"], 0, 3)
}

module "vpc" {
  source  = "terraform-aws-modules/vpc/aws"
  version = "~> 5.8"

  name = "${var.cluster_name}-vpc"
  cidr = "10.0.0.0/16"

  azs = local.azs
  # Private subnets use fresh, non-overlapping ranges (not 10.0.0.0/19 etc.)
  # because this module replaces subnets create-before-destroy: reusing the
  # old CIDRs collides with the still-existing old subnets during replacement.
  private_subnets = ["10.0.160.0/19", "10.0.192.0/19", "10.0.224.0/19"]
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
