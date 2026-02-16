# Root outputs — exposed from child modules

output "iam_users" {
  description = "IAM users created by the IAM module"
  value       = module.iam.users
}

output "iam_access_keys" {
  description = "IAM access key IDs (retrieve secrets from state)"
  value       = module.iam.access_keys
}

output "iam_policies" {
  description = "IAM policies created"
  value       = module.iam.policies
}

output "account_info" {
  description = "AWS account and region information"
  value = {
    account_id = local.account_id
    region     = local.region
  }
}

output "iam_access_keys_secret" {
  description = "IAM access key secrets (sensitive - do not log)"
  value       = module.iam.access_keys_secret
  sensitive   = true
}
