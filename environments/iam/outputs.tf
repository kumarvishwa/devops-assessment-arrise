output "role_a_arn" {
  description = "roleA ARN in Account A."
  value       = aws_iam_role.role_a.arn
}

output "role_b_arn" {
  description = "roleB ARN in Account A."
  value       = aws_iam_role.role_b.arn
}

output "role_c_arn" {
  description = "roleC ARN in Account B."
  value       = aws_iam_role.role_c.arn
}

output "role_c_bucket" {
  description = "The only bucket roleC can administer."
  value       = aws_s3_bucket.role_c.id
}

output "ci_policy_arn" {
  description = "Least-privilege policy attached to ci, also used as ci's permissions boundary."
  value       = aws_iam_policy.ci_pipeline.arn
}

output "group1_users" {
  description = "Programmatic-only users. No login profile is created for them."
  value       = sort([for user in aws_iam_user.programmatic : user.name])
}

output "group2_users" {
  description = "Console and CLI users."
  value       = sort([for user in aws_iam_user.console : user.name])
}

output "programmatic_access_key_ids" {
  description = "Access key IDs for engine and ci."
  value       = { for name, key in aws_iam_access_key.programmatic : name => key.id }
}

output "programmatic_secret_access_keys" {
  description = "Secret access keys for engine and ci. Stored in remote state only."
  value       = { for name, key in aws_iam_access_key.programmatic : name => key.secret }
  sensitive   = true
}

output "console_access_key_ids" {
  description = "Access key IDs for the group2 users."
  value       = { for name, key in aws_iam_access_key.console : name => key.id }
}

output "console_secret_access_keys" {
  description = "Secret access keys for the group2 users. Stored in remote state only."
  value       = { for name, key in aws_iam_access_key.console : name => key.secret }
  sensitive   = true
}

output "console_passwords" {
  description = "Initial console passwords. Each user must change the password at first login."
  value       = { for name, profile in aws_iam_user_login_profile.console : name => profile.password }
  sensitive   = true
}
