# AWS EC2 diagnostics

Script: `scripts/ec2_debug.sh <instance-id> [region]`

Requires AWS CLI credentials with at least:

- `ec2:DescribeInstances`
- `ec2:DescribeInstanceStatus`
- `ec2:DescribeVolumes`
- `ec2:DescribeSecurityGroups`
- `cloudwatch:GetMetricStatistics`
- optional `ssm:DescribeInstanceInformation`

## Status checks

| Check | Meaning |
| --- | --- |
| System reachability | AWS network path to the instance. Failure is rarely fixable in the guest. Stop-start or the AWS console “retire” path. |
| Instance reachability | Guest kernel answered. Failure: hung OS, bad fstab, full disk preventing boot, panic. Serial console or snapshot + mount elsewhere. |

Both OK + application down → log into the guest and run `server_health.sh`.

## Burstable CPU

`CPUUtilization` at 100% on `t3`/`t4g` with empty `CPUCreditBalance` is not an application bug. Confirm with CloudWatch before you profile Java.

## Security groups

The script prints ingress CIDRs. “I cannot curl the app” is often `0.0.0.0/0` missing on the *wrong* group, or an NACL on the subnet that the instance view will not show. Pair with `network_debug.sh` from inside the guest.
