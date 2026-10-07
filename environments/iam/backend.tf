# Same bucket and lock table as the EC2 stack. A different key keeps the
# states independent while one DynamoDB table locks both.
terraform {
  backend "s3" {
    bucket         = "vk-arrise-devops-tfstate"
    key            = "iam/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "vk-arrise-devops-tflock"
    encrypt        = true
  }
}
