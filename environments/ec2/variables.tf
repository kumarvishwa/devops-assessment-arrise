variable "aws_region" {
  description = "Region for the fleet and for the S3 backend."
  type        = string
  default     = "us-east-1"
  nullable    = false
}

variable "aws_profile" {
  description = "Optional shared-credentials profile. Null uses the ambient AWS credential chain."
  type        = string
  default     = null
}

variable "environment" {
  description = "Environment tag on every instance."
  type        = string
  default     = "assessment"
  nullable    = false
}

variable "owner" {
  description = "Owner tag on every instance."
  type        = string
  default     = "vikash"
  nullable    = false
}

variable "name_prefix" {
  description = "Short prefix used on the security group name."
  type        = string
  default     = "arrise"
  nullable    = false
}

variable "subnet_id" {
  description = "Subnet for the fleet. Null uses the default VPC."
  type        = string
  default     = null
}

variable "ami_id" {
  description = "Override the Amazon Linux 2023 lookup."
  type        = string
  default     = null
}

variable "ssh_cidr" {
  description = "CIDR allowed to SSH. Leave null to keep port 22 closed."
  type        = string
  default     = null
}

variable "associate_public_ip" {
  description = "Assign public IPv4 addresses."
  type        = bool
  default     = false
  nullable    = false
}

variable "create_key_pairs" {
  description = "Generate one key pair per instance."
  type        = bool
  default     = true
  nullable    = false
}

variable "instances" {
  description = "Single input for all five EC2 instances."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    root_volume_iops = optional(number)
    key_name         = string
    prevent_destroy  = bool
  }))
  nullable = false

  default = {
    web-01 = {
      instance_type    = "t3.micro"
      root_volume_type = "standard"
      root_volume_size = 30
      key_name         = "arrise-web-01"
      prevent_destroy  = false
    }
    web-02 = {
      instance_type    = "t3.small"
      root_volume_type = "gp2"
      root_volume_size = 40
      key_name         = "arrise-web-02"
      prevent_destroy  = false
    }
    api-01 = {
      instance_type    = "t3.medium"
      root_volume_type = "gp3"
      root_volume_size = 50
      key_name         = "arrise-api-01"
      prevent_destroy  = false
    }
    worker-01 = {
      instance_type    = "t3.large"
      root_volume_type = "io1"
      root_volume_size = 80
      root_volume_iops = 1000
      key_name         = "arrise-worker-01"
      prevent_destroy  = false
    }
    db-01 = {
      instance_type    = "m5.large"
      root_volume_type = "io2"
      root_volume_size = 100
      root_volume_iops = 3000
      key_name         = "arrise-db-01"
      prevent_destroy  = true
    }
  }
}
