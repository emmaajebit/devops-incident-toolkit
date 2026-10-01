#!/bin/bash
# collect_evidence.sh — run a safe snapshot bundle into evidence/<utc>/ and tar it.
# Usage: collect_evidence.sh [out-dir]
# Env: IR_NS  IR_POD  IR_SVC  IR_CONTAINER  PROM_URL  EC2_INSTANCE_ID  AWS_DEFAULT_REGION
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
OUT="${1:-${ROOT_DIR}/evidence/${STAMP}}"
mkdir -p "$OUT"

ir_header "Evidence pack → ${OUT}"
echo "host=${IR_HOSTNAME} utc=${IR_TIMESTAMP}" | tee "${OUT}/meta.txt"
{
  echo "user=$(id 2>/dev/null)"
  echo "pwd=$(pwd)"
  echo "IR_NS=${IR_NS:-}"
  echo "IR_POD=${IR_POD:-}"
  echo "IR_SVC=${IR_SVC:-}"
  echo "IR_CONTAINER=${IR_CONTAINER:-}"
  echo "PROM_URL=${PROM_URL:-}"
  echo "EC2_INSTANCE_ID=${EC2_INSTANCE_ID:-}"
} >> "${OUT}/meta.txt"

run_cap() {
  local file="$1"; shift
  echo "${C_DIM}>> $* → ${file}${C_RST}"
  timeout 45 bash "$@" > "${OUT}/${file}" 2>&1 || echo "exit:$?" >> "${OUT}/${file}"
}

run_cap host_health.txt     "${SCRIPT_DIR}/server_health.sh"
run_cap cpu.txt             "${SCRIPT_DIR}/cpu_debug.sh"
run_cap memory.txt          "${SCRIPT_DIR}/memory_debug.sh"
run_cap disk.txt            "${SCRIPT_DIR}/disk_debug.sh" /tmp
run_cap network.txt         "${SCRIPT_DIR}/network_debug.sh"
run_cap logs.txt            "${SCRIPT_DIR}/log_debug.sh" 80

if command -v docker >/dev/null 2>&1; then
  run_cap docker.txt "${SCRIPT_DIR}/docker_debug.sh" ${IR_CONTAINER:-}
fi
if command -v kubectl >/dev/null 2>&1; then
  run_cap k8s.txt "${SCRIPT_DIR}/k8s_debug.sh" ${IR_NS:-} ${IR_POD:-}
  if [[ -n "${IR_NS:-}" ]]; then
    run_cap k8s_workload.txt "${SCRIPT_DIR}/k8s_workload_debug.sh" "$IR_NS" ${IR_POD:-}
    if [[ -n "${IR_SVC:-}" ]]; then
      run_cap k8s_network.txt "${SCRIPT_DIR}/k8s_network_debug.sh" "$IR_NS" "$IR_SVC"
    fi
  fi
fi
if [[ -n "${PROM_URL:-}" ]]; then
  run_cap prometheus.txt "${SCRIPT_DIR}/prometheus_debug.sh" "$PROM_URL"
fi
if [[ -n "${EC2_INSTANCE_ID:-}" ]]; then
  run_cap ec2.txt "${SCRIPT_DIR}/ec2_debug.sh" "$EC2_INSTANCE_ID" ${AWS_DEFAULT_REGION:-}
fi

TAR="${OUT}.tar.gz"
if tar -C "$(dirname "$OUT")" -czf "$TAR" "$(basename "$OUT")" 2>/dev/null; then
  ir_ok "wrote ${TAR}"
  ls -lh "$TAR"
else
  ir_warn "tar failed; leave the directory in place: ${OUT}"
fi

echo
echo "Attach ${TAR} (or the folder) when you escalate."
echo "Redact security-group CIDRs / hostnames if the channel is public."
