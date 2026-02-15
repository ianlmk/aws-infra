terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  backend "s3" {
    bucket         = "tfstate-ghost-backend"
    key            = "ghost/terraform.tfstate"
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
      Project     = "ghost-blog"
      Environment = "free-tier"
      ManagedBy   = "terraform"
    }
  }
}
