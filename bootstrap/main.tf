#================================================================#
# AWS Bootstrap: IAM User, Policies, and State Backend Setup      #
#================================================================#
# 
# Purpose: Create opentofu IAM user with all required permissions
#          and bootstrap the S3 state backend + DynamoDB locking
#
# Prerequisites:
#   - AWS credentials configured for admin user (player1)
#   - Run from bootstrap/ directory
#   - terraform init
#   - terraform apply
#
# Run As: player1 (default profile) in account 143551597089
# Output: Access keys for opentofu user (add to ~/.aws/credentials)
#
#================================================================#

terraform {
  required_version = ">= 1.6"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }

  # Note: Bootstrap runs locally; no remote state
  # Once complete, switch to S3 backend in other projects
}

provider "aws" {
  region  = var.aws_region
  profile = var.admin_profile  # Run as admin user (player1)

  default_tags {
    tags = {
      Environment = "bootstrap"
      ManagedBy   = "terraform"
      Purpose     = "Infrastructure automation"
    }
  }
}

#================================================#
# 1. Create opentofu IAM User                   #
#================================================#

resource "aws_iam_user" "opentofu" {
  name = var.infra_user_name

  tags = {
    Name        = var.infra_user_name
    Description = "Infrastructure automation user for Terraform"
  }
}

#================================================#
# 2. Create Access Keys (for ~/.aws/credentials)#
#================================================#

resource "aws_iam_access_key" "opentofu" {
  user = aws_iam_user.opentofu.name

  # Safeguard: Prevent accidental key rotation
  lifecycle {
    create_before_destroy = true
  }
}

#================================================#
# 3. Attach IAM Policies                        #
#================================================#

#------------------#
# Policy 1: EC2 Key Pair Management
#------------------#

resource "aws_iam_user_policy" "opentofu_ec2_keypair" {
  name = "${var.infra_user_name}-ec2-keypair"
  user = aws_iam_user.opentofu.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2KeyPairManagement"
        Effect = "Allow"
        Action = [
          "ec2:ImportKeyPair",
          "ec2:DeleteKeyPair",
          "ec2:DescribeKeyPairs"
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------#
# Policy 2: Full Infrastructure Management
#------------------#

resource "aws_iam_user_policy" "opentofu_infrastructure" {
  name = "${var.infra_user_name}-infrastructure"
  user = aws_iam_user.opentofu.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "EC2InstanceManagement"
        Effect = "Allow"
        Action = [
          "ec2:RunInstances",
          "ec2:TerminateInstances",
          "ec2:StopInstances",
          "ec2:StartInstances",
          "ec2:RebootInstances",
          "ec2:DescribeInstances",
          "ec2:DescribeInstanceStatus",
          "ec2:GetConsoleOutput",
          "ec2:ModifyInstanceAttribute",
          "ec2:AttachNetworkInterface",
          "ec2:DetachNetworkInterface"
        ]
        Resource = "*"
      },
      {
        Sid    = "EC2VolumeManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVolume",
          "ec2:DeleteVolume",
          "ec2:DescribeVolumes",
          "ec2:DescribeVolumeStatus",
          "ec2:AttachVolume",
          "ec2:DetachVolume",
          "ec2:ModifyVolume",
          "ec2:ModifyVolumeAttribute"
        ]
        Resource = "*"
      },
      {
        Sid    = "ElasticIPManagement"
        Effect = "Allow"
        Action = [
          "ec2:AllocateAddress",
          "ec2:ReleaseAddress",
          "ec2:DescribeAddresses",
          "ec2:AssociateAddress",
          "ec2:DisassociateAddress",
          "ec2:ModifyAddressAttribute"
        ]
        Resource = "*"
      },
      {
        Sid    = "VPCNetworkManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateVpc",
          "ec2:DeleteVpc",
          "ec2:DescribeVpcs",
          "ec2:ModifyVpcAttribute",
          "ec2:DescribeVpcAttribute",
          "ec2:CreateSubnet",
          "ec2:DeleteSubnet",
          "ec2:DescribeSubnets",
          "ec2:ModifySubnetAttribute",
          "ec2:CreateInternetGateway",
          "ec2:DeleteInternetGateway",
          "ec2:DescribeInternetGateways",
          "ec2:AttachInternetGateway",
          "ec2:DetachInternetGateway",
          "ec2:CreateNatGateway",
          "ec2:DeleteNatGateway",
          "ec2:DescribeNatGateways",
          "ec2:CreateRoute",
          "ec2:DeleteRoute",
          "ec2:ReplaceRoute",
          "ec2:DescribeRouteTables",
          "ec2:CreateRouteTable",
          "ec2:DeleteRouteTable",
          "ec2:AssociateRouteTable",
          "ec2:DisassociateRouteTable"
        ]
        Resource = "*"
      },
      {
        Sid    = "SecurityGroupManagement"
        Effect = "Allow"
        Action = [
          "ec2:CreateSecurityGroup",
          "ec2:DeleteSecurityGroup",
          "ec2:DescribeSecurityGroups",
          "ec2:DescribeSecurityGroupRules",
          "ec2:AuthorizeSecurityGroupIngress",
          "ec2:RevokeSecurityGroupIngress",
          "ec2:AuthorizeSecurityGroupEgress",
          "ec2:RevokeSecurityGroupEgress",
          "ec2:CreateSecurityGroupRule",
          "ec2:DeleteSecurityGroupRule",
          "ec2:ModifySecurityGroupRules"
        ]
        Resource = "*"
      },
      {
        Sid    = "RDSDatabaseManagement"
        Effect = "Allow"
        Action = [
          "rds:CreateDBInstance",
          "rds:DeleteDBInstance",
          "rds:DescribeDBInstances",
          "rds:ModifyDBInstance",
          "rds:StopDBInstance",
          "rds:StartDBInstance",
          "rds:RebootDBInstance",
          "rds:CreateDBSubnetGroup",
          "rds:DeleteDBSubnetGroup",
          "rds:DescribeDBSubnetGroups",
          "rds:ModifyDBSubnetGroup",
          "rds:DescribeDBSnapshots",
          "rds:CreateDBSnapshot",
          "rds:DeleteDBSnapshot"
        ]
        Resource = "*"
      },
      {
        Sid    = "Route53Management"
        Effect = "Allow"
        Action = [
          "route53:CreateHostedZone",
          "route53:DeleteHostedZone",
          "route53:DescribeHostedZone",
          "route53:ListHostedZones",
          "route53:ListResourceRecordSets",
          "route53:ChangeResourceRecordSets",
          "route53:GetChange"
        ]
        Resource = "*"
      },
      {
        Sid    = "S3Management"
        Effect = "Allow"
        Action = [
          "s3:CreateBucket",
          "s3:DeleteBucket",
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:PutBucketVersioning",
          "s3:GetBucketEncryption",
          "s3:PutBucketEncryption",
          "s3:GetBucketPublicAccessBlock",
          "s3:PutBucketPublicAccessBlock",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucketVersions",
          "s3:GetBucketLifecycle",
          "s3:PutBucketLifecycle"
        ]
        Resource = "*"
      },
      {
        Sid    = "KMSManagement"
        Effect = "Allow"
        Action = [
          "kms:Decrypt",
          "kms:GenerateDataKey",
          "kms:CreateGrant",
          "kms:DescribeKey",
          "kms:ListAliases"
        ]
        Resource = "*"
      },
      {
        Sid    = "IAMReadOnly"
        Effect = "Allow"
        Action = [
          "iam:ListUsers",
          "iam:GetUser",
          "iam:ListAccessKeys",
          "iam:ListAttachedUserPolicies"
        ]
        Resource = "*"
      }
    ]
  })
}

