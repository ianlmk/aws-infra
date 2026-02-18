# This file is intentionally minimal - backend is configured in main.tf
#
# The S3 backend configuration in main.tf is:
#   backend "s3" {
#     bucket         = "tfstate-0001x"
#     key            = "ghost-infra/terraform.tfstate"
#     dynamodb_table = "terraform-locks"
#   }
#
# To initialize the remote backend:
#   tofu init -backend-config="bucket=tfstate-0001x" \
#             -backend-config="key=ghost-infra/terraform.tfstate" \
#             -backend-config="dynamodb_table=terraform-locks"
#
# Or simply:
#   tofu init
#
# (Terraform will use the backend config from main.tf)
