terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
    vault = {
      source  = "hashicorp/vault"
      version = "~> 4.0"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.0"
    }
  }

  # State backend - same S3 bucket as free-tier, different key
  backend "s3" {
    bucket         = "tfstate-0001x"
    key            = "wordpress-infra/terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}

# AWS Provider
provider "aws" {
  profile = "seldon"
  region  = var.aws_region
  
  default_tags {
    tags = {
      Environment = "free-tier"
      ManagedBy   = "terraform"
      Application = "wordpress"
      IaC         = "true"
    }
  }
}

# Vault Provider
provider "vault" {
  address = "http://localhost:8200"
  token   = var.vault_token
}

# Ansible Provider
provider "ansible" {}

# Get base infrastructure outputs (VPC, subnets, security groups) from free-tier
data "terraform_remote_state" "base" {
  backend = "s3"
  
  config = {
    bucket         = "tfstate-0001x"
    key            = "free-tier/terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}

# Get WordPress database password from Vault
data "vault_generic_secret" "wordpress_password" {
  path = "secret/aws/wordpress/rds"
}

# Get AWS caller identity
data "aws_caller_identity" "current" {}

# Extract outputs from free-tier state (using "default" network key)
locals {
  base_vpc_id              = data.terraform_remote_state.base.outputs.vpc_id["default"]
  base_private_subnet_ids  = data.terraform_remote_state.base.outputs.private_subnet_ids["default"]
  base_public_subnet_ids   = data.terraform_remote_state.base.outputs.public_subnet_ids["default"]
  base_app_sg_id           = data.terraform_remote_state.base.outputs.app_security_group_ids["default"]
  base_db_sg_id            = data.terraform_remote_state.base.outputs.database_security_group_ids["default"]
  base_web_sg_id           = data.terraform_remote_state.base.outputs.web_security_group_ids["default"]
  base_route53_zone_ids    = data.terraform_remote_state.base.outputs.route53_zone_ids
}

# Get VPC details
data "aws_vpc" "main" {
  id = local.base_vpc_id
}

# Local variables for convenience
locals {
  app_name              = var.app_name
  wordpress_db_name    = "wordpress"
  wordpress_db_user    = "wordpress"
  wordpress_db_password = data.vault_generic_secret.wordpress_password.data["password"]
  rds_allocated_storage = var.rds_allocated_storage
  rds_instance_class   = var.rds_instance_class
  
  # VPC references from base infrastructure
  vpc_id             = local.base_vpc_id
  private_subnet_ids = local.base_private_subnet_ids
  public_subnet_ids  = local.base_public_subnet_ids
  db_sg_id           = local.base_db_sg_id
  
  # Tags for all WordPress resources
  wordpress_tags = {
    Name        = "${local.app_name}-wordpress"
    Application = "wordpress"
    IaC         = "true"
  }
}
