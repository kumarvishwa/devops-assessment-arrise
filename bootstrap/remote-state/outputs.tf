output "state_bucket_name" {
  description = "S3 bucket that stores Terraform state."
  value       = aws_s3_bucket.state.id
}

output "lock_table_name" {
  description = "DynamoDB table that locks Terraform state."
  value       = aws_dynamodb_table.lock.name
}

output "backend_example" {
  description = "Backend settings consumed by the EC2 and IAM stacks. The key line differs per stack."
  value       = <<-EOT
    bucket         = "${aws_s3_bucket.state.id}"
    region         = "${var.aws_region}"
    dynamodb_table = "${aws_dynamodb_table.lock.name}"
    encrypt        = true
  EOT
}
