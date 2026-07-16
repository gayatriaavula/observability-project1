variable "name" {
  description = "Name prefix for the VPC (e.g. orders-eks-dev)"
  type        = string
}

variable "cluster_name" {
  description = "EKS cluster name these subnets belong to, used for the required kubernetes.io subnet tags"
  type        = string
}

variable "vpc_cidr" {
  description = "CIDR block for the VPC"
  type        = string
}

variable "private_subnets" {
  description = "Private subnet CIDR blocks, one per AZ"
  type        = list(string)
}

variable "public_subnets" {
  description = "Public subnet CIDR blocks, one per AZ"
  type        = list(string)
}

variable "excluded_azs" {
  description = "Availability zones to exclude when selecting AZs for subnets"
  type        = list(string)
  default     = []
}

variable "single_nat_gateway" {
  description = "Use one shared NAT gateway instead of one per AZ (cheaper, less resilient)"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Extra tags to apply to the VPC and its subnets"
  type        = map(string)
  default     = {}
}
