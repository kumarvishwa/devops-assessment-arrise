data "aws_iam_policy_document" "role_a_trust" {
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

data "aws_iam_policy_document" "role_a_permissions" {
  statement {
    sid         = "AdminExceptIam"
    effect      = "Allow"
    not_actions = ["iam:*"]
    resources   = ["*"]
  }

  statement {
    sid       = "DenyAllIam"
    effect    = "Deny"
    actions   = ["iam:*"]
    resources = ["*"]
  }
}

resource "aws_iam_role" "role_a" {
  name                 = "roleA"
  description          = "Administrative access to every AWS service except IAM."
  assume_role_policy   = data.aws_iam_policy_document.role_a_trust.json
  max_session_duration = 3600

  tags = {
    Name        = "roleA"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_iam_role_policy" "role_a" {
  name   = "roleA-admin-except-iam"
  role   = aws_iam_role.role_a.name
  policy = data.aws_iam_policy_document.role_a_permissions.json
}
