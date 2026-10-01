#!/bin/bash
# k8s_node_debug.sh — node pressure, kubelet, allocatable vs requests.
# Usage: k8s_node_debug.sh [node-name]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

NODE="${1:-}"

ir_header "Kubernetes Node Diagnostics"

if ! command -v kubectl >/dev/null 2>&1; then
  ir_fail "kubectl not found"
  exit 1
fi

ir_section "Nodes"
kubectl get nodes -o wide
echo
echo "conditions (Ready / MemoryPressure / DiskPressure / PIDPressure / NetworkUnavailable):"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions[*]}{.type}={.status}{" "}{end}{"\n"}{end}' 2>/dev/null
echo
echo "taints:"
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .spec.taints[*]}{.key}={.value}:{.effect}{" "}{end}{"\n"}{end}' 2>/dev/null

if command -v kubectl >/dev/null && kubectl top nodes >/dev/null 2>&1; then
  ir_section "kubectl top nodes"
  kubectl top nodes
else
  ir_info "metrics-server not available — use Prometheus node metrics instead"
fi

ir_section "Allocatable vs allocated (approx via describe headers)"
if [[ -n "$NODE" ]]; then
  kubectl describe node "$NODE" 2>/dev/null | awk '
    /Name:|Roles:|Taints:|Unschedulable:|Allocated resources:|Resource|Requests|Limits|Events:|MemoryPressure|DiskPressure|PIDPressure|NetworkUnavailable|Ready / {print}
  ' | head -n 80
  echo
  echo "pods on ${NODE}:"
  kubectl get pods -A --field-selector spec.nodeName="$NODE" -o wide 2>/dev/null
  echo
  echo "non-Running pods on node:"
  kubectl get pods -A --field-selector spec.nodeName="$NODE" --no-headers 2>/dev/null \
    | awk '$4 !~ /Running|Succeeded|Completed/ {print}'
else
  ir_info "pass a node name for describe + pod list: $0 <node>"
  kubectl describe nodes 2>/dev/null | awk '/^Name:|Allocated resources:|^  (cpu|memory|ephemeral-storage)/ {print}' | head -n 60
fi

ir_section "Suggested Prometheus queries"
cat <<'EOF'
  node_cpu_seconds_total          → rate by instance (busy node)
  node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes
  kube_node_status_condition
  kube_pod_container_resource_requests
  See scripts/promql/k8s.promql and docs/prometheus.md
EOF

