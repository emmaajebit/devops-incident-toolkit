#!/bin/bash
# ec2_debug.sh - Inspect AWS infrastructure around an EC2 instance

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

INSTANCE_ID="${1:-}"
REGION="${2:-us-east-1}"

if [[ "${1:-}" == "--help" || -z "$INSTANCE_ID" ]]; then
  echo "Usage: $0 <instance-id> [region]"
  echo "Example: $0 i-0123456789abcdef0 us-east-1"
  exit 0
fi

print_header "EC2 DEBUG for $INSTANCE_ID in $REGION"

print_header "Instance Details"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
  --query 'Reservations[0].Instances[0].[InstanceId,InstanceType,State.Name,PrivateIpAddress,PublicIpAddress,Placement.AvailabilityZone,Platform]' \
  --output text

print_header "Status Checks"
aws ec2 describe-instance-status --instance-ids "$INSTANCE_ID" --region "$REGION" \
  --query 'InstanceStatuses[0].[SystemStatus.Status,InstanceStatus.Status]' --output text

print_header "Attached EBS Volumes"
aws ec2 describe-volumes --region "$REGION" --filters Name=attachment.instance-id,Values="$INSTANCE_ID" \
  --query 'Volumes[*].[VolumeId,Size,VolumeType,State]' --output text

print_header "Security Groups"
aws ec2 describe-instances --instance-ids "$INSTANCE_ID" --region "$REGION" \
  --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' --output text

echo -e "\n${GREEN}EC2 debug complete.${NC}"