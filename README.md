# AWS Infrastructure

Centralized infrastructure as code using **OpenTofu** (open-source successor to Terraform).

- **Why OpenTofu?** Open source (Apache 2.0), community-maintained, 100% compatible with Terraform HCL
- **Cost:** Free
- **State:** S3 + DynamoDB (encrypted, versioned, locked)

## Structure

```
accounts/
├── free-tier/              # Free tier account (multiple projects)
│   ├── README.md
│   └── tofu/               # OpenTofu infrastructure
│       ├── backend.tf      # S3 + DynamoDB backend config
│       ├── bootstrap.tf    # State management resources
│       ├── variables.tf
│       └── projects/       # Per-project configurations
│           ├── ghost/      # Example: Ghost blog project
│           └── api/        # Example: API project
```

## Getting Started

1. **Install OpenTofu:**
   ```bash
   # https://opentofu.org/docs/intro/install/
   brew install opentofu  # macOS
   # or download from https://github.com/opentofu/opentofu/releases
   ```

2. **Select an account (or project):**
   ```bash
   cd accounts/<account-name>/tofu
   # or for a specific project:
   cd accounts/<account-name>/tofu/projects/<project-name>
   ```

3. **Initialize OpenTofu:**
   ```bash
   tofu init
   ```

4. **Plan changes:**
   ```bash
   tofu plan
   ```

5. **Apply:**
   ```bash
   tofu apply
   ```

## AWS Credentials

Each account has a dedicated IAM profile configured locally in `~/.aws/credentials`. See account-specific README for profile names.

## State Management

All OpenTofu state is stored in S3 with:
- Encryption enabled (AES256)
- Versioning enabled
- DynamoDB locking for concurrency
- Public access blocked

State files are never committed to this repository (see `.gitignore`).

## Adding New Accounts

1. Create `accounts/<account-name>/tofu/` directory
2. Create `backend.tf`, `variables.tf`, and resource files
3. Create `accounts/<account-name>/README.md` with account details
4. Document the account setup and any manual bootstrap steps
5. Update S3 bucket and DynamoDB table names in `backend.tf` for the new account

Example `backend.tf`:
```hcl
backend "s3" {
  bucket         = "tfstate-<project-name>"
  key            = "<project-name>/terraform.tfstate"
  region         = "us-east-2"
  encrypt        = true
  dynamodb_table = "terraform-locks"
}
```

**Note:** Bucket names should be organized by project (e.g., `tfstate-ghost`, `tfstate-api`). Do not include AWS account IDs or other sensitive identifying information.

## Cost Tracking

Monitor free tier usage and set up CloudWatch alarms to prevent unexpected charges.

---

**Never commit secrets, credentials, or PII to this repository.**
