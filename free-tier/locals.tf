# Computed values and locals for reuse across modules
locals {
  # AWS account and region info
  account_id = data.aws_caller_identity.current.account_id
  region     = data.aws_region.current.name

  # Naming convention for resources
  name_prefix = "${var.project_name}-${var.environment}"

  # Common tags with computed values
  common_tags = merge(
    var.common_tags,
    {
      Environment = var.environment
      ManagedBy   = "opentofu"
    }
  )

  # Policy definitions for IAM users
  policies = {
    opentofu_state = {
      user        = "opentofu"
      policy_name = "opentofu-state-backend"
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
              "arn:aws:s3:::tfstate-*",
              "arn:aws:s3:::tfstate-*/*"
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
            Resource = "arn:aws:dynamodb:${local.region}:${local.account_id}:table/terraform-locks"
          }
        ]
      })
    }
    cheapass_ce = {
      user        = "svc_cheapass"
      policy_name = "cheapass-cost-explorer"
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
    opentofu_ce = {
      user        = "opentofu"
      policy_name = "opentofu-cost-explorer"
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
    opentofu_ec2_keypair = {
      user        = "opentofu"
      policy_name = "opentofu-ec2-keypair"
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
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
