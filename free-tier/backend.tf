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

  backend "s3" {
    bucket         = "tfstate-0001x"
    key            = "free-tier/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-locks"
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
