variable "team_config_file" {
  description = "Path to the team YAML config file. Passed by CI per changed team."
  type        = string
}

variable "environment" {
  description = "Deployment environment."
  type        = string
  default     = "prod"
}

variable "aws_region" {
  description = "AWS region for all resources."
  type        = string
  default     = "eu-west-1"
}

variable "tfstate_bucket" {
  description = "S3 bucket name for Terraform state storage."
  type        = string
  default     = "company-tfstate"
}
