# Task 5 fix, applied to the Task 3 role.
#
# Trust bug: the snippet trusted arn:aws:iam::000000000000:user/roleB.
# roleB is a role, so only arn:aws:iam::000000000000:role/roleB can match
# the caller. This trust uses that role ARN and nothing else in Account A.
#
# Permissions bug: the snippet allowed s3:* on Resource "*". That is every
# bucket in the account. Full access here is the one bucket and its objects.

resource "aws_s3_bucket" "role_c" {
  provider = aws.account_b
  bucket   = var.account_b_bucket_name

  tags = {
    Name        = var.account_b_bucket_name
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_s3_bucket_versioning" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}

resource "aws_s3_bucket_public_access_block" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_ownership_controls" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id

  rule {
    object_ownership = "BucketOwnerEnforced"
  }
}

data "aws_iam_policy_document" "role_c_bucket" {
  statement {
    sid     = "DenyInsecureTransport"
    effect  = "Deny"
    actions = ["s3:*"]
    resources = [
      aws_s3_bucket.role_c.arn,
      "${aws_s3_bucket.role_c.arn}/*",
    ]

    principals {
      type        = "*"
      identifiers = ["*"]
    }

    condition {
      test     = "Bool"
      variable = "aws:SecureTransport"
      values   = ["false"]
    }
  }
}

resource "aws_s3_bucket_policy" "role_c" {
  provider = aws.account_b
  bucket   = aws_s3_bucket.role_c.id
  policy   = data.aws_iam_policy_document.role_c_bucket.json

  depends_on = [aws_s3_bucket_public_access_block.role_c]
}

data "aws_iam_policy_document" "role_c_trust" {
  statement {
    sid     = "RoleBOnly"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type        = "AWS"
      identifiers = ["arn:aws:iam::${var.account_a_id}:role/roleB"]
    }

    condition {
      test     = "StringEquals"
      variable = "sts:ExternalId"
      values   = [var.cross_account_external_id]
    }
  }
}

resource "aws_iam_role" "role_c" {
  provider             = aws.account_b
  name                 = "roleC"
  description          = "Full access to one S3 bucket. Assumable only by roleB in Account A."
  assume_role_policy   = data.aws_iam_policy_document.role_c_trust.json
  max_session_duration = 3600

  tags = {
    Name        = "roleC"
    Environment = var.environment
    Owner       = var.owner
  }
}

resource "aws_iam_role_policy" "role_c_s3" {
  provider = aws.account_b
  name     = "roleC-s3-access"
  role     = aws_iam_role.role_c.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Sid    = "FullAccessSingleBucket"
      Effect = "Allow"
      Action = "s3:*"
      Resource = [
        aws_s3_bucket.role_c.arn,
        "${aws_s3_bucket.role_c.arn}/*",
      ]
    }]
  })
}
