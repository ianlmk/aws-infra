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
    ansible = {
      source  = "ansible/ansible"
      version = "~> 1.0"
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

# Get base infrastructure outputs (VPC, EC2, security groups)
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

# Get EC2 instance details
data "aws_instance" "web_server" {
  instance_id = data.terraform_remote_state.base.outputs.web_server_instance_id
}

# Get VPC and subnet details
data "aws_vpc" "main" {
  id = data.terraform_remote_state.base.outputs.vpc_id
}

data "aws_subnets" "private" {
  filter {
    name   = "vpc-id"
    values = [data.terraform_remote_state.base.outputs.vpc_id]
  }
  filter {
    name   = "tag:Name"
    values = ["*private*"]
  }
}

data "aws_security_group" "app" {
  vpc_id = data.terraform_remote_state.base.outputs.vpc_id
  filter {
    name   = "tag:Name"
    values = ["*app*"]
  }
}

# Local variables for convenience
locals {
  app_name              = var.app_name
  wordpress_db_name    = "wordpress"
  wordpress_db_user    = "wordpress"
  wordpress_db_password = data.vault_generic_secret.wordpress_password.data["password"]
  rds_allocated_storage = var.rds_allocated_storage
  rds_instance_class   = var.rds_instance_class
  
  # Tags for all WordPress resources
  wordpress_tags = {
    Name        = "${local.app_name}-wordpress"
    Application = "wordpress"
  }
}
