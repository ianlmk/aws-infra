# Ghost Infrastructure Module

Deploys **Ghost CMS** on AWS using OpenTofu, with RDS database, EC2 compute, and Nginx reverse proxy.

## Overview

This module creates:

- **EC2 Instance** (t3.micro, free-tier eligible)
  - Ubuntu 22.04 LTS
  - Node.js + Ghost CLI
  - Nginx reverse proxy (port 80 → Ghost 2368)
  - CloudWatch monitoring
  - SystemD service management

- **RDS MySQL Database** (db.t3.micro, free-tier eligible)
  - MySQL 8.0
  - Automated backups (7 days retention)
  - Multi-AZ: disabled (to save costs)
  - Encrypted storage
  - Parameter group optimized for Ghost

- **Networking**
  - References VPC/subnets from `free-tier` module
  - Security groups for web, app, and database tiers
  - Nginx on port 80/443, Ghost on 2368 (internal only)

- **Secrets Management**
  - RDS password from Vault (`secret/ghost/rds`)
  - SSH key from Vault (`secret/ghost/ssh`)

## Prerequisites

1. **Free-tier network infrastructure deployed**
   ```bash
   cd ../free-tier
   tofu apply
   ```

2. **Vault secrets configured**
   ```bash
   vault kv put secret/ghost/rds password=<strong-password>
   vault kv put secret/ghost/ssh private_key=@~/.ssh/id_rsa
   ```

3. **Vault server running**
   ```bash
   vault server -dev
   ```

4. **Terraform state backend ready**
   - S3 bucket: `tfstate-0001x`
   - DynamoDB table: `terraform-locks`

## Deployment

### 1. Initialize Remote State

```bash
cd ghost-infra
tofu init
```

### 2. Plan the Deployment

```bash
export TF_VAR_vault_token=$(vault print token)
tofu plan -out=tfplan
```

### 3. Apply Infrastructure

```bash
tofu apply tfplan
```

**What happens:**
- RDS database created (~5-10 minutes)
- EC2 instance launched (~2 minutes)
- User data script runs Ghost provisioning
- Nginx configured as reverse proxy
- CloudWatch logs enabled

### 4. Verify Installation

After apply completes, outputs will show:

```
ghost_infrastructure = {
  ec2 = {
    public_ip = "x.x.x.x"
    instance_id = "i-..."
  }
  rds = {
    endpoint = "app1-ghost-mysql.cbc2...us-east-2.rds.amazonaws.com"
  }
}
```

#### SSH into Instance
```bash
ssh -i ~/.ssh/app1-web-key ubuntu@<public-ip>
```

#### Check Ghost Status
```bash
# From EC2 instance
systemctl status ghost
journalctl -u ghost -f  # Follow logs
```

#### Nginx Status
```bash
sudo systemctl status nginx
sudo tail -f /var/log/nginx/error.log
```

## Configuration

Edit `ghost.auto.tfvars` to customize:

```hcl
ghost_url = "https://yourdomain.com"  # Your actual domain
ghost_admin_email = "admin@yourdomain.com"

rds_instance_class = "db.t3.micro"    # Free tier
ec2_instance_type = "t3.micro"        # Free tier

backup_retention_days = 7
enable_ssl = true                     # Let's Encrypt via Certbot
```

## Monitoring

### CloudWatch Logs
```bash
# From AWS Console
CloudWatch > Log Groups > /aws/ec2/app1-ghost
```

### RDS Performance
```bash
# From AWS Console
RDS > Databases > app1-ghost-mysql > Monitoring
```

## Cost Estimation

| Resource | Cost | Notes |
|----------|------|-------|
| EC2 t3.micro | FREE | 750 hrs/month free tier |
| RDS db.t3.micro | FREE | 750 hrs/month free tier |
| Storage (30 GB) | ~$3.06 | gp3 pricing |
| **Monthly Total** | **~$3.06** | (within free tier) |

**Outside free tier:**
- Data transfer: $0.01/GB
- Elastic IP: $3.50/month (if not attached)
- NAT Gateway: $32/month (if enabled)

## Destroying Infrastructure

```bash
# Graceful destroy (respects deletion protection)
tofu destroy -auto-approve

# View what will be destroyed
tofu plan -destroy
```

**Before destroying in production:**
- Create final RDS snapshot: `skip_final_snapshot = false`
- Download Ghost content and database backup
- Verify no important data will be lost

## Troubleshooting

### Ghost Won't Start
```bash
ssh -i ~/.ssh/app1-web-key ubuntu@<ip>
sudo journalctl -u ghost -n 50  # Last 50 log entries
```

### Database Connection Failed
```bash
# Check RDS security group allows inbound on 3306
aws ec2 describe-security-groups --group-ids sg-...
```

### Nginx Returns 502 Bad Gateway
```bash
# Ghost may still be starting (5-10 minutes)
sudo systemctl is-active ghost
sudo curl http://127.0.0.1:2368  # Test local port
```

### SSL Certificate Issues
```bash
# Check Certbot status
sudo certbot certificates
sudo certbot renew --dry-run
```

## Advanced Features

### Enable Performance Insights
```hcl
enable_performance_insights = true  # Extra cost
```

### Enable Multi-AZ Database
```hcl
# Edit rds.tf: multi_az = true
# Cost: doubles RDS price (~$30-40/month)
```

### Add Elastic IP
```hcl
# Uncomment in ec2.tf: resource "aws_eip" "ghost"
# Cost: $3.50/month
```

### CloudWatch Alarms
Create custom alarms in AWS Console for:
- High CPU (EC2)
- Database connection count
- Nginx error rate

## Security Notes

⚠️ **Production Checklist:**

- [ ] Restrict SSH to your IP only (not `0.0.0.0/0`)
- [ ] Set `enable_deletion_protection = true`
- [ ] Set `skip_final_snapshot = false`
- [ ] Use strong RDS password (40+ chars)
- [ ] Enable Multi-AZ for HA
- [ ] Configure CloudWatch alarms
- [ ] Set up log retention (currently 7 days)
- [ ] Restrict SMTP/mail service (if applicable)

## Next Steps

1. **Domain Setup**: Point your domain to the EC2 public IP or add Route53 records
2. **SSL Certificate**: Let's Encrypt automatically via `enable_ssl = true`
3. **Ghost Admin**: Visit `https://yourdomain.com/admin` and complete setup
4. **Backups**: Enable automated RDS snapshots (already configured)
5. **Monitoring**: Set up CloudWatch alarms for critical metrics

## Support & Documentation

- [Ghost Docs](https://ghost.org/docs/)
- [Ghost Config](https://ghost.org/docs/config/)
- [Ghost API](https://ghost.org/docs/api/)
- [Ghost Themes](https://ghost.org/resources/)

## State Management

Terraform state is stored remotely in S3 for security and team collaboration:

```
s3://tfstate-0001x/ghost-infra/terraform.tfstate
```

State file contains:
- EC2 instance details
- RDS credentials (encrypted)
- Network configuration
- SSH keys (sensitive)

**Never commit `.tfstate` files to git!**
