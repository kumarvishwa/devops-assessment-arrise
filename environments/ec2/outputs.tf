output "instance_ids" {
  description = "Map of instance name to EC2 instance ID."
  value       = module.ec2_fleet.instance_ids
}

output "instance_private_ips" {
  description = "Map of instance name to private IP."
  value       = module.ec2_fleet.instance_private_ips
}

output "protected_instance_name" {
  description = "Instance protected from Terraform destroy."
  value       = module.ec2_fleet.protected_instance_name
}

output "key_pair_names" {
  description = "Map of instance name to key pair name."
  value       = module.ec2_fleet.key_pair_names
}

output "private_keys_pem" {
  description = "Generated SSH private keys. Retrieve with terraform output -json private_keys_pem."
  value       = module.ec2_fleet.private_keys_pem
  sensitive   = true
}
