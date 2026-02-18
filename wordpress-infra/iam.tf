# IAM Role for WordPress EC2 Instance

# IAM role for EC2 instance
resource "aws_iam_role" "wordpress_ec2" {
  name = "${local.app_name}-wordpress-ec2-role"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        Effect = "Allow"
        Principal = {
          Service = "ec2.amazonaws.com"
        }
      }
    ]
  })

  tags = local.wordpress_tags
}

# Instance profile
resource "aws_iam_instance_profile" "wordpress_ec2" {
  name = "${local.app_name}-wordpress-ec2-profile"
  role = aws_iam_role.wordpress_ec2.name
}

# Policy for S3 uploads bucket access
resource "aws_iam_role_policy" "wordpress_s3_uploads" {
  name = "${local.app_name}-wordpress-s3-uploads-policy"
  role = aws_iam_role.wordpress_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWordPresS3Uploads"
        Effect = "Allow"
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket",
          "s3:GetObjectVersion"
        ]
        Resource = [
          aws_s3_bucket.wordpress_uploads.arn,
          "${aws_s3_bucket.wordpress_uploads.arn}/*"
        ]
      }
    ]
  })
}

# Policy for CloudWatch Logs (for WordPress debugging)
resource "aws_iam_role_policy" "wordpress_cloudwatch_logs" {
  name = "${local.app_name}-wordpress-cloudwatch-logs-policy"
  role = aws_iam_role.wordpress_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowCloudWatchLogs"
        Effect = "Allow"
        Action = [
          "logs:CreateLogGroup",
          "logs:CreateLogStream",
          "logs:PutLogEvents",
          "logs:DescribeLogStreams"
        ]
        Resource = "arn:aws:logs:${var.aws_region}:${data.aws_caller_identity.current.account_id}:*"
      }
    ]
  })
}

# Optional: Policy for AWS Systems Manager (for secure parameter storage)
resource "aws_iam_role_policy" "wordpress_ssm" {
  count = var.enable_ssm_parameters ? 1 : 0
  name  = "${local.app_name}-wordpress-ssm-policy"
  role  = aws_iam_role.wordpress_ec2.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowSSMParameters"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath"
        ]
        Resource = "arn:aws:ssm:${var.aws_region}:${data.aws_caller_identity.current.account_id}:parameter/wordpress/*"
      }
    ]
  })
}

# Attach the instance profile to the EC2 instance
resource "aws_iam_instance_profile" "wordpress_ec2_attachment" {
  count = var.attach_iam_instance_profile ? 1 : 0
  name  = "${local.app_name}-wordpress-ec2-profile-attachment"
  role  = aws_iam_role.wordpress_ec2.name
}
