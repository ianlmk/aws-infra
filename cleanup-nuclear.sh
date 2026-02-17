#!/bin/bash
#================================================================#
# NUCLEAR CLEANUP SCRIPT                                         #
# Forcefully delete ALL infrastructure resources in proper order #
# Usage: ./cleanup-nuclear.sh [account_profile] [region]         #
#================================================================#

set -e

PROFILE="${1:-seldon}"
REGION="${2:-us-east-2}"

echo "🗑️ NUCLEAR INFRASTRUCTURE CLEANUP"
echo "Profile: $PROFILE"
echo "Region: $REGION"
echo ""

# Helper function
delete_resource() {
  local name="$1"
  local cmd="$2"
  echo -n "  ⏳ $name... "
  if eval "$cmd" 2>&1 | grep -q "error\|Error\|ERROR"; then
    echo "❌"
  else
    echo "✅"
  fi
}

delete_with_filter() {
  local name="$1"
  local resource_type="$2"
  local cmd="$3"
  
  echo "Deleting $name..."
  eval "aws $resource_type list-$name --region $REGION --profile $PROFILE --query '${name}[*].[${resource_type}Id,${resource_type}Id]' --output text 2>/dev/null | awk '{print \$1}'" | while read id; do
    [ -z "$id" ] && continue
    echo "  Deleting $id..."
    eval "$cmd --$resource_type-id $id --region $REGION --profile $PROFILE" 2>&1 | head -1 || true
  done
}

#================================================#
# 1. Terminate EC2 Instances
#================================================#
echo "1️⃣  EC2 INSTANCES"
aws ec2 describe-instances --region $REGION --profile $PROFILE \
  --query 'Reservations[*].Instances[?State.Name!=`terminated`].[InstanceId]' \
  --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Terminating $id..."
  aws ec2 terminate-instances --region $REGION --profile $PROFILE --instance-ids "$id" 2>&1 | head -1 || true
done
echo "  Waiting 30s for terminations..."
sleep 30
echo "✅ EC2 instances terminated"
echo ""

#================================================#
# 2. Delete RDS Databases
#================================================#
echo "2️⃣  RDS DATABASES"
aws rds describe-db-instances --region $REGION --profile $PROFILE \
  --query 'DBInstances[?DBInstanceStatus!=`deleting`].DBInstanceIdentifier' \
  --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting RDS $id..."
  aws rds delete-db-instance --region $REGION --profile $PROFILE \
    --db-instance-identifier "$id" --skip-final-snapshot 2>&1 | head -1 || true
done
echo "✅ RDS databases deleted"
echo ""

#================================================#
# 3. Delete RDS Subnet Groups
#================================================#
echo "3️⃣  RDS SUBNET GROUPS"
aws rds describe-db-subnet-groups --region $REGION --profile $PROFILE \
  --query 'DBSubnetGroups[*].DBSubnetGroupName' --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting subnet group $id..."
  aws rds delete-db-subnet-group --region $REGION --profile $PROFILE \
    --db-subnet-group-name "$id" 2>&1 | head -1 || true
done
echo "✅ RDS subnet groups deleted"
echo ""

#================================================#
# 4. Delete Key Pairs
#================================================#
echo "4️⃣  KEY PAIRS"
aws ec2 describe-key-pairs --region $REGION --profile $PROFILE \
  --query 'KeyPairs[*].KeyName' --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting key pair $id..."
  aws ec2 delete-key-pair --region $REGION --profile $PROFILE --key-name "$id" 2>&1 | head -1 || true
done
echo "✅ Key pairs deleted"
echo ""

