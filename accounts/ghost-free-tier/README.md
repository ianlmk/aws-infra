# Ghost Free Tier Account

## Overview

AWS account for hosting Ghost blog on free tier EC2 + RDS + S3.

- **Account ID:** 870946031520
- **Region:** us-east-2
- **Profile:** seldon
- **Billing:** Free tier only

## Bootstrap Infrastructure

### State Management
- **S3 Bucket:** `tfstate-ghost-870946031520` (encrypted, versioned, public access blocked)
- **DynamoDB Table:** `terraform-locks` (for state locking)

### Setup Instructions

1. **AWS CLI Profile:**
   ```bash
   aws configure --profile seldon
   ```
   Use credentials from the IAM user `seldon` in this account.

2. **Initialize Terraform:**
   ```bash
   cd accounts/ghost-free-tier/terraform
   terraform init
   ```

3. **Plan & Apply:**
   ```bash
   terraform plan
   terraform apply
   ```

## Architecture (Planned)

- **EC2:** t2.micro (free tier eligible)
- **RDS:** t3.micro PostgreSQL (free tier eligible)
- **S3:** Ghost media storage (free tier has limits)
- **Route53:** DNS management for domain
- **Domain:** Pointed via NS records

## Cost Notes

- Free tier covers 12 months
- Monitor usage to stay within limits
- Set up CloudWatch alarms for free tier warnings

## Maintenance

- Terraform state is locked and versioned
- All infrastructure as code in `terraform/`
- Document any manual changes immediately

---

Created: 2026-02-15
