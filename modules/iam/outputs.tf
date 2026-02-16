output "users" {
  description = "Created IAM users"
  value = {
    for name, user in aws_iam_user.this :
    name => {
      arn  = user.arn
      id   = user.id
      name = user.name
    }
  }
}

output "access_keys" {
  description = "Created access keys (access_key_id only, secret stored in state)"
  value = {
    for user, key in aws_iam_access_key.this :
    user => {
      access_key_id = key.id
      create_date   = key.create_date
    }
  }
  sensitive = false
}

output "access_keys_secret" {
  description = "Access key secrets - retrieve from state only"
  value = {
    for user, key in aws_iam_access_key.this :
    user => key.secret
  }
  sensitive = true
}

output "policies" {
  description = "Created IAM policies"
  value = {
    for name, policy in aws_iam_policy.this :
    name => {
      arn  = policy.arn
      name = policy.name
    }
  }
}
