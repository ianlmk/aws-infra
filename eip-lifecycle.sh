#!/bin/bash
#--------#
# EIP Lifecycle Manager #
#--------#
# 
# Manage Elastic IP allocation/deallocation for cost control
# 
# Usage:
#   ./eip-lifecycle.sh status       # Check current state
#   ./eip-lifecycle.sh release      # Release EIP (save $3.50/month)
#   ./eip-lifecycle.sh allocate     # Allocate EIP (instant resume)
#   ./eip-lifecycle.sh pause        # Release + Stop instance
#   ./eip-lifecycle.sh resume       # Start instance + Allocate EIP
#

set -e

cd "$(dirname "$0")/free-tier"

PROFILE="${AWS_PROFILE:-opentofu}"
APP="ghost"

#---------#
# Helpers #
#---------#

get_instance_id() {
  AWS_PROFILE=$PROFILE aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=$APP-web" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text 2>/dev/null || echo ""
}

get_eip_id() {
  AWS_PROFILE=$PROFILE aws ec2 describe-addresses \
    --filters "Name=tag:Name,Values=$APP-eip" \
    --query 'Addresses[0].AllocationId' \
    --output text 2>/dev/null || echo ""
}

get_instance_state() {
  INSTANCE_ID=$(get_instance_id)
  if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
    echo "not-found"
    return
  fi
  AWS_PROFILE=$PROFILE aws ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text
}

#----------#
# Commands #
#----------#

status() {
  echo "EIP Status Report"
  echo "=================="
  
  INSTANCE_ID=$(get_instance_id)
  EIP_ID=$(get_eip_id)
  
  if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
    echo "❌ Instance not found"
  else
    STATE=$(get_instance_state)
    echo "✅ Instance: $INSTANCE_ID ($STATE)"
  fi
  
  if [ -z "$EIP_ID" ] || [ "$EIP_ID" == "None" ]; then
    echo "⏸️  EIP: Not allocated (no charges)"
  else
    EIP_IP=$(AWS_PROFILE=$PROFILE aws ec2 describe-addresses \
      --allocation-ids "$EIP_ID" \
      --query 'Addresses[0].PublicIp' \
      --output text 2>/dev/null)
    ASSOCIATED=$(AWS_PROFILE=$PROFILE aws ec2 describe-addresses \
      --allocation-ids "$EIP_ID" \
      --query 'Addresses[0].InstanceId' \
      --output text 2>/dev/null)
    
    if [ "$ASSOCIATED" == "None" ] || [ -z "$ASSOCIATED" ]; then
      echo "⚠️  EIP: $EIP_IP (NOT attached - CHARGING $3.50/month!)"
    else
      echo "✅ EIP: $EIP_IP (attached to $ASSOCIATED)"
    fi
  fi
}

release() {
  echo "Releasing EIP (saves $3.50/month)..."
  AWS_PROFILE=$PROFILE ~/.local/bin/tofu apply \
    -target="module.web_server[\"$APP\"].aws_eip.main" \
    -destroy \
    -auto-approve
  echo "✅ EIP released. DNS will stop resolving until you allocate again."
}

allocate() {
  echo "Allocating EIP (enables DNS)..."
  export TF_VAR_databases='{"ghost"={"engine"="mysql","engine_version"="8.0","instance_class"="db.t3.micro","allocated_storage"=20,"storage_type"="gp3","db_name"="ghostdb","username"="admin","password"="TempPassword123!","port"=3306,"backup_retention_days"=7,"multi_az"=false,"skip_final_snapshot"=false,"network_key"="ghost"}}'
  AWS_PROFILE=$PROFILE ~/.local/bin/tofu apply \
    -target="module.web_server[\"$APP\"].aws_eip.main" \
    -target="aws_route53_record.web" \
    -auto-approve
  echo "✅ EIP allocated. DNS updated."
  status
}

pause() {
  echo "Pausing: Stopping instance + releasing EIP..."
  INSTANCE_ID=$(get_instance_id)
  if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
    echo "Stopping $INSTANCE_ID..."
    AWS_PROFILE=$PROFILE aws ec2 stop-instances --instance-ids "$INSTANCE_ID"
    sleep 10  # Wait for stop
  fi
  release
  echo "✅ Paused (costs $0.50/month for Route53 only)"
}

resume() {
  echo "Resuming: Starting instance + allocating EIP..."
  INSTANCE_ID=$(get_instance_id)
  if [ -n "$INSTANCE_ID" ] && [ "$INSTANCE_ID" != "None" ]; then
    STATE=$(get_instance_state)
    if [ "$STATE" == "stopped" ]; then
      echo "Starting $INSTANCE_ID..."
      AWS_PROFILE=$PROFILE aws ec2 start-instances --instance-ids "$INSTANCE_ID"
      sleep 30  # Wait for start
    fi
  fi
  allocate
  echo "✅ Resumed (costs $0.05-0.30/month for EC2 + Route53)"
}

#-----------#
# Main #
#-----------#

COMMAND=${1:-status}

case "$COMMAND" in
  status)
    status
    ;;
  release)
    release
    ;;
  allocate)
    allocate
    ;;
  pause)
    pause
    ;;
  resume)
    resume
    ;;
  *)
    echo "Usage: $0 {status|release|allocate|pause|resume}"
    exit 1
    ;;
esac
