#!/bin/bash
# prometheus_debug.sh — Prometheus / Alertmanager / kube-prometheus-stack health
# plus PromQL probes against a live API.
#
# Usage:
#   prometheus_debug.sh                         # in-cluster discovery via kubectl
#   prometheus_debug.sh http://localhost:9090   # direct base URL
#   PROM_URL=... PROM_TOKEN=... prometheus_debug.sh
#
# Optional env:
#   PROM_URL          Base URL (no trailing slash)
#   PROM_TOKEN        Bearer token
#   PROM_NS           Namespace hint for kubectl discovery (default: monitoring)
#   PROM_QUERY        Extra PromQL to run
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

PROM_URL="${1:-${PROM_URL:-}}"
PROM_NS="${PROM_NS:-monitoring}"
CURL=(curl -fsS --max-time 8)
if [[ -n "${PROM_TOKEN:-}" ]]; then
  CURL+=(-H "Authorization: Bearer ${PROM_TOKEN}")
fi

ir_header "Prometheus / Alerting Diagnostics"

prom_get() {
  local path="$1"
  "${CURL[@]}" "${PROM_URL}${path}"
}

discover_via_kubectl() {
  command -v kubectl >/dev/null 2>&1 || return 1
  ir_section "In-cluster discovery (ns=${PROM_NS} + common names)"
  for ns in "$PROM_NS" monitoring observability kube-prometheus kube-system default; do
    kubectl get svc,pods,prometheus,alertmanager -n "$ns" 2>/dev/null | head -n 20 && echo "(namespace $ns)" && break
  done
  echo
  echo "ServiceMonitors / PodMonitors / Probes (if CRDs exist):"
  kubectl get servicemonitor,podmonitor,probe,prometheusrule -A 2>/dev/null | head -n 40 || ir_info "monitoring.coreos.com CRDs not installed or not permitted"
  echo
  echo "kube-prometheus-stack / operator pods:"
  kubectl get pods -A --no-headers 2>/dev/null | grep -iE 'prometheus|alertmanager|grafana|node-exporter|kube-state|blackbox|operator' | head -n 40
}

if [[ -z "$PROM_URL" ]]; then
  ir_info "no PROM_URL; attempting kubectl discovery only"
  discover_via_kubectl || ir_warn "kubectl unavailable — pass a Prometheus URL"
else
  PROM_URL="${PROM_URL%/}"
  ir_section "API ${PROM_URL}"
  if ! prom_get "/-/healthy" >/dev/null; then
    ir_fail "Prometheus /-/healthy failed"
  else
    ir_ok "Prometheus healthy"
  fi
  if prom_get "/-/ready" >/dev/null; then
    ir_ok "Prometheus ready"
  else
    ir_fail "Prometheus not ready (compaction / WAL replay / crash loop)"
  fi

  ir_section "Build / flags (sanitized)"
  prom_get "/api/v1/status/buildinfo" 2>/dev/null || true
  echo
  prom_get "/api/v1/status/runtimeinfo" 2>/dev/null || true

  ir_section "TSDB / WAL pressure"
  prom_get "/api/v1/status/tsdb" 2>/dev/null | head -c 4000; echo

  ir_section "Targets (unhealthy first)"
  if command -v python3 >/dev/null; then
    prom_get "/api/v1/targets" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception as e:
    print("parse error", e); sys.exit(0)
act=d.get("data",{}).get("activeTargets",[])
bad=[t for t in act if t.get("health")!="up"]
print("active=%d unhealthy=%d"%(len(act),len(bad)))
for t in bad[:25]:
    lbl=t.get("labels",{})
    print("DOWN job=%s instance=%s scrape=%s lastError=%s"%(
        lbl.get("job","?"), lbl.get("instance","?"),
        t.get("lastScrape",""), (t.get("lastError") or "")[:160]))
'
  else
    prom_get "/api/v1/targets" 2>/dev/null | head -c 2000; echo
  fi

  ir_section "Alertmanager discovery via Prometheus"
  prom_get "/api/v1/alertmanagers" 2>/dev/null | head -c 2000; echo

  query() {
    local q="$1"
    echo "${C_DIM}PromQL: ${q}${C_RST}"
    local enc
    enc="$(python3 -c 'import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1]))' "$q" 2>/dev/null || echo "$q")"
    prom_get "/api/v1/query?query=${enc}" 2>/dev/null | python3 -c '
import json,sys
try:
    d=json.load(sys.stdin)
except Exception as e:
    print("  query failed", e); sys.exit(0)
print("  status=", d.get("status"), "type=", d.get("data",{}).get("resultType"))
for r in d.get("data",{}).get("result",[])[:8]:
    m=r.get("metric",{})
    v=r.get("value",["",""])
    keys=" ".join("%s=%s"%item for item in list(m.items())[:6] if item[0]!="__name__")
    print("  ", v[-1], keys)
' || true
    echo
  }

  ir_section "Built-in PromQL probes"
  query 'up'
  query 'count(up==0)'
  query 'prometheus_tsdb_head_series'
  query 'prometheus_tsdb_wal_corruptions_total'
  query 'prometheus_rule_evaluation_failures_total'
  query 'prometheus_notifications_dropped_total'
  query 'ALERTS{alertstate="firing"}'
  query 'kube_pod_container_status_restarts_total'
  query 'sum(rate(container_cpu_cfs_throttled_seconds_total[5m])) by (namespace,pod)'
  if [[ -n "${PROM_QUERY:-}" ]]; then
    query "$PROM_QUERY"
  fi
fi

ir_section "Alertmanager (best-effort same host :9093)"
AM_URL="${AM_URL:-}"
if [[ -z "$AM_URL" && -n "${PROM_URL:-}" ]]; then
  AM_URL="$(echo "$PROM_URL" | sed -E 's/:[0-9]+$/:9093/')"
fi
if [[ -n "$AM_URL" ]]; then
  echo "trying ${AM_URL}/-/healthy"
  curl -fsS --max-time 5 "${AM_URL}/-/healthy" >/dev/null 2>&1 && ir_ok "Alertmanager healthy" || ir_info "Alertmanager not on guessed URL (set AM_URL)"
fi

ir_section "Suggested next checks"
cat <<'EOF'
  Many targets DOWN     → ServiceMonitor selector, NetworkPolicy, scrape timeout,
                          kubelet auth, wrong honorLabels
  Head series exploding → high-cardinality labels (user_id, pod UID, raw path)
  Rules failing         → /rules API, look for "too many samples" or syntax
  Alerts fire, no page  → Alertmanager routes, inhibit, silenced, wrong receiver
  Query timeouts        → recording rules, longer range, or compacting TSDB

  Query library: scripts/promql/k8s.promql
  Runbook:       docs/prometheus.md
EOF

