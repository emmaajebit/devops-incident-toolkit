#!/bin/bash
# k8s_workload_debug.sh — Deployments, ReplicaSets, HPA, PDB, probes, restarts.
# Usage: k8s_workload_debug.sh <namespace> [name]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

NS="${1:-}"
NAME="${2:-}"

if [[ -z "$NS" ]]; then
  ir_usage_exit "$0 <namespace> [workload-name]"
fi

ir_header "Kubernetes Workload Debug  ns=${NS}  name=${NAME:-*}"

if ! command -v kubectl >/dev/null 2>&1; then
  ir_fail "kubectl not found"
  exit 1
fi

ir_section "Controllers"
kubectl get deploy,sts,ds,job,cronjob,rs,hpa,pdb -n "$NS" -o wide 2>/dev/null || kubectl get deploy,sts,ds -n "$NS"

ir_section "Pods + restart counts"
kubectl get pods -n "$NS" -o wide
echo
echo "restarts > 0:"
kubectl get pods -n "$NS" --no-headers 2>/dev/null | awk '$4+0 > 0 {print}'

ir_section "Recent events"
kubectl get events -n "$NS" --sort-by='.lastTimestamp' 2>/dev/null | tail -n 25

if [[ -n "$NAME" ]]; then
  ir_section "Describe ${NAME}"
  if kubectl get deploy -n "$NS" "$NAME" >/dev/null 2>&1; then
    kubectl describe deploy -n "$NS" "$NAME" | tail -n 60
  elif kubectl get sts -n "$NS" "$NAME" >/dev/null 2>&1; then
    kubectl describe sts -n "$NS" "$NAME" | tail -n 60
  elif kubectl get ds -n "$NS" "$NAME" >/dev/null 2>&1; then
    kubectl describe ds -n "$NS" "$NAME" | tail -n 60
  else
    ir_warn "no deploy/sts/ds named ${NAME}; describing pods matching the name"
  fi
  echo
  PODS="$(kubectl get pods -n "$NS" -o name 2>/dev/null | grep -E "/${NAME}(-|$)" | head -n 5 || true)"
  for p in $PODS; do
    echo "=== $p ==="
    kubectl describe -n "$NS" "$p" 2>/dev/null | awk '/Status:|QoS|Node:|Controlled By|Conditions:|Warning |Error |Restart|OOM|Probe|Events:/ {print}' | tail -n 40
    echo "-- current logs --"
    kubectl logs -n "$NS" "$p" --tail=40 --all-containers 2>/dev/null || true
    echo "-- previous logs --"
    kubectl logs -n "$NS" "$p" --tail=20 --previous --all-containers 2>/dev/null || ir_info "no previous container"
  done
fi

ir_section "HPA / PDB pitfalls"
echo "HPA:"
kubectl get hpa -n "$NS" 2>/dev/null || true
echo "PDB:"
kubectl get pdb -n "$NS" 2>/dev/null || true
ir_info "HPA stuck at min + metrics-server missing looks like 'the app will not scale'"
ir_info "PDB maxUnavailable=0 blocks drains and can strand NotReady nodes"

ir_section "Suggested next checks"
cat <<'EOF'
  CrashLoop  → logs --previous, probes, required Secrets, OOMKilled
  0/1 Ready  → readiness probe + Service endpoints
  Pending    → k8s_node_debug.sh and PVC/storage class
  Flapping   → Prometheus kube_pod_container_status_restarts_total
EOF

