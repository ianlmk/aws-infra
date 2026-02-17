#-----------#
# Vault Integration #
#-----------#
# Read secrets from local Vault instance
# Requires: VAULT_TOKEN and TF_VAR_vault_token env vars
# Provider config defined in backend.tf

provider "vault" {
  address = "http://localhost:8200"
  token   = var.vault_token
}

#---------#
# Read Secrets from Vault #
#---------#

# RDS credentials
data "vault_generic_secret" "rds_creds" {
  path = "secret/ghost/rds"
}

# SSH keys
data "vault_generic_secret" "ssh_keys" {
  path = "secret/ghost/ssh"
}

# AWS credentials
data "vault_generic_secret" "aws_creds" {
  path = "secret/ghost/aws"
}

#---------#
# Outputs #
#---------#

output "vault_secrets_loaded" {
  value = {
    rds_path = "secret/ghost/rds"
    ssh_path = "secret/ghost/ssh"
    aws_path = "secret/ghost/aws"
    rds_user = data.vault_generic_secret.rds_creds.data["username"]
  }
  description = "Vault secrets successfully loaded"
  sensitive   = true
}
