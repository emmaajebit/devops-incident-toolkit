#!/bin/bash
# ec2_debug.sh — AWS EC2 instance health via AWS CLI + optional SSM.
# Usage: ec2_debug.sh <instance-id> [region]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

INSTANCE_ID="${1:-}"
REGION="${2:-${AWS_DEFAULT_REGION:-${AWS_REGION:-}}}"

if [[ -z "$INSTANCE_ID" ]]; then
  ir_usage_exit "$0 <instance-id> [region]"
fi

ir_header "AWS EC2 Debug: ${INSTANCE_ID}"

if ! command -v aws >/dev/null 2>&1; then
  ir_fail "aws CLI not found"
  exit 1
fi

AWS_ARGS=()
[[ -n "$REGION" ]] && AWS_ARGS+=(--region "$REGION")
echo "region: ${REGION:-default-from-profile}"

ir_section "Describe instance"
aws ec2 describe-instances "${AWS_ARGS[@]}" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].{
    State:State.Name,
    Type:InstanceType,
    AZ:Placement.AvailabilityZone,
    PrivateIP:PrivateIpAddress,
    PublicIP:PublicIpAddress,
    Subnet:SubnetId,
    Vpc:VpcId,
    Key:KeyName,
    Launch:LaunchTime,
    Platform:PlatformDetails,
    Arch:Architecture,
    LifeCycle:InstanceLifecycle,
    IMDSv2:MetadataOptions.HttpTokens
  }' --output table 2>/dev/null || ir_fail "describe-instances failed"

ir_section "Status checks"
aws ec2 describe-instance-status "${AWS_ARGS[@]}" --instance-ids "$INSTANCE_ID" \
  --include-all-instances \
  --query 'InstanceStatuses[0].{
    System:SystemStatus.Status,
    Instance:InstanceStatus.Status,
    Reachability_System:SystemStatus.Details[0].Status,
    Reachability_Instance:InstanceStatus.Details[0].Status,
    Events:Events
  }' --output table 2>/dev/null || true

ir_section "Volumes"
aws ec2 describe-instances "${AWS_ARGS[@]}" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[].{Dev:DeviceName,Vol:Ebs.VolumeId,DeleteOnTerm:Ebs.DeleteOnTermination}' \
  --output table 2>/dev/null || true

VOLS="$(aws ec2 describe-instances "${AWS_ARGS[@]}" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].BlockDeviceMappings[].Ebs.VolumeId' --output text 2>/dev/null || true)"
if [[ -n "$VOLS" && "$VOLS" != "None" ]]; then
  aws ec2 describe-volumes "${AWS_ARGS[@]}" --volume-ids $VOLS \
    --query 'Volumes[].{Id:VolumeId,Size:Size,Type:VolumeType,Iops:Iops,Thru:Throughput,Enc:Encrypted,State:State}' \
    --output table 2>/dev/null || true
fi

ir_section "Security groups (ingress summary)"
SG_IDS="$(aws ec2 describe-instances "${AWS_ARGS[@]}" --instance-ids "$INSTANCE_ID" \
  --query 'Reservations[0].Instances[0].SecurityGroups[].GroupId' --output text 2>/dev/null || true)"
if [[ -n "$SG_IDS" && "$SG_IDS" != "None" ]]; then
  for sg in $SG_IDS; do
    echo "=== $sg ==="
    aws ec2 describe-security-groups "${AWS_ARGS[@]}" --group-ids "$sg" \
      --query 'SecurityGroups[0].{Name:GroupName,Ingress:IpPermissions[].{Proto:IpProtocol,From:FromPort,To:ToPort,Cidrs:IpRanges[].CidrIp}}' \
      --output json 2>/dev/null | head -n 40
  done
fi

ir_section "CloudWatch CPU (last 3 hours, 5 min)"
END="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
START="$(date -u -d '3 hours ago' +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -v-3H +%Y-%m-%dT%H:%M:%SZ)"
aws cloudwatch get-metric-statistics "${AWS_ARGS[@]}" \
  --namespace AWS/EC2 --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value="$INSTANCE_ID" \
  --start-time "$START" --end-time "$END" --period 300 --statistics Average Maximum \
  --output table 2>/dev/null | tail -n 20 || ir_warn "CloudWatch query failed"

ir_section "SSM (if managed)"
aws ssm describe-instance-information "${AWS_ARGS[@]}" \
  --filters "Key=InstanceIds,Values=${INSTANCE_ID}" \
  --query 'InstanceInformationList[0].{Ping:PingStatus,Agent:AgentVersion,Platform:PlatformName,OS:PlatformVersion}' \
  --output table 2>/dev/null || ir_info "instance may not be SSM-managed"

ir_section "Suggested next checks"
cat <<'EOF'
  System reachability failed  → AWS networking / hypervisor; often needs stop-start.
  Instance reachability failed → guest OS hang; use serial console or SSM.
  High CPU on T-family        → CPUCreditBalance exhausted.
  Status OK but app down      → SSH/SSM in and run server_health.sh on the guest.
EOF

