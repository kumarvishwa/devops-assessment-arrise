data "aws_vpc" "default" {
  count   = var.subnet_id == null ? 1 : 0
  default = true
}

data "aws_subnets" "default" {
  count = var.subnet_id == null ? 1 : 0

  filter {
    name   = "vpc-id"
    values = [data.aws_vpc.default[0].id]
  }
}

data "aws_ami" "amazon_linux" {
  count       = var.ami_id == null ? 1 : 0
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-20*-x86_64"]
  }

  filter {
    name   = "architecture"
    values = ["x86_64"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }

  filter {
    name   = "root-device-type"
    values = ["ebs"]
  }
}

locals {
  common_tags = {
    Environment = var.environment
    Owner       = var.owner
  }

  discovered_subnet_ids = flatten(data.aws_subnets.default[*].ids)
  subnet_id             = coalesce(var.subnet_id, try(local.discovered_subnet_ids[0], null))
  ami_id                = coalesce(var.ami_id, try(data.aws_ami.amazon_linux[0].id, null))

  protected_instances = {
    for name, inst in var.instances : name => inst if inst.prevent_destroy
  }
  standard_instances = {
    for name, inst in var.instances : name => inst if !inst.prevent_destroy
  }

  key_names = {
    for name, inst in var.instances :
    name => var.create_key_pairs ? aws_key_pair.this[name].key_name : inst.key_name
  }
}

data "aws_subnet" "selected" {
  id = local.subnet_id
}

resource "tls_private_key" "this" {
  for_each  = var.create_key_pairs ? var.instances : {}
  algorithm = "ED25519"
}

resource "aws_key_pair" "this" {
  for_each   = var.create_key_pairs ? var.instances : {}
  key_name   = each.value.key_name
  public_key = tls_private_key.this[each.key].public_key_openssh

  tags = merge(local.common_tags, {
    Name = each.value.key_name
  })
}

resource "aws_security_group" "fleet" {
  name        = "${var.name_prefix}-ec2-fleet"
  description = "Assessment fleet. Ingress stays closed unless ssh_cidr is set."
  vpc_id      = data.aws_subnet.selected.vpc_id

  egress {
    description = "Outbound traffic."
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  dynamic "ingress" {
    for_each = var.ssh_cidr == null ? [] : [var.ssh_cidr]
    content {
      description = "SSH from the operator CIDR."
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  tags = merge(local.common_tags, {
    Name = "${var.name_prefix}-ec2-fleet"
  })
}

# prevent_destroy must be a literal, so the protected instance cannot share a
# resource with the other four. Both resources still come from var.instances.
resource "aws_instance" "standard" {
  for_each = local.standard_instances

  ami                         = local.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = local.subnet_id
  key_name                    = local.key_names[each.key]
  vpc_security_group_ids      = [aws_security_group.fleet.id]
  associate_public_ip_address = var.associate_public_ip
  disable_api_termination     = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["io1", "io2"], each.value.root_volume_type) ? each.value.root_volume_iops : null
    encrypted             = true
    delete_on_termination = true

    tags = merge(local.common_tags, {
      Name = "${each.key}-root"
    })
  }

  tags = merge(local.common_tags, {
    Name = each.key
  })
}

resource "aws_instance" "protected" {
  for_each = local.protected_instances

  ami                         = local.ami_id
  instance_type               = each.value.instance_type
  subnet_id                   = local.subnet_id
  key_name                    = local.key_names[each.key]
  vpc_security_group_ids      = [aws_security_group.fleet.id]
  associate_public_ip_address = var.associate_public_ip
  disable_api_termination     = true

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    volume_type           = each.value.root_volume_type
    volume_size           = each.value.root_volume_size
    iops                  = contains(["io1", "io2"], each.value.root_volume_type) ? each.value.root_volume_iops : null
    encrypted             = true
    delete_on_termination = false

    tags = merge(local.common_tags, {
      Name = "${each.key}-root"
    })
  }

  tags = merge(local.common_tags, {
    Name = each.key
  })

  lifecycle {
    prevent_destroy = true
    ignore_changes  = [ami]
  }
}
