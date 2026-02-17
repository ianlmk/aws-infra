#---------------------#
# Free Tier Cost Guide #
#---------------------#

**Goal:** Stay within AWS free tier + minimize charges for shutdown scenarios.

## Monthly Cost Breakdown

### Free Resources (Always)
- VPC, Subnets, IGW, Route Tables: **FREE**
- EC2 t3.micro: **FREE** (750 hrs/month)
- RDS db.t3.micro: **FREE** (750 hrs/month)
- S3: **FREE** (5GB + 20k requests)
- Route53: **$0.50/month** (zone only)

**Subtotal: $0.50/month**

### Paid Resources (Default OFF)

| Resource | Cost | Why | Control |
|----------|------|-----|---------|
| **NAT Gateway** | $32/month | Outbound internet from private subnets | `enable_nat_gateways = true/false` |
| **Elastic IP** | $3.50/month | Static IP for EC2 (if unused) | `eip_allocation = true/false` |
| **RDS beyond 750h** | $0.50+/day | Beyond free tier hours | Stop instance when not needed |
| **Data transfer out** | $0.09/GB | Egress to internet | Minimize downloads |

## Current Configuration (Free Tier)

```hcl
# free-tier.auto.tfvars

networks = {
  "ghost" = {
    enable_nat_gateways = false  # Save $64/month (2 NATs)
  }
}

web_servers = {
  "ghost" = {
    eip_allocation = false  # Save $3.50/month
  }
}
```

**Monthly cost:** $0.50 (Route53 only)

## Scenarios

### Scenario 1: Always-On (Production-Like)
```hcl
enable_nat_gateways = true
eip_allocation = true
# Cost: ~$68/month
```

Use when: Running Ghost 24/7, need static IPs.

### Scenario 2: Free-Tier Only (Development)
```hcl
enable_nat_gateways = false
eip_allocation = false
# Cost: $0.50/month
```

Use when: Testing, development, not running public web server.

### Scenario 3: Killswitch (Shut Everything Down)
```bash
# Remove all app infrastructure
tofu apply -destroy

# Or selectively:
tofu plan -target=module.web_server -destroy
tofu plan -target=module.database -destroy
tofu plan -target=module.storage -destroy

# Keep: VPC, subnets, IAM, Route53 (minimal cost)
```

Cost when destroyed: $0.50/month (Route53 zone only)

## RDS Shutdown Pattern

RDS instances count toward free tier **only if running < 750 hours/month**.

To stay free:
```hcl
# Option A: Stop RDS (when not needed)
# In AWS console: RDS → Instance → Instance Actions → Stop

# Option B: Destroy and recreate (via Terraform)
databases = {}  # Remove this app
tofu apply      # Destroys RDS instance

# Option C: Set skip_final_snapshot for dev teardowns
skip_final_snapshot = true  # Deletes data on destroy (dev only!)
```

## Free Tier Hours Calculation

**750 hours/month available for:**
- EC2 t3.micro (1 instance)
- RDS db.t3.micro (1 instance)

**Examples:**
- Run 24/7 for 31 days = 744 hours ✅ (within free tier)
- Run 24/7 for 32 days = 768 hours ❌ (costs ~$20)
- Run 8h/day = 240 hours ✅ (safe margin)
- Run 16h/day = 480 hours ✅ (safe margin)

## Elastic IP Lifecycle (With Smart Release)

Elastic IPs charge:
- **FREE** while attached to running instance
- **$3.50/month** if unattached OR attached to stopped instance

**Current setup:** EIP enabled, DNS auto-updates

When you want to **pause and save money:**

