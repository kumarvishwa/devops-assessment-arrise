# Task 2. Backends belong on the root module. Terraform rejects a backend
# block inside modules/ec2-fleet. Bucket and lock table are created by
# bootstrap/remote-state and these names must match its defaults.
terraform {
  backend "s3" {
    bucket         = "vk-arrise-devops-tfstate"
    key            = "ec2/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vk-arrise-devops-tflock"
    encrypt        = true
  }
}
