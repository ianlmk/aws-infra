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
    key            = "ghost-infra/terraform.tfstate"
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
      ManagedBy   = "opentofu"
      Application = "ghost"
      IaC         = "true"
    }
  }
}

# Vault Provider
provider "vault" {
  address = "http://localhost:8200"
  token   = var.vault_token
}

# Get base infrastructure outputs (VPC, subnets, security groups) from free-tier
data "terraform_remote_state" "base" {
  backend = "s3"
  
  config = {
    bucket         = "tfstate-0001x"
    key            = "free-tier/terraform.tfstate"
    dynamodb_table = "terraform-locks"
  }
}

# Get Ghost database password from Vault
data "vault_generic_secret" "ghost_password" {
  path = "secret/ghost/rds"
}

# Get Ghost SSH key from Vault
data "vault_generic_secret" "ghost_ssh_key" {
  path = "secret/ghost/ssh"
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

# Get latest Ubuntu 22.04 LTS AMI
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"]  # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# Local variables for convenience
locals {
  app_name           = var.app_name
  ghost_db_name      = "ghost_db"
  ghost_db_user      = "ghost"
  ghost_db_password  = data.vault_generic_secret.ghost_password.data["password"]
  ghost_ssh_key      = data.vault_generic_secret.ghost_ssh_key.data["private_key"]
  rds_allocated_storage = var.rds_allocated_storage
  rds_instance_class = var.rds_instance_class
  
  # VPC references from base infrastructure
  vpc_id             = local.base_vpc_id
  private_subnet_ids = local.base_private_subnet_ids
  public_subnet_ids  = local.base_public_subnet_ids
  db_sg_id           = local.base_db_sg_id
  
  # Tags for all Ghost resources
  ghost_tags = {
    Name        = "${local.app_name}-ghost"
    Application = "ghost"
    IaC         = "true"
  }
}
