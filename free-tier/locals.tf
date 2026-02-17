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
    opentofu_infrastructure = {
      user        = "opentofu"
      policy_name = "opentofu-infrastructure"
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
  }
}

# Data sources
data "aws_caller_identity" "current" {}
data "aws_region" "current" {}
