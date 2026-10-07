data "aws_iam_policy_document" "role_b_trust" {
  statement {
    sid     = "Group2Operators"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = [for user in aws_iam_user.console : user.arn]
    }

    dynamic "condition" {
      for_each = var.require_mfa ? [1] : []
      content {
        test     = "Bool"
        variable = "aws:MultiFactorAuthPresent"
        values   = ["true"]
      }
    }
  }
}

data "aws_iam_policy_document" "role_b_permissions" {
  statement {
    sid       = "AssumeRoleCOnly"
    effect    = "Allow"
    actions   = ["sts:AssumeRole"]
    resources = ["arn:aws:iam::${var.account_b_id}:role/roleC"]

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.cross_account_external_id]
    }
  }
}

resource "aws_iam_role" "role_b" {
  name                 = "roleB"
  description          = "Assumes roleC in Account B. Has no other permissions."
  assume_role_policy   = data.aws_iam_policy_document.role_b_trust.json
  max_session_duration = 3600

  tags = {
    Name        = "roleB"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_iam_role_policy" "role_b" {
  name   = "roleB-assume-rolec"
  role   = aws_iam_role.role_b.name
  policy = data.aws_iam_policy_document.role_b_permissions.json
}
