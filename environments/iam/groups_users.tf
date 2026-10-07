resource "aws_iam_group" "group1" {
  name = "group1"
}

resource "aws_iam_group" "group2" {
  name = "group2"
}

resource "aws_iam_user" "programmatic" {
  for_each = toset(var.group1_users)
  name     = each.value

  # ci cannot exceed the pipeline policy even if another policy is attached later.
  permissions_boundary = each.value == "ci" ? aws_iam_policy.ci_pipeline.arn : null

  tags = {
    Name        = each.value
    Environment = var.environment
    Owner       = var.owner
    Access      = "programmatic-only"
  }
}

resource "aws_iam_user" "console" {
  for_each = toset(var.group2_users)
  name     = each.value

  tags = {
    Name        = each.value
    Environment = var.environment
    Owner       = var.owner
    Access      = "console-and-cli"
  }
}

resource "aws_iam_user_group_membership" "group1" {
  for_each = aws_iam_user.programmatic
  user     = each.value.name
  groups   = [aws_iam_group.group1.name]
}

resource "aws_iam_user_group_membership" "group2" {
  for_each = aws_iam_user.console
  user     = each.value.name
  groups   = [aws_iam_group.group2.name]
}

resource "aws_iam_access_key" "programmatic" {
  for_each = var.create_access_keys ? aws_iam_user.programmatic : {}
  user     = each.value.name
}

resource "aws_iam_access_key" "console" {
  for_each = var.create_access_keys ? aws_iam_user.console : {}
  user     = each.value.name
}

resource "aws_iam_user_login_profile" "console" {
  for_each                = aws_iam_user.console
  user                    = each.value.name
  password_length         = 24
  password_reset_required = true
}

data "aws_iam_policy_document" "group1" {
  statement {
    sid    = "DenyConsolePassword"
    effect = "Deny"
    actions = [
      "iam:CreateLoginProfile",
      "iam:UpdateLoginProfile",
      "iam:DeleteLoginProfile",
      "iam:ChangePassword",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_group_policy" "group1" {
  name   = "programmatic-only"
  group  = aws_iam_group.group1.name
  policy = data.aws_iam_policy_document.group1.json
}

data "aws_iam_policy_document" "group2" {
  statement {
    sid     = "AssumeRoleAAndRoleB"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]
    resources = [
      aws_iam_role.role_a.arn,
      aws_iam_role.role_b.arn,
    ]
  }

  statement {
    sid    = "ListMfa"
    effect = "Allow"
    actions = [
      "iam:ListMFADevices",
      "iam:ListVirtualMFADevices",
    ]
    resources = ["*"]
  }

  statement {
    sid    = "SelfManageMfa"
    effect = "Allow"
    actions = [
      "iam:CreateVirtualMFADevice",
      "iam:EnableMFADevice",
      "iam:ResyncMFADevice",
    ]
    resources = [
      "arn:aws:iam::${var.account_a_id}:user/$${aws:username}",
      "arn:aws:iam::${var.account_a_id}:mfa/$${aws:username}",
    ]
  }

  statement {
    sid    = "DisableOwnMfaWhilePresent"
    effect = "Allow"
    actions = [
      "iam:DeactivateMFADevice",
      "iam:DeleteVirtualMFADevice",
    ]
    resources = [
      "arn:aws:iam::${var.account_a_id}:user/$${aws:username}",
      "arn:aws:iam::${var.account_a_id}:mfa/$${aws:username}",
    ]

    condition {
      test     = "Bool"
      variable = "aws:MultiFactorAuthPresent"
      values   = ["true"]
    }
  }

  statement {
    sid     = "ChangeOwnPassword"
    effect  = "Allow"
    actions = ["iam:ChangePassword", "iam:GetUser"]
    resources = [
      "arn:aws:iam::${var.account_a_id}:user/$${aws:username}",
    ]
  }

  statement {
    sid       = "ReadPasswordPolicy"
    effect    = "Allow"
    actions   = ["iam:GetAccountPasswordPolicy"]
    resources = ["*"]
  }
}

resource "aws_iam_group_policy" "group2" {
  name   = "console-and-cli"
  group  = aws_iam_group.group2.name
  policy = data.aws_iam_policy_document.group2.json
}
