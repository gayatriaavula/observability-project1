terraform {
  required_version = ">= 1.5.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
    helm = {
      source  = "hashicorp/helm"
      version = "~> 2.12"
    }
  }

  # Created by ../../bootstrap -- run that once first, then `terraform init`
  # here (adjust bucket/region if you customized the bootstrap variables).
  backend "s3" {
    bucket         = "orders-eks-tfstate"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "orders-eks-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}

# Configured from module.eks's own outputs so Argo CD can be installed in
# the same apply that creates the cluster, right after it, with no manual
# `aws eks update-kubeconfig` step in between. This is a well-known but
# imperfect Terraform pattern (provider config depending on a resource in
# the same state): it works because eks_managed_node_group_defaults and
# enable_cluster_creator_admin_permissions in modules/eks mean whichever
# identity runs `terraform apply` -- including modules/terraform-ci-role in
# CI -- already has cluster-admin the moment the cluster exists. If this
# errors on a completely fresh account with an empty/unreachable endpoint,
# re-run `terraform apply` once; that's this pattern's one known rough edge.
provider "helm" {
  kubernetes {
    host                   = module.eks.cluster_endpoint
    cluster_ca_certificate = base64decode(module.eks.cluster_certificate_authority_data)

    exec {
      api_version = "client.authentication.k8s.io/v1beta1"
      command     = "aws"
      args        = ["eks", "get-token", "--cluster-name", module.eks.cluster_name, "--region", var.region]
    }
  }
}
