variable "instances" {
  description = "All five instances, supplied as one map. The module creates them with for_each. Each entry must differ in instance type, root volume type, root volume size, and key pair. Exactly one entry must set prevent_destroy."
  type = map(object({
    instance_type    = string
    root_volume_type = string
    root_volume_size = number
    root_volume_iops = optional(number)
    key_name         = string
    prevent_destroy  = bool
  }))
  nullable = false

  validation {
    condition     = length(var.instances) == 5
    error_message = "Provide exactly 5 instances."
  }

  validation {
    condition = alltrue([
      for name in keys(var.instances) : can(regex("^[a-z0-9-]+$", name))
    ])
    error_message = "Instance names must use lowercase letters, numbers, and hyphens."
  }

  validation {
    condition = (
      length(distinct([for inst in values(var.instances) : inst.instance_type])) == length(var.instances) &&
      length(distinct([for inst in values(var.instances) : inst.root_volume_type])) == length(var.instances) &&
      length(distinct([for inst in values(var.instances) : inst.root_volume_size])) == length(var.instances) &&
      length(distinct([for inst in values(var.instances) : inst.key_name])) == length(var.instances)
    )
    error_message = "Instance type, root volume type, root volume size, and key pair must be unique on every instance."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) : contains(["standard", "gp2", "gp3", "io1", "io2"], inst.root_volume_type)
    ])
    error_message = "Root volume type must be standard, gp2, gp3, io1, or io2. st1 and sc1 cannot be root volumes."
  }

  validation {
    condition = anytrue([
      for inst in values(var.instances) : contains(["io1", "io2"], inst.root_volume_type)
    ])
    error_message = "At least one instance must use an io1 or io2 root volume."
  }

  validation {
    condition     = length([for inst in values(var.instances) : inst if inst.prevent_destroy]) == 1
    error_message = "Exactly one instance must set prevent_destroy = true."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) : inst.root_volume_size >= 30 && inst.root_volume_size <= 16384
    ])
    error_message = "Root volume size must be between 30 and 16384 GiB so it can hold the Amazon Linux snapshot."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) :
      contains(["io1", "io2"], inst.root_volume_type) ? try(inst.root_volume_iops >= 100, false) : inst.root_volume_iops == null
    ])
    error_message = "Set root_volume_iops to at least 100 on io1 and io2 only."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) :
      inst.root_volume_type != "io1" || try(inst.root_volume_iops <= inst.root_volume_size * 50, false)
    ])
    error_message = "io1 IOPS cannot exceed 50 times the volume size in GiB."
  }

  validation {
    condition = alltrue([
      for inst in values(var.instances) :
      inst.root_volume_type != "io2" || try(inst.root_volume_iops <= inst.root_volume_size * 1000, false)
    ])
    error_message = "io2 IOPS cannot exceed 1000 times the volume size in GiB."
  }
}

variable "environment" {
  description = "Environment tag applied to every instance."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.environment)) > 0
    error_message = "environment cannot be empty."
  }
}

variable "owner" {
  description = "Owner tag applied to every instance."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.owner)) > 0
    error_message = "owner cannot be empty."
  }
}

variable "name_prefix" {
  description = "Short prefix used on the security group name."
  type        = string
  default     = "arrise"
  nullable    = false

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{0,20}$", var.name_prefix))
    error_message = "name_prefix must be a short lowercase identifier."
  }
}

variable "subnet_id" {
  description = "Subnet for the fleet. Null uses the first subnet of the default VPC."
  type        = string
  default     = null
}

variable "ami_id" {
  description = "AMI for every instance. Null looks up the latest Amazon Linux 2023 x86_64 AMI."
  type        = string
  default     = null
}

variable "ssh_cidr" {
  description = "Optional CIDR allowed to SSH. Null leaves ingress closed. 0.0.0.0/0 is rejected."
  type        = string
  default     = null

  validation {
    condition     = var.ssh_cidr == null || (can(cidrhost(var.ssh_cidr, 0)) && var.ssh_cidr != "0.0.0.0/0")
    error_message = "ssh_cidr must be a specific CIDR. 0.0.0.0/0 is rejected."
  }
}

variable "associate_public_ip" {
  description = "Assign a public IPv4 address. Private IPs are allocated either way."
  type        = bool
  default     = false
  nullable    = false
}

variable "create_key_pairs" {
  description = "Generate a distinct key pair per instance. Set false to use key pairs that already exist under key_name."
  type        = bool
  default     = true
  nullable    = false
}
