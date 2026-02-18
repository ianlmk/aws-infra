# S3 Bucket for WordPress Uploads

# Main uploads bucket
resource "aws_s3_bucket" "wordpress_uploads" {
  bucket = "${local.app_name}-wordpress-uploads-${data.aws_caller_identity.current.account_id}"

  tags = merge(
    local.wordpress_tags,
    { Name = "${local.app_name}-wordpress-uploads" }
  )
}

# Block public access
resource "aws_s3_bucket_public_access_block" "wordpress_uploads" {
  bucket = aws_s3_bucket.wordpress_uploads.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Enable versioning
resource "aws_s3_bucket_versioning" "wordpress_uploads" {
  bucket = aws_s3_bucket.wordpress_uploads.id

  versioning_configuration {
    status = "Enabled"
  }
}

# Enable encryption
resource "aws_s3_bucket_server_side_encryption_configuration" "wordpress_uploads" {
  bucket = aws_s3_bucket.wordpress_uploads.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

# Bucket policy - allow EC2 instance to upload/download
resource "aws_s3_bucket_policy" "wordpress_uploads" {
  bucket = aws_s3_bucket.wordpress_uploads.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "AllowWordPressUploads"
        Effect = "Allow"
        Principal = {
          AWS = aws_iam_role.wordpress_ec2.arn
        }
        Action = [
          "s3:GetObject",
          "s3:PutObject",
          "s3:DeleteObject",
          "s3:ListBucket"
        ]
        Resource = [
          aws_s3_bucket.wordpress_uploads.arn,
          "${aws_s3_bucket.wordpress_uploads.arn}/*"
        ]
      }
    ]
  })
}

# Lifecycle policy - clean up old versions after 30 days
resource "aws_s3_bucket_lifecycle_configuration" "wordpress_uploads" {
  bucket = aws_s3_bucket.wordpress_uploads.id

  rule {
    id     = "delete-old-versions"
    status = "Enabled"
    filter {}

    noncurrent_version_expiration {
      noncurrent_days = 30
    }
  }

  rule {
    id     = "abort-incomplete-uploads"
    status = "Enabled"
    filter {}

    abort_incomplete_multipart_upload {
      days_after_initiation = 7
    }
  }
}

# Note: aws_caller_identity is defined in main.tf
