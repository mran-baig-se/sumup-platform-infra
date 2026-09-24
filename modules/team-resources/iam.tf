data "aws_caller_identity" "current" {}

# ── Trust Policy ─────────────────────────────────────────────────────────────
# Who can assume this role. Defaults to the account root if no principals given.

data "aws_iam_policy_document" "assume_role" {
  statement {
    sid     = "AllowAssumeRole"
    effect  = "Allow"
    actions = ["sts:AssumeRole"]

    principals {
      type = "AWS"
      identifiers = length(var.iam_assume_role_principals) > 0 ? (
        var.iam_assume_role_principals
      ) : ["arn:aws:iam::${data.aws_caller_identity.current.account_id}:root"]
    }
  }
}

resource "aws_iam_role" "team_role" {
  name               = "${var.environment}-${var.team_name}-role"
  assume_role_policy = data.aws_iam_policy_document.assume_role.json
  description        = "IAM role for ${var.team_name} — scoped to its own S3 buckets only."

  tags = merge(var.tags, {
    Team        = var.team_name
    Environment = var.environment
    ManagedBy   = "terraform"
  })
}

# ── S3 Permission Policy ─────────────────────────────────────────────────────
# Least-privilege: only this team's bucket ARNs — never a wildcard resource.

data "aws_iam_policy_document" "team_s3" {
  # Bucket-level: list and locate own buckets only
  statement {
    sid    = "ListOwnBuckets"
    effect = "Allow"
    actions = [
      "s3:ListBucket",
      "s3:GetBucketLocation",
    ]
    # Explicit ARN list — no * wildcard
    resources = [for b in aws_s3_bucket.team_buckets : b.arn]
  }

  # Object-level: read/write/delete within own buckets only
  statement {
    sid    = "ManageOwnObjects"
    effect = "Allow"
    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:DeleteObjectVersion",
    ]
    resources = [for b in aws_s3_bucket.team_buckets : "${b.arn}/*"]
  }

  # Explicit deny: block access to any bucket NOT owned by this team
  statement {
    sid    = "DenyOtherBuckets"
    effect = "Deny"
    actions = [
      "s3:*",
    ]
    not_resources = concat(
      [for b in aws_s3_bucket.team_buckets : b.arn],
      [for b in aws_s3_bucket.team_buckets : "${b.arn}/*"]
    )
  }
}

resource "aws_iam_role_policy" "team_s3_access" {
  name   = "${var.environment}-${var.team_name}-s3-policy"
  role   = aws_iam_role.team_role.id
  policy = data.aws_iam_policy_document.team_s3.json
}
