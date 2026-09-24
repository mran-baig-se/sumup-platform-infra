variable "team_name" {
  description = "Unique name for the team. Used in resource naming and IAM scoping."
  type        = string

  validation {
    condition     = can(regex("^[a-z][a-z0-9-]{2,29}$", var.team_name))
    error_message = "team_name must be 3-30 lowercase alphanumeric or hyphen, starting with a letter."
  }
}

variable "environment" {
  description = "Deployment environment (prod, staging, dev)."
  type        = string
  default     = "prod"

  validation {
    condition     = contains(["prod", "staging", "dev"], var.environment)
    error_message = "environment must be one of: prod, staging, dev."
  }
}

variable "buckets" {
  description = "List of S3 buckets to create. Each must have a name and explicit visibility."
  type = list(object({
    name       = string
    visibility = string
  }))

  validation {
    condition = alltrue([
      for b in var.buckets : contains(["public", "private"], b.visibility)
    ])
    error_message = "Each bucket visibility must be explicitly 'public' or 'private'. No defaults allowed."
  }

  validation {
    condition     = length(var.buckets) > 0
    error_message = "Each team must declare at least one S3 bucket."
  }

  validation {
    condition = length(var.buckets) == length(distinct([for b in var.buckets : b.name]))
    error_message = "Bucket names within a team must be unique."
  }
}

variable "allow_force_destroy" {
  description = "Allow Terraform to destroy non-empty buckets. Keep false in production."
  type        = bool
  default     = false
}

variable "iam_assume_role_principals" {
  description = "AWS principal ARNs allowed to assume this team's IAM role."
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Additional tags merged onto all resources."
  type        = map(string)
  default     = {}
}
