variable "region" {
  type    = string
  default = "us-east-1"
}

variable "state_bucket_name" {
  description = "S3 bucket that holds Terraform state for all environments (must be globally unique)"
  type        = string
  default     = "orders-eks-tfstate"
}

variable "lock_table_name" {
  description = "DynamoDB table used for Terraform state locking, shared by all environments"
  type        = string
  default     = "orders-eks-tfstate-lock"
}
