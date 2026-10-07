variable "aws_region" {
  description = "Region for both account providers. IAM is global, but the provider still needs a region."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "account_a_id" {
  description = "Account A from the brief. Replace this before a real apply."
  type        = string
  default     = "000000000000"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_a_id))
    error_message = "account_a_id must be a 12 digit AWS account ID."
  }
}

variable "account_b_id" {
  description = "Account B from the brief. Replace this before a real apply."
  type        = string
  default     = "111111111111"
  nullable    = false

  validation {
    condition     = can(regex("^[0-9]{12}$", var.account_b_id))
    error_message = "account_b_id must be a 12 digit AWS account ID."
  }
}

variable "account_a_profile" {
  description = "AWS profile for Account A. Null uses the ambient credential chain."
  type        = string
  default     = null
}

variable "account_b_profile" {
  description = "AWS profile for Account B. Null uses the ambient credential chain."
  type        = string
  default     = null
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

variable "group1_users" {
  description = "Programmatic-only users. The brief names engine and ci."
  type        = list(string)
  default     = ["engine", "ci"]
  nullable    = false

  validation {
    condition     = toset(var.group1_users) == toset(["engine", "ci"])
    error_message = "group1 members must be exactly engine and ci."
  }
}

variable "group2_users" {
  description = "Two human operators with console and CLI access."
  type        = list(string)
  default     = ["vikash", "meera"]
  nullable    = false

  validation {
    condition = (
      length(var.group2_users) == 2 &&
      length(setsubtract(toset(var.group2_users), toset(["engine", "ci"]))) == 2
    )
    error_message = "group2 must contain exactly two users, and must not include engine or ci."
  }
}

variable "require_mfa" {
  description = "Require MFA before group2 users can assume roleA or roleB."
  type        = bool
  default     = true
  nullable    = false
}

variable "create_access_keys" {
  description = "Create long-lived access keys for the IAM users. The brief asks for CLI access. NOTES.md explains why production should not do this."
  type        = bool
  default     = true
  nullable    = false
}

variable "cross_account_external_id" {
  description = "External ID required when roleB assumes roleC. Change this before any real use. The sample value is not a secret."
  type        = string
  default     = "arrise-assessment-external-id"
  nullable    = false

  validation {
    condition     = length(var.cross_account_external_id) >= 8
    error_message = "cross_account_external_id must be at least 8 characters."
  }
}

variable "account_b_bucket_name" {
  description = "The one S3 bucket roleC can administer in Account B."
  type        = string
  default     = "arrise-account-b-data"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z0-9][a-z0-9.-]{1,61}[a-z0-9]$", var.account_b_bucket_name))
    error_message = "account_b_bucket_name must be a valid S3 bucket name."
  }
}

variable "ecr_repository_name" {
  description = "ECR repository the ci user may push to. Must match policies/ci-pipeline.json."
  type        = string
  default     = "arrise-app"
  nullable    = false
}

variable "ecs_cluster_name" {
  description = "ECS cluster of the one service ci may deploy. Must match policies/ci-pipeline.json."
  type        = string
  default     = "arrise-cluster"
  nullable    = false
}

variable "ecs_service_name" {
  description = "ECS service ci may update. Must match policies/ci-pipeline.json."
  type        = string
  default     = "arrise-service"
  nullable    = false
}

variable "artifact_bucket_name" {
  description = "Build-artifact bucket ci may read. Must match policies/ci-pipeline.json."
  type        = string
  default     = "arrise-build-artifacts"
  nullable    = false
}

variable "ecs_execution_role_name" {
  description = "Execution role ci may pass to ECS. Must match policies/ci-pipeline.json."
  type        = string
  default     = "arrise-ecs-execution"
  nullable    = false
}

variable "ecs_task_role_name" {
  description = "Task role ci may pass to ECS. Must match policies/ci-pipeline.json."
  type        = string
  default     = "arrise-ecs-task"
  nullable    = false
}
