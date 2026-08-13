#!/bin/bash
# k8s_debug.sh - Troubleshoot Kubernetes workloads

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

NAMESPACE="${1:-default}"

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [namespace]"
  echo "Default: default"
  exit 0
fi

print_header "KUBERNETES DEBUG in namespace: $NAMESPACE"

print_header "Cluster Info"
kubectl cluster-info || { echo "Cannot reach cluster"; exit 1; }

print_header "Nodes"
kubectl get nodes -o wide

print_header "Pods in $NAMESPACE"
kubectl get pods -n "$NAMESPACE" -o wide

print_header "Events (last 30m)"
kubectl get events -n "$NAMESPACE" --sort-by=.lastTimestamp | tail -15

print_header "Top Resource Consumers"
kubectl top pods -n "$NAMESPACE" 2>/dev/null || echo "Metrics server not available"

print_header "CrashLoopBackOff / ImagePullBackOff Pods"
kubectl get pods -n "$NAMESPACE" | grep -E 'CrashLoopBackOff|ImagePullBackOff|Error' || echo "None found"

echo -e "\n${GREEN}Kubernetes debug complete.${NC}"