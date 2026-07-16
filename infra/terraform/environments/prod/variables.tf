variable "region" {
  description = "AWS region to deploy into"
  type        = string
  default     = "us-east-1"
}

variable "project" {
  type    = string
  default = "orders"
}

variable "environment" {
  type    = string
  default = "prod"
}

variable "cluster_version" {
  description = "Kubernetes version for the EKS control plane"
  type        = string
  default     = "1.32"
}

variable "vpc_cidr" {
  description = "Distinct from dev's 10.0.0.0/16 so the two VPCs could be peered later without overlap"
  type        = string
  default     = "10.1.0.0/16"
}

variable "private_subnets" {
  type    = list(string)
  default = ["10.1.160.0/19", "10.1.192.0/19", "10.1.224.0/19"]
}

variable "public_subnets" {
  type    = list(string)
  default = ["10.1.96.0/20", "10.1.112.0/20", "10.1.128.0/20"]
}

variable "excluded_azs" {
  description = "AZs to exclude, e.g. because this account already has other VPCs sitting at the NAT-gateway-per-AZ quota there"
  type        = list(string)
  default     = ["us-east-1a"]
}

variable "cluster_endpoint_public_access_cidrs" {
  description = "Restrict this to your office/VPN CIDR for prod instead of the wide-open default"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}

variable "node_min_size" {
  type    = number
  default = 2
}

variable "node_max_size" {
  type    = number
  default = 4
}

variable "node_desired_size" {
  type    = number
  default = 2
}

variable "github_repo" {
  description = "GitHub repo allowed to assume the CI role, in \"org/repo\" form"
  type        = string
}

variable "github_ref" {
  type    = string
  default = "refs/heads/main"
}

variable "create_github_oidc_provider" {
  description = "Set to false if the token.actions.githubusercontent.com OIDC provider already exists in this account (only one is allowed per account -- environments/dev creates it by default)"
  type        = bool
  default     = false
}

variable "state_bucket_name" {
  description = "S3 bucket holding this environment's Terraform state, created by ../../bootstrap"
  type        = string
  default     = "orders-eks-tfstate"
}

variable "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking, created by ../../bootstrap"
  type        = string
  default     = "orders-eks-tfstate-lock"
}
