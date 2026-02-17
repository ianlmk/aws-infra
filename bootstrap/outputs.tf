output "opentofu_user_created" {
  description = "ARN of the opentofu IAM user"
  value       = aws_iam_user.opentofu.arn
}

output "opentofu_access_key_id" {
  description = "Access key ID for opentofu user (add to ~/.aws/credentials)"
  value       = aws_iam_access_key.opentofu.id
  sensitive   = true
}

output "opentofu_secret_access_key" {
  description = "Secret access key for opentofu user (save securely, do not commit)"
  value       = aws_iam_access_key.opentofu.secret
  sensitive   = true
}

output "state_bucket_name" {
  description = "S3 bucket name for Terraform state"
  value       = aws_s3_bucket.terraform_state.id
}

output "state_lock_table_name" {
  description = "DynamoDB table name for state locking"
  value       = aws_dynamodb_table.terraform_locks.name
}

output "setup_instructions" {
  description = "Step-by-step instructions to complete bootstrap"
  value = <<-EOT

    ✅ Bootstrap Complete!

    Next Steps:
    ===========

    1. Get the access keys (they're sensitive, so shown only once):
       terraform output -raw opentofu_access_key_id
       terraform output -raw opentofu_secret_access_key

    2. Add to ~/.aws/credentials as a new profile [opentofu]:
       [opentofu]
       aws_access_key_id = <from step 1>
       aws_secret_access_key = <from step 1>
       region = us-east-2

    3. Verify the credentials work:
       aws sts get-caller-identity --profile opentofu
       
       Expected output should show ARN: arn:aws:iam::ACCOUNT:user/opentofu

    4. Test the state backend:
       aws s3 ls ${aws_s3_bucket.terraform_state.id} --profile opentofu
       aws dynamodb describe-table --table-name ${aws_dynamodb_table.terraform_locks.name} --region us-east-2 --profile opentofu

    5. Now deploy infrastructure:
       cd ../free-tier
       terraform init  # This will prompt to use the S3 backend
       terraform plan
       terraform apply

    ⚠️  IMPORTANT:
    - Store the access keys securely (not in git)
    - Do NOT commit terraform.tfstate to git
    - The bootstrap state is stored locally only (fine for one-time setup)
    - Subsequent deployments use the S3 backend

  EOT
}
