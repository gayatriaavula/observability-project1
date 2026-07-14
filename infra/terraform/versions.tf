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

  # Uncomment and configure once you have a place to store state (S3 + DynamoDB lock table).
  # backend "s3" {
  #   bucket         = "your-tfstate-bucket"
  #   key            = "orders-backend/eks.tfstate"
  #   region         = "us-east-1"
  #   dynamodb_table = "your-tfstate-lock-table"
  #   encrypt        = true
  # }
}

provider "aws" {
  region = var.region
}
