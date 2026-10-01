#!/bin/bash
# k8s_network_debug.sh — Services, Endpoints, Ingress, NetworkPolicy, DNS.
# Usage: k8s_network_debug.sh <namespace> [service]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

NS="${1:-}"
SVC="${2:-}"

if [[ -z "$NS" ]]; then
  ir_usage_exit "$0 <namespace> [service]"
fi

ir_header "Kubernetes Network Debug  ns=${NS}"

if ! command -v kubectl >/dev/null 2>&1; then
  ir_fail "kubectl not found"
  exit 1
fi

ir_section "Services / Endpoints / EndpointSlices"
kubectl get svc,ep,endpointslices,ingress,ingressclass,networkpolicy -n "$NS" -o wide 2>/dev/null \
  || kubectl get svc,ep,ingress -n "$NS"

if [[ -n "$SVC" ]]; then
  ir_section "Service ${SVC}"
  kubectl get svc -n "$NS" "$SVC" -o yaml 2>/dev/null | awk '
    /^(apiVersion|kind|metadata:|  name:|spec:|  type:|  selector:|  ports:|    - |  clusterIP:|status:)/ {print}
  ' | head -n 80
  echo
  echo "endpoints:"
  kubectl get endpoints -n "$NS" "$SVC" -o wide 2>/dev/null || true
  echo
  echo "pods matching selector (best-effort from labels on the Service):"
  SEL="$(kubectl get svc -n "$NS" "$SVC" -o jsonpath='{range .spec.selector}{@}{end}' 2>/dev/null || true)"
  # jsonpath for map is awkward; use go-template
  SEL="$(kubectl get svc -n "$NS" "$SVC" -o go-template='{{range $k,$v := .spec.selector}}{{$k}}={{$v}},{{end}}' 2>/dev/null | sed 's/,$//')"
  if [[ -n "$SEL" ]]; then
    echo "selector: $SEL"
    kubectl get pods -n "$NS" -l "$SEL" -o wide
    echo
    echo "ready containers:"
    kubectl get pods -n "$NS" -l "$SEL" -o jsonpath='{range .items[*]}{.metadata.name}{" ready="}{.status.containerStatuses[0].ready}{" restarts="}{.status.containerStatuses[0].restartCount}{"\n"}{end}' 2>/dev/null
  fi
fi

ir_section "CoreDNS"
kubectl get pods -n kube-system -l k8s-app=kube-dns -o wide 2>/dev/null \
  || kubectl get pods -n kube-system -l k8s-app=coredns -o wide 2>/dev/null \
  || kubectl get deploy,pods -n kube-system | grep -i dns || true
echo
echo "cluster DNS service:"
kubectl get svc -n kube-system kube-dns -o wide 2>/dev/null || kubectl get svc -n kube-system -l k8s-app=kube-dns 2>/dev/null || true

ir_section "NetworkPolicy present?"
NP="$(kubectl get networkpolicy -A --no-headers 2>/dev/null | wc -l | tr -d ' ')"
echo "cluster NetworkPolicy objects: ${NP}"
[[ "${NP}" != "0" ]] && ir_warn "policies exist — a deny-all default will look like 'DNS is broken' or 'Service has no traffic'"

ir_section "Suggested next checks"
cat <<'EOF'
  Endpoints empty          → selector vs pod labels, or no Ready pods
  Endpoints stale          → kube-proxy / dataplane; check node kube-proxy
  Ingress 502/504          → backend Service, readiness, ingress controller logs
  Cross-ns failure         → NetworkPolicy + DNS ndots
  From a debug pod:
    nslookup kubernetes.default
    wget -S -O- http://<svc>.<ns>.svc.cluster.local:<port>/ready
EOF

