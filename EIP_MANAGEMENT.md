#-----------#
# EIP Management #
#-----------#

**Status:** ✅ Enabled with smart lifecycle control

## Overview

Elastic IP (EIP) is now enabled with **release on pause** strategy. Cost structure:

```
EIP allocated + attached to running instance = FREE
EIP allocated + attached to STOPPED instance = $3.50/month (CHARGING!)
EIP NOT allocated at all                     = FREE
```

**Your setup:** Release EIP on pause (unallocate) → costs $0 during downtime
**Trade-off:** 24h DNS resolution issues after resume (acceptable for personal site)

## Smart Features

### 1. Dynamic DNS Updates
DNS A records automatically pull the web server's EIP. When you release and re-allocate:
- Old EIP: 1.2.3.4 → Deleted
- DNS: Still points to 1.2.3.4 (won't resolve)
- New deployment: Allocates new EIP 5.6.7.8 → DNS updates automatically

### 2. One-Command Lifecycle Management
```bash
cd ~/workspace/seldon/aws-infra

# Check status
./eip-lifecycle.sh status

# Release EIP (save $3.50/month)
./eip-lifecycle.sh release

# Allocate EIP (re-enable DNS)
./eip-lifecycle.sh allocate

# Pause (stop instance + release EIP)
./eip-lifecycle.sh pause
# Cost: $0.50/month (Route53 zone only)

# Resume (start instance + allocate EIP)
./eip-lifecycle.sh resume
# Cost: $0.05-0.30/month (EC2 + Route53)
```

## Cost Scenarios

### Running (Everything On)
```
EC2 t3.micro    = FREE (750h/month)
RDS db.t3.micro = FREE (750h/month)
EIP             = FREE (attached to running instance)
Route53         = $0.50
-----
Total: $0.50/month ✅
```

### Paused (Instance Stopped, EIP Released)
```
EC2 stopped     = FREE (not running, doesn't count hours)
RDS running     = FREE (still within 750h)
EIP             = FREE (not allocated)
Route53         = $0.50
DNS             = ⚠️ Will be dead until resume (24h global propagation)
-----
Total: $0.50/month ✅
Savings: $0 (EIP was free while attached anyway)
```

### Destroyed (Full Teardown)
```
EC2             = FREE (destroyed)
RDS             = FREE (destroyed)
EIP             = FREE (no allocation)
Route53         = $0.50
DNS             = ⚠️ Will be dead for 24h after full redeploy
-----
Total: $0.50/month
```

## Common Workflows

### Workflow 1: Daily Pause (Save Money, Accept DNS Churn)

```bash
# End of workday: Pause for 8 hours
./eip-lifecycle.sh pause
# Cost: $0.50/month (just Route53)
# DNS: Dead until resume + 24h global propagation
# You: Flush browser cache on resume

# Morning: Resume
./eip-lifecycle.sh resume
# New EIP allocated, DNS updated
# Flush cache locally or wait 24h for global DNS resolution
```

**Savings:** $0 during pause (EIP is free when not allocated)  
**Trade-off:** 24h DNS downtime after resume (acceptable for personal use)

### Workflow 2: Weekend Shutdown (Save $17/month)

```bash
# Friday EOD: Full pause
./eip-lifecycle.sh pause

# Monday 9AM: Resume
./eip-lifecycle.sh resume
```

**Savings:** ~$17/month (2 days/week × EIP)

### Workflow 3: Long Project Pause (Multi-week)

```bash
# Before vacation: Full destroy
tofu destroy

# Back from vacation: Full redeploy (takes 15 min)
tofu apply
```

**Savings:** $0.50/month (Route53 only for 3 weeks = ~$0.03)

## Behind the Scenes

### Terraform Changes

**Variables:** `eip_allocation = true`
- EC2 module allocates EIP when true
- EIP is freed when toggled to false

**DNS Records:** Dynamic lookup
```hcl
# Old way (hardcoded):
records = ["0.0.0.0"]

# New way (dynamic):
records = each.value.type == "A" ? [module.web_server[app_key].public_ip] : static_values
```

When EIP is destroyed, DNS records temporarily point to nothing. When you re-allocate:
1. EIP script runs `tofu apply`
2. EC2 module allocates new EIP
3. DNS records automatically update to new EIP IP
4. surfingclouds.io resolves to new IP

### Script Details

`eip-lifecycle.sh` does:

**status:**
- Looks up EC2 instance by tag (`ghost-web`)
- Checks EIP allocation status
- Reports if EIP is attached or orphaned (charging)

**release:**
- `tofu apply -target=eip -destroy`
- Releases EIP, saves $3.50/month
- DNS will stop working until re-allocated

**allocate:**
- `tofu apply -target=eip`
- Allocates new EIP
- `tofu apply -target=dns`
- Updates DNS records with new IP
- Both happen in seconds

**pause:**
- Calls `aws ec2 stop-instances`
- Waits for stop
- Calls `release`
- Total cost: $0.50/month

**resume:**
- Calls `aws ec2 start-instances`
- Waits for start
- Calls `allocate`
- Total cost: $0.05-0.30/month (EC2 + Route53)

## Troubleshooting

### "DNS Not Resolving After Release"
- Expected: Old EIP deleted, new one not allocated yet
- Solution: Run `./eip-lifecycle.sh allocate`
- Time: 30 seconds

### "EIP Charging But Instance is Stopped"
```bash
# Check status
./eip-lifecycle.sh status

# Should show: "EIP: X.X.X.X (NOT attached - CHARGING!)"

# Fix: Release it
./eip-lifecycle.sh release
```

### "Instance ID Not Found"
- Script looks for tags `Name=ghost-web`
- If EC2 was created outside Terraform, tag it manually:
```bash
aws ec2 create-tags --resources i-xxxxx --tags Key=Name,Value=ghost-web
```

## Current Configuration

```hcl
# free-tier.auto.tfvars
web_servers = {
  "ghost" = {
    eip_allocation = true  # EIP enabled
    # ... rest of config
  }
}

dns_records = {
  "ghost" = {
    records = {
      "surfingclouds.io" = {
        type = "A"      # A records auto-pull web_server IP
        values = []     # Empty: populated from EIP
      }
    }
  }
}
```

## Cost Math

**Monthly costs (EIP released on pause):**

| Scenario | Cost | Trade-off |
|----------|------|-----------|
| Always on (24/7) | $0.50/mo | Zero downtime ✅ |
| Pause 12h/day | $0.50/mo | 24h DNS churn on resume ⚠️ |
| Pause weekends | $0.50/mo | 24h DNS churn on resume ⚠️ |
| Pause 2 weeks/month | $0.50/mo | 24h DNS churn on resume ⚠️ |

**Why it's $0.50 regardless:** EIP costs nothing when unallocated. You're not paying extra for pause time. The savings (vs keeping EIP allocated) comes from avoiding the $3.50/month charge during downtime.

---

**TL;DR:**
- EIP is now enabled (FREE when instance is running)
- Use `./eip-lifecycle.sh pause/resume` for cost control
- DNS updates automatically
- Saves $3.50/month per pause cycle
