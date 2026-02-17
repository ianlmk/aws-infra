terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
  }

  # backend "s3" {
  #   bucket         = "tfstate-ghost-p1"
  #   key            = "ghost/terraform.tfstate"
  #   region         = "us-east-2"
  #   encrypt        = true
  #   dynamodb_table = "terraform-locks"
  # }
  
  # Using local backend for now (opentofu user lacks S3 permissions)
  backend "local" {
    path = "terraform.tfstate"
  }
}

provider "aws" {
  region  = "us-east-2"
  profile = "seldon"

  default_tags {
    tags = {
      Environment = "free-tier"
      ManagedBy   = "opentofu"
    }
  }
}