```bash
# Shutdown with cost savings (2 options)

# Option A: Release EIP only (instance stays up)
tofu apply -target='module.web_server["ghost"].aws_eip.main' -destroy
# Cost: $0 / month
# Resume: tofu apply (recreates EIP + DNS updates automatically)

# Option B: Stop instance + release EIP
aws ec2 stop-instances --instance-ids $(tofu output -raw web_servers.ghost.instance_id 2>/dev/null || echo "")
tofu apply -target='module.web_server["ghost"].aws_eip.main' -destroy
# Cost: $0 / month (stopped instance doesn't charge)
# Resume: 
#   aws ec2 start-instances --instance-ids <id>  # Start instance
#   tofu apply                                     # Recreate EIP + DNS

# Option C: Nuclear (destroy everything)
tofu destroy
# Cost: $0.50/month (Route53 zone only)
# Resume: 10-15 min to redeploy everything
```

**DNS automatically updates:**
```
Before shutdown:  surfingclouds.io → 1.2.3.4 (EIP)
After destroy EIP: DNS still points to old IP (won't resolve)
After tofu apply:  surfingclouds.io → NEW.EIP.IP (updated automatically)
```

## NAT Gateway Gotcha

NAT Gateways charge:
- $32/month per gateway (hourly: $0.045/hour)
- $0.045 per GB of data processed

**Common mistake:**
```hcl
# ❌ BAD: Private subnets need NAT but you enable it "just in case"
enable_nat_gateways = true
# ↳ Costs $64/month even if RDS isn't using it

# ✅ GOOD: Only enable if private subnets actually need egress
enable_nat_gateways = false
# RDS in private subnets doesn't need NAT (no outbound)
```

## Recommended Setup

### Development (Free)
```hcl
networks = {
  "ghost" = {
    enable_nat_gateways = false
    public_subnet_cidrs = ["10.0.1.0/24"]  # One public subnet (dev)
  }
}

web_servers = {
  "ghost" = {
    eip_allocation = false
  }
}

databases = {
  "ghost" = { ... }
}

storage_buckets = {
  "ghost" = { ... }
}

# Cost: $0.50/month
# Runtime: 8h/day (240 hrs) → Well within free tier
```

### Stop & Destroy Pattern (Kill Everything)
```bash
# Remove web server
tofu apply -target='module.web_server'

# Remove database (creates final snapshot, keeps data)
tofu apply -target='module.database'

# Remove storage
tofu apply -target='module.storage'

# Remove DNS (optional)
tofu apply -target='aws_route53_record.web' -destroy

# Keep: VPC, IAM, Route53 zone (~$0.50/month)
```

## Cost Optimization Checklist

- [ ] `enable_nat_gateways = false` (unless private subnets need internet)
- [ ] `eip_allocation = false` (use auto-assigned public IP)
- [ ] RDS on `t3.micro` (free tier eligible)
- [ ] EC2 on `t3.micro` (free tier eligible)
- [ ] S3 storage < 5GB (free tier)
- [ ] Monitor monthly usage in AWS Billing Dashboard
- [ ] Set up cost alerts (AWS Budgets)
- [ ] Stop/destroy when not actively using

## AWS Budgets Setup

Prevent runaway charges:
```bash
AWS Console → Billing → Budgets
  Name: "Free Tier Alert"
  Type: "Zero Spend Budget" (ideal) or $5/month limit
  Alert: When forecasted > limit
  Recipients: your@email.com
```

## Variables for Cost Control

Quick toggles:

```hcl
# free-tier.auto.tfvars

# Toggle on to spend money, off to stay free
networks = {
  "ghost" = {
    enable_nat_gateways = false  # true = +$64/month
  }
}

web_servers = {
  "ghost" = {
    eip_allocation = false  # true = +$3.50/month
  }
}

# Toggle off entire app to destroy it
web_servers = {}  # Destroy web server
databases = {}    # Destroy database
storage_buckets = {}  # Destroy storage
dns_records = {}  # Destroy DNS records

# Leave blank = all infrastructure destroyed
# Cost returns to $0.50/month (Route53 zone only)
```

---

**Bottom Line:** You're paying **$0.50/month** now. Anything else is a choice (NAT, EIP, RDS overages). You can go to zero by destroying resources, back to $0.50 when just the VPC + Route53 remain.
