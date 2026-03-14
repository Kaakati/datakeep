terraform {
  required_version = ">= 1.5"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.30.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
  }

  # Uncomment for remote state (recommended for production)
  # backend "s3" {
  #   bucket  = "datakeep-terraform-state"
  #   key     = "production/terraform.tfstate"
  #   region  = "eu-south-1"
  #   profile = "manifest"
  #   encrypt = true
  # }
}

provider "aws" {
  region  = var.aws_region
  profile = "manifest"

  default_tags {
    tags = {
      Project     = "datakeep"
      Environment = var.environment
      ManagedBy   = "terraform"
    }
  }
}

locals {
  name_prefix = "datakeep-${var.environment}"
}
