terraform {
  required_version = ">= 1.6.0, < 2.0.0"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }
}

provider "aws" {
  region = var.aws_region

  # Used only for plan-only review. Real deployments set plan_only=false
  # and authenticate through the AWS CLI/environment or workload identity.
  access_key                  = var.plan_only ? "mock_access_key" : null
  secret_key                  = var.plan_only ? "mock_secret_key" : null
  skip_credentials_validation = var.plan_only
  skip_metadata_api_check     = var.plan_only
  skip_requesting_account_id  = var.plan_only
  default_tags {
    tags = var.tags
  }
}
