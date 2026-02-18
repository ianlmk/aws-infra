output "rds_endpoint" {
  description = "RDS MySQL endpoint (host:port)"
  value       = "${aws_db_instance.wordpress.address}:${aws_db_instance.wordpress.port}"
}

output "rds_address" {
  description = "RDS MySQL hostname"
  value       = aws_db_instance.wordpress.address
}

output "rds_port" {
  description = "RDS MySQL port"
  value       = aws_db_instance.wordpress.port
}

output "rds_database_name" {
  description = "RDS database name"
  value       = aws_db_instance.wordpress.db_name
}

output "rds_username" {
  description = "RDS database username"
  value       = aws_db_instance.wordpress.username
}

output "rds_resource_id" {
  description = "RDS resource ID (for backup/snapshot operations)"
  value       = aws_db_instance.wordpress.resource_id
}

output "s3_bucket_name" {
  description = "S3 bucket for WordPress uploads"
  value       = aws_s3_bucket.wordpress_uploads.id
}

output "s3_bucket_arn" {
  description = "S3 bucket ARN"
  value       = aws_s3_bucket.wordpress_uploads.arn
}

output "wordpress_url" {
  description = "WordPress site URL"
  value       = var.wordpress_url
}

output "wordpress_admin_url" {
  description = "WordPress admin dashboard URL"
  value       = "${var.wordpress_url}/wp-admin/"
}

output "ec2_public_ip" {
  description = "EC2 instance public IP"
  value       = data.aws_instance.web_server.public_ip
}

output "ec2_instance_id" {
  description = "EC2 instance ID"
  value       = data.aws_instance.web_server.id
}

output "iam_role_arn" {
  description = "IAM role ARN for EC2 instance"
  value       = aws_iam_role.wordpress_ec2.arn
}

output "deployment_status" {
  description = "WordPress deployment status"
  value = var.deploy_wordpress ? "✓ Deployment triggered via Ansible" : "⏸ Deployment disabled (manual deployment required)"
}

output "setup_instructions" {
  description = "Post-deployment instructions"
  value = <<-EOF
✓ WordPress infrastructure created!

Next steps:

1. Wait for Ansible deployment to complete (check logs)

2. SSH to EC2 instance:
   ssh -i ~/.ssh/app1-web-key ansible@${data.aws_instance.web_server.public_ip}

3. Verify WordPress is installed:
   sudo systemctl status apache2
   curl http://127.0.0.1

4. Configure WordPress:
   Visit: ${var.wordpress_url}/wp-admin/
   Complete WordPress setup wizard
   Create admin account
   Configure site settings

5. Database info (if needed for manual access):
   Host: ${aws_db_instance.wordpress.address}
   Port: ${aws_db_instance.wordpress.port}
   Database: ${aws_db_instance.wordpress.db_name}
   User: ${aws_db_instance.wordpress.username}
   (Password is in Vault at: secret/aws/wordpress/rds)

6. S3 uploads bucket:
   ${aws_s3_bucket.wordpress_uploads.id}

7. To tear down WordPress infrastructure only:
   terraform destroy
   (Base infrastructure in free-tier/ remains untouched)

Important:
- Database: ${aws_db_instance.wordpress.address}
- S3 Bucket: ${aws_s3_bucket.wordpress_uploads.id}
- EC2 IP: ${data.aws_instance.web_server.public_ip}
- WordPress URL: ${var.wordpress_url}
EOF
}
