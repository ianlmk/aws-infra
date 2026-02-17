output "bucket_id" {
  value       = aws_s3_bucket.main.id
  description = "Bucket ID"
}

output "bucket_arn" {
  value       = aws_s3_bucket.main.arn
  description = "Bucket ARN"
}

output "bucket_region" {
  value       = aws_s3_bucket.main.region
  description = "Bucket region"
}

output "bucket_domain_name" {
  value       = aws_s3_bucket.main.bucket_regional_domain_name
  description = "Bucket regional domain name"
}
