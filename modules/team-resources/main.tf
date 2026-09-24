terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

locals {
  # Keyed map for for_each — avoids index-based drift
  buckets_map = { for b in var.buckets : b.name => b }

  # Naming convention: {env}-{team}-{bucket} e.g. prod-team-alpha-data
  common_tags = merge(var.tags, {
    Team        = var.team_name
    Environment = var.environment
    ManagedBy   = "terraform"
    Repo        = "sumup-platform-infra"
  })
}

# ── S3 Buckets ──────────────────────────────────────────────────────────────

resource "aws_s3_bucket" "team_buckets" {
  for_each = local.buckets_map

  # Enforced naming convention — no team can diverge from this pattern
  bucket        = "${var.environment}-${var.team_name}-${each.key}"
  force_destroy = var.allow_force_destroy

  tags = merge(local.common_tags, {
    BucketPurpose = each.key
    Visibility    = each.value.visibility
    CostCenter    = var.team_name
  })
}

# ── Public Access Blocks ─────────────────────────────────────────────────────
# Explicitly set for every bucket — no implicit defaults.
# Private buckets: all public access blocked.
# Public buckets: controlled opening, but still no ACL grants.

resource "aws_s3_bucket_public_access_block" "team_buckets" {
  for_each = local.buckets_map

  bucket = aws_s3_bucket.team_buckets[each.key].id

  block_public_acls       = each.value.visibility == "private"
  block_public_policy     = each.value.visibility == "private"
  ignore_public_acls      = each.value.visibility == "private"
  restrict_public_buckets = each.value.visibility == "private"
}

# ── Bucket Versioning ────────────────────────────────────────────────────────

resource "aws_s3_bucket_versioning" "team_buckets" {
  for_each = local.buckets_map

  bucket = aws_s3_bucket.team_buckets[each.key].id

  versioning_configuration {
    status = "Enabled"
  }
}

# ── Server-Side Encryption ───────────────────────────────────────────────────

resource "aws_s3_bucket_server_side_encryption_configuration" "team_buckets" {
  for_each = local.buckets_map

  bucket = aws_s3_bucket.team_buckets[each.key].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
    bucket_key_enabled = true
  }
}
