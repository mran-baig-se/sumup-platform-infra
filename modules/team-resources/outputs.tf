output "team_role_arn" {
  description = "ARN of the IAM role for this team."
  value       = aws_iam_role.team_role.arn
}

output "team_role_name" {
  description = "Name of the IAM role for this team."
  value       = aws_iam_role.team_role.name
}

output "bucket_names" {
  description = "Map of bucket key → actual bucket name for this team."
  value       = { for k, v in aws_s3_bucket.team_buckets : k => v.bucket }
}

output "bucket_arns" {
  description = "Map of bucket key → ARN for this team."
  value       = { for k, v in aws_s3_bucket.team_buckets : k => v.arn }
}

output "public_buckets" {
  description = "Bucket names that have public visibility — for audit awareness."
  value = {
    for k, v in local.buckets_map : k => aws_s3_bucket.team_buckets[k].bucket
    if v.visibility == "public"
  }
}
