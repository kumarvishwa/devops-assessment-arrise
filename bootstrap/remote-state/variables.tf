variable "aws_region" {
  description = "Region of the state bucket and the lock table. Must match the backend region."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "aws_profile" {
  description = "Optional shared-credentials profile. Null uses the ambient AWS credential chain."
  type        = string
  default     = null
}

variable "state_bucket_name" {
  description = "Globally unique name for the Terraform state bucket. Must match environments/*/backend.tf."
  type        = string
  default     = "vk-arrise-devops-tfstate"
  nullable    = false
}

variable "lock_table_name" {
  description = "DynamoDB table used as the state lock. Must match environments/*/backend.tf."
  type        = string
  default     = "vk-arrise-devops-tflock"
  nullable    = false
}

variable "environment" {
  description = "Environment tag."
  type        = string
  default     = "assessment"
  nullable    = false
}

variable "owner" {
  description = "Owner tag."
  type        = string
  default     = "vikash"
  nullable    = false
}
