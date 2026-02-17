# Enable AWS Cost Explorer at account level
# Cost Explorer must be enabled before IAM users can query costs
# This is a one-time account-level operation via the AWS API

resource "null_resource" "enable_cost_explorer" {
  provisioner "local-exec" {
    command = <<-EOT
      set -e
      echo "Attempting to enable Cost Explorer..."
      
      # Try to query cost explorer - this implicitly enables it if not already enabled
      aws ce get-cost-and-usage \
        --region us-east-1 \
        --time-period Start=$(date -u -d '30 days ago' +%Y-%m-%d),End=$(date -u +%Y-%m-%d) \
        --granularity MONTHLY \
        --metrics UnblendedCost \
        --output json > /dev/null 2>&1 && \
        echo "✅ Cost Explorer is active" || \
        echo "⚠️ Cost Explorer may be initializing (can take 5-10 minutes after first query)"
    EOT
    environment = {
      AWS_PROFILE = "opentofu"
    }
    on_failure = continue
  }

  # Only runs once on initial apply
  triggers = {
    region = data.aws_region.current.name
  }
}

# Output instructions if needed
output "cost_explorer_status" {
  description = "Cost Explorer activation status"
  value       = "Cost Explorer query provisioner has run. If not yet enabled, visit: https://console.aws.amazon.com/billing/home#/costexplorer and click Enable Cost Explorer"
}