#------------------#
# Policy 3: State Backend Access
#------------------#

resource "aws_iam_user_policy" "opentofu_state_backend" {
  name = "${var.infra_user_name}-state-backend"
  user = aws_iam_user.opentofu.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "S3StateBackend"
        Effect = "Allow"
        Action = [
          "s3:ListBucket",
          "s3:GetBucketVersioning",
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject"
        ]
        Resource = [
          "arn:aws:s3:::${local.computed_bucket_name}",
          "arn:aws:s3:::${local.computed_bucket_name}/*"
        ]
      },
      {
        Sid    = "DynamoDBLocking"
        Effect = "Allow"
        Action = [
          "dynamodb:DescribeTable",
          "dynamodb:GetItem",
          "dynamodb:PutItem",
          "dynamodb:DeleteItem"
        ]
        Resource = "arn:aws:dynamodb:${var.aws_region}:${data.aws_caller_identity.current.account_id}:table/${var.state_lock_table_name}"
      }
    ]
  })
}

#------------------#
# Policy 4: Cost Explorer
#------------------#

resource "aws_iam_user_policy" "opentofu_cost_explorer" {
  name = "${var.infra_user_name}-cost-explorer"
  user = aws_iam_user.opentofu.name

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "CostExplorerRead"
        Effect = "Allow"
        Action = [
          "ce:GetCostAndUsage",
          "ce:GetCostForecast",
          "ce:DescribeCostCategoryDefinition",
          "ce:ListCostAllocationTags"
        ]
        Resource = "*"
      }
    ]
  })
}

#================================================#
# 4. S3 Bucket for Terraform State              #
#================================================#

resource "aws_s3_bucket" "terraform_state" {
  bucket = local.computed_bucket_name

  tags = {
    Name        = local.computed_bucket_name
    Description = "Terraform state backend"
  }
}

resource "aws_s3_bucket_versioning" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "terraform_state" {
  bucket = aws_s3_bucket.terraform_state.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

#================================================#
# 5. DynamoDB Table for State Locking           #
#================================================#

resource "aws_dynamodb_table" "terraform_locks" {
  name           = var.state_lock_table_name
  billing_mode   = "PAY_PER_REQUEST"
  hash_key       = "LockID"

  attribute {
    name = "LockID"
    type = "S"
  }

  tags = {
    Name        = var.state_lock_table_name
    Description = "Terraform state locking"
  }
}

#================================================#
# Data Sources & Locals                         #
#================================================#

data "aws_caller_identity" "current" {}

#------------------#
# Computed bucket name if not provided
#------------------#

locals {
  # If state_bucket_name is empty, generate unique name using account ID
  computed_bucket_name = var.state_bucket_name != "" ? var.state_bucket_name : "tfstate-${data.aws_caller_identity.current.account_id}-ghost"
}