#================================================#
# 5. Delete Network Interfaces (force detach)
#================================================#
echo "5️⃣  NETWORK INTERFACES"
aws ec2 describe-network-interfaces --region $REGION --profile $PROFILE \
  --query 'NetworkInterfaces[?Status!=`available`].NetworkInterfaceId' \
  --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Detaching $id..."
  aws ec2 detach-network-interface --region $REGION --profile $PROFILE \
    --attachment-id $(aws ec2 describe-network-interfaces --region $REGION --profile $PROFILE \
    --network-interface-ids "$id" --query 'NetworkInterfaces[0].Attachment.AttachmentId' --output text) 2>&1 | head -1 || true
done
sleep 10
echo "✅ Network interfaces detached"
echo ""

#================================================#
# 6. Delete NAT Gateways
#================================================#
echo "6️⃣  NAT GATEWAYS"
aws ec2 describe-nat-gateways --region $REGION --profile $PROFILE \
  --filter "Name=state,Values=available" --query 'NatGateways[*].NatGatewayId' \
  --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting NAT gateway $id..."
  aws ec2 delete-nat-gateway --region $REGION --profile $PROFILE --nat-gateway-id "$id" 2>&1 | head -1 || true
done
echo "  Waiting 30s for NAT gateways to delete..."
sleep 30
echo "✅ NAT gateways deleted"
echo ""

#================================================#
# 7. Release Elastic IPs
#================================================#
echo "7️⃣  ELASTIC IPs"
aws ec2 describe-addresses --region $REGION --profile $PROFILE \
  --query 'Addresses[?AssociationId==null].AllocationId' \
  --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Releasing $id..."
  aws ec2 release-address --region $REGION --profile $PROFILE --allocation-id "$id" 2>&1 | head -1 || true
done
echo "✅ Elastic IPs released"
echo ""

#================================================#
# 8. Detach Internet Gateways
#================================================#
echo "8️⃣  INTERNET GATEWAYS"
aws ec2 describe-internet-gateways --region $REGION --profile $PROFILE \
  --query 'InternetGateways[*].[InternetGatewayId,Attachments[0].VpcId]' \
  --output text | while read igw vpc; do
  if [ ! -z "$vpc" ] && [ "$vpc" != "None" ]; then
    echo "  Detaching $igw from $vpc..."
    aws ec2 detach-internet-gateway --region $REGION --profile $PROFILE \
      --internet-gateway-id "$igw" --vpc-id "$vpc" 2>&1 | head -1 || true
  fi
done
sleep 5
echo "✅ Internet gateways detached"
echo ""

#================================================#
# 9. Delete Internet Gateways
#================================================#
echo "9️⃣  DELETE INTERNET GATEWAYS"
aws ec2 describe-internet-gateways --region $REGION --profile $PROFILE \
  --query 'InternetGateways[*].InternetGatewayId' --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting $id..."
  aws ec2 delete-internet-gateway --region $REGION --profile $PROFILE --internet-gateway-id "$id" 2>&1 | head -1 || true
done
echo "✅ Internet gateways deleted"
echo ""

#================================================#
# 10. Delete Security Groups (non-default)
#================================================#
echo "🔟 SECURITY GROUPS"
aws ec2 describe-security-groups --region $REGION --profile $PROFILE \
  --query 'SecurityGroups[?GroupName!=`default`].GroupId' --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting $id..."
  aws ec2 delete-security-group --region $REGION --profile $PROFILE --group-id "$id" 2>&1 | head -1 || true
done
echo "✅ Security groups deleted"
echo ""

#================================================#
# 11. Delete Subnets
#================================================#
echo "1️⃣1️⃣  SUBNETS"
aws ec2 describe-subnets --region $REGION --profile $PROFILE \
  --query 'Subnets[*].SubnetId' --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting $id..."
  aws ec2 delete-subnet --region $REGION --profile $PROFILE --subnet-id "$id" 2>&1 | head -1 || true
done
sleep 5
echo "✅ Subnets deleted"
echo ""

