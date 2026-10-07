provider "aws" {
  region              = var.aws_region
  profile             = var.account_a_profile
  allowed_account_ids = [var.account_a_id]
}

provider "aws" {
  alias               = "account_b"
  region              = var.aws_region
  profile             = var.account_b_profile
  allowed_account_ids = [var.account_b_id]
}
