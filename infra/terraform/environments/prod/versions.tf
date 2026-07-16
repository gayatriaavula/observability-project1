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
  }

  # Created by ../../bootstrap -- run that once first, then `terraform init`
  # here (adjust bucket/region if you customized the bootstrap variables).
  backend "s3" {
    bucket         = "orders-eks-tfstate"
    key            = "prod/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "orders-eks-tfstate-lock"
    encrypt        = true
  }
}

provider "aws" {
  region = var.region
}
