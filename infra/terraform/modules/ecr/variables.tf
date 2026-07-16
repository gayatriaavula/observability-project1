variable "name" {
  description = "Name of the ECR repository (e.g. orders-backend-dev)"
  type        = string
}

variable "image_tag_mutability" {
  type    = string
  default = "IMMUTABLE"
}

variable "scan_on_push" {
  type    = bool
  default = true
}

variable "untagged_expiry_days" {
  description = "Days after which untagged images are expired"
  type        = number
  default     = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
