module "ec2_fleet" {
  source = "../../modules/ec2-fleet"

  instances           = var.instances
  environment         = var.environment
  owner               = var.owner
  name_prefix         = var.name_prefix
  subnet_id           = var.subnet_id
  ami_id              = var.ami_id
  ssh_cidr            = var.ssh_cidr
  associate_public_ip = var.associate_public_ip
  create_key_pairs    = var.create_key_pairs
}
