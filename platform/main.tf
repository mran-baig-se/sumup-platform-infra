terraform {
  required_version = ">= 1.5.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }

  # Backend is configured dynamically per team via -backend-config at init time.
  # Each team gets: s3://company-tfstate/teams/{team_name}/terraform.tfstate
  # This ensures true state isolation — one team's state never touches another's.
  backend "s3" {}
}

provider "aws" {
  region = var.aws_region
}

# ── Load this team's config file ─────────────────────────────────────────────
# var.team_config_file is passed by CI: -var="team_config_file=../teams/team-alpha.yaml"

locals {
  team_config = yamldecode(file(var.team_config_file))
}

module "team_resources" {
  source = "../modules/team-resources"

  team_name   = local.team_config.team_name
  environment = var.environment
  buckets     = local.team_config.buckets

  tags = {
    ManagedBy   = "platform-team"
    Repo        = "sumup-platform-infra"
    Environment = var.environment
  }
}

output "team_outputs" {
  description = "Resources provisioned for this team."
  value = {
    role_arn        = module.team_resources.team_role_arn
    buckets         = module.team_resources.bucket_names
    public_buckets  = module.team_resources.public_buckets
  }
}