#================================================#
# 12. Delete Route Tables (non-main)
#================================================#
echo "1️⃣2️⃣  ROUTE TABLES"
aws ec2 describe-route-tables --region $REGION --profile $PROFILE \
  --query 'RouteTables[?Associations[?Main==`false`]].RouteTableId' \
  --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting $id..."
  aws ec2 delete-route-table --region $REGION --profile $PROFILE --route-table-id "$id" 2>&1 | head -1 || true
done
echo "✅ Route tables deleted"
echo ""

#================================================#
# 13. Delete VPCs (non-default)
#================================================#
echo "1️⃣3️⃣  VPCs"
aws ec2 describe-vpcs --region $REGION --profile $PROFILE \
  --query 'Vpcs[?IsDefault==`false`].VpcId' --output text | tr '\t' '\n' | while read id; do
  [ -z "$id" ] && continue
  echo "  Deleting $id..."
  aws ec2 delete-vpc --region $REGION --profile $PROFILE --vpc-id "$id" 2>&1 | head -1 || true
done
sleep 10
echo "✅ VPCs deleted"
echo ""

#================================================#
# 14. Delete Route53 Zones (skip pre-existing)
#================================================#
echo "1️⃣4️⃣  ROUTE53 ZONES"
aws route53 list-hosted-zones --profile $PROFILE \
  --query 'HostedZones[?Name==`surfingclouds.io.`].Id' --output text | sed 's|/hostedzone/||' | while read zone; do
  [ -z "$zone" ] && continue
  echo "  Clearing records in zone $zone..."
  aws route53 list-resource-record-sets --hosted-zone-id "$zone" --profile $PROFILE \
    --query 'ResourceRecordSets[?Type!=`NS` && Type!=`SOA`].[Name,Type]' \
    --output text | while read name type; do
    [ -z "$name" ] && continue
    echo "    Deleting $type $name"
    aws route53 change-resource-record-sets --hosted-zone-id "$zone" --profile $PROFILE \
      --change-batch "{\"Changes\":[{\"Action\":\"DELETE\",\"ResourceRecordSet\":{\"Name\":\"$name\",\"Type\":\"$type\"}}]}" 2>&1 | head -1 || true
  done
  echo "  Deleting zone $zone..."
  aws route53 delete-hosted-zone --id "$zone" --profile $PROFILE 2>&1 | head -1 || true
done
echo "✅ Route53 zones deleted"
echo ""

#================================================#
# 15. Delete S3 Buckets
#================================================#
echo "1️⃣5️⃣  S3 BUCKETS"
aws s3api list-buckets --profile $PROFILE --query 'Buckets[*].Name' --output text | tr '\t' '\n' | while read bucket; do
  [ -z "$bucket" ] && continue
  if [[ "$bucket" == *"tfstate"* ]] || [[ "$bucket" == *"app"* ]] || [[ "$bucket" == *"free-tier"* ]]; then
    echo "  Clearing and deleting $bucket..."
    aws s3 rm "s3://$bucket" --recursive --profile $PROFILE 2>&1 | tail -1 || true
    aws s3api delete-bucket --bucket "$bucket" --profile $PROFILE 2>&1 | head -1 || true
  fi
done
echo "✅ S3 buckets deleted"
echo ""

#================================================#
# 16. Delete DynamoDB Tables
#================================================#
echo "1️⃣6️⃣  DYNAMODB TABLES"
aws dynamodb list-tables --region $REGION --profile $PROFILE \
  --query 'TableNames[?contains(@, `terraform`) || contains(@, `lock`)]' \
  --output text | tr '\t' '\n' | while read table; do
  [ -z "$table" ] && continue
  echo "  Deleting $table..."
  aws dynamodb delete-table --region $REGION --profile $PROFILE --table-name "$table" 2>&1 | head -1 || true
done
echo "✅ DynamoDB tables deleted"
echo ""

echo "═════════════════════════════════════════════════"
echo "🎯 NUCLEAR CLEANUP COMPLETE"
echo "═════════════════════════════════════════════════"
