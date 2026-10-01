#!/bin/bash
# k8s_debug.sh — cluster-wide then namespace-focused Kubernetes diagnostics.
# Usage: k8s_debug.sh [namespace] [pod]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

NS="${1:-}"
POD="${2:-}"

ir_header "Kubernetes Diagnostics"

if ! command -v kubectl >/dev/null 2>&1; then
  ir_fail "kubectl not found in PATH"
  exit 1
fi

ir_section "Context"
kubectl config current-context 2>/dev/null || ir_warn "no current context"
kubectl cluster-info 2>/dev/null | head -n 8 || ir_fail "cannot reach API server"

ir_section "Component / node health"
kubectl get --raw='/readyz?verbose' 2>/dev/null | tail -n 20 || ir_info "readyz not permitted or unavailable"
echo
kubectl get nodes -o wide 2>/dev/null || true
echo
echo "not-Ready nodes:"
kubectl get nodes --no-headers 2>/dev/null | awk '$2 !~ /Ready/ {print}' || true

ir_section "Unhealthy workloads (all namespaces)"
echo "CrashLoop / Error / Pending / ImagePull pods:"
kubectl get pods -A --no-headers 2>/dev/null \
  | awk '$4 !~ /Running|Succeeded|Completed/ {print}' | head -n 40
echo
echo "recent warning events:"
kubectl get events -A --sort-by='.lastTimestamp' 2>/dev/null \
  | awk 'tolower($0) ~ /warn|fail|error|kill|probe|unhealthy|backoff/' \
  | tail -n 25

if command -v kubectl >/dev/null && kubectl top nodes >/dev/null 2>&1; then
  ir_section "Metrics"
  kubectl top nodes 2>/dev/null || true
  kubectl top pods -A --sort-by=memory 2>/dev/null | head -n 15 || true
else
  ir_info "metrics-server not installed or not permitted"
fi

if [[ -n "$NS" ]]; then
  ir_section "Namespace ${NS}"
  kubectl get all,cm,secret,pvc,ingress,networkpolicy -n "$NS" 2>/dev/null || kubectl get all -n "$NS"
  echo
  echo "events:"
  kubectl get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -n 20
fi

if [[ -n "$NS" && -n "$POD" ]]; then
  ir_section "Pod ${NS}/${POD}"
  kubectl describe pod -n "$NS" "$POD" 2>/dev/null | tail -n 80
  echo
  echo "logs (current, last 80):"
  kubectl logs -n "$NS" "$POD" --tail=80 --all-containers 2>/dev/null || true
  echo
  echo "logs (previous, last 40 — useful after crash):"
  kubectl logs -n "$NS" "$POD" --tail=40 --previous --all-containers 2>/dev/null || ir_info "no previous container"
fi

ir_section "Suggested next checks"
cat <<'EOF'
  Usage:
    ./scripts/k8s_debug.sh
    ./scripts/k8s_debug.sh production
    ./scripts/k8s_debug.sh production api-7f9c4d6b-xk2nq

  ImagePullBackOff : registry auth, image name, node egress, pull secrets.
  CrashLoopBackOff : k8s_workload_debug.sh <ns> <name> + logs --previous.
  Pending          : k8s_node_debug.sh and PVC/storage class.
  Service 5xx      : k8s_network_debug.sh <ns> <svc>
  Metrics / pages  : prometheus_debug.sh and scripts/promql/k8s.promql
  Node NotReady    : kubelet logs, disk pressure, CNI, cloud provider API.
EOF

