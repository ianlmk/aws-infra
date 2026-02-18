# Data sources for AWS account and region info

data "aws_caller_identity" "current" {}

data "aws_region" "current" {
  name = var.aws_region
}
