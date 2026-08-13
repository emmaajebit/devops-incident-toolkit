# DevOps Incident Decision Tree

Start here during an incident.

## Step 1: General Health

Run: `./server_health.sh`

Look for:
- High load average vs CPU cores
- Memory pressure (low available RAM)
- Disk > 90% or inodes 100%
- Failed services
- Recent system errors

## Step 2: Follow the Failing Component

- **CPU high?** → `./cpu_debug.sh`
- **Memory low / OOM?** → `./memory_debug.sh`
- **Disk full?** → `./disk_debug.sh`
- **Network timeout?** → `./network_debug.sh <target> <port>`
- **Service running but broken?** → `./log_debug.sh <service>`
- **Docker container?** → `./docker_debug.sh`
- **Kubernetes pod?** → `./k8s_debug.sh <namespace>`
- **AWS/EC2 issue?** → `./ec2_debug.sh <instance-id> [region]`

## Quick Reference by Symptom

- App slow + high CPU → cpu_debug.sh
- App slow + high memory → memory_debug.sh
- Can't write files → disk_debug.sh (check inodes too!)
- Connection refused/timeout → network_debug.sh
- Service keeps restarting → log_debug.sh + check NRestarts
- Pod CrashLoopBackOff → k8s_debug.sh
- Container exited with 137 → docker_debug.sh (OOM likely)
- Security group blocking DB port → ec2_debug.sh

## The Core Concept

Alert → Hypothesis → Evidence → Fix

Don't just run random commands. Map the symptom to the right tool, gather evidence, then fix.