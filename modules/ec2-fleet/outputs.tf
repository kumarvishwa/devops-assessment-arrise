output "instance_ids" {
  description = "Map of instance name to EC2 instance ID."
  value = merge(
    { for name, inst in aws_instance.standard : name => inst.id },
    { for name, inst in aws_instance.protected : name => inst.id },
  )
}

output "instance_private_ips" {
  description = "Map of instance name to private IP."
  value = merge(
    { for name, inst in aws_instance.standard : name => inst.private_ip },
    { for name, inst in aws_instance.protected : name => inst.private_ip },
  )
}

output "protected_instance_name" {
  description = "Name of the instance that has prevent_destroy set."
  value       = one(keys(local.protected_instances))
}

output "key_pair_names" {
  description = "Map of instance name to key pair name."
  value       = local.key_names
}

output "private_keys_pem" {
  description = "Generated SSH private keys, keyed by instance name. Empty when create_key_pairs is false."
  value       = { for name, key in tls_private_key.this : name => key.private_key_pem }
  sensitive   = true
}
