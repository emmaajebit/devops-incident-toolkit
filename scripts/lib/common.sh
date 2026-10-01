#!/bin/bash
# Shared helpers for the DevOps Incident Response Toolkit.
# Source this file; do not execute it directly.

set -o pipefail

IR_TOOLKIT_VERSION="1.0.0"
IR_TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
IR_HOSTNAME="$(hostname -f 2>/dev/null || hostname)"

# Colors (disabled when not a TTY or NO_COLOR is set)
if [[ -t 1 && -z "${NO_COLOR:-}" ]]; then
  C_RED=$'\033[31m'; C_GRN=$'\033[32m'; C_YEL=$'\033[33m'
  C_BLU=$'\033[34m'; C_CYN=$'\033[36m'; C_BOLD=$'\033[1m'
  C_DIM=$'\033[2m'; C_RST=$'\033[0m'
else
  C_RED=""; C_GRN=""; C_YEL=""; C_BLU=""; C_CYN=""; C_BOLD=""; C_DIM=""; C_RST=""
fi

ir_header() {
  local title="${1:-Incident Response}"
  echo
  echo "${C_BOLD}${C_CYN}════════════════════════════════════════════════════════════${C_RST}"
  echo "${C_BOLD}${C_CYN}  ${title}${C_RST}"
  echo "${C_DIM}  host=${IR_HOSTNAME}  utc=${IR_TIMESTAMP}  toolkit=${IR_TOOLKIT_VERSION}${C_RST}"
  echo "${C_BOLD}${C_CYN}════════════════════════════════════════════════════════════${C_RST}"
}

ir_section() {
  echo
  echo "${C_BOLD}${C_BLU}── ${1} ──${C_RST}"
}

ir_ok()   { echo "${C_GRN}[OK]${C_RST}    $*"; }
ir_warn() { echo "${C_YEL}[WARN]${C_RST}  $*"; }
ir_fail() { echo "${C_RED}[FAIL]${C_RST}  $*"; }
ir_info() { echo "${C_DIM}[INFO]${C_RST}  $*"; }

ir_need_cmd() {
  local missing=0
  local c
  for c in "$@"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      ir_warn "missing command: $c"
      missing=1
    fi
  done
  return "$missing"
}

ir_need_root() {
  if [[ "${EUID}" -ne 0 ]]; then
    ir_warn "not running as root; some checks will be limited"
    return 1
  fi
  return 0
}

ir_hr() {
  echo "${C_DIM}────────────────────────────────────────────────────────────${C_RST}"
}

ir_run() {
  # Run a command, print it, and never abort the parent script.
  local desc="$1"; shift
  echo "${C_DIM}\$ $*${C_RST}"
  if "$@"; then
    return 0
  else
    ir_warn "${desc} exited $?"
    return 0
  fi
}

ir_usage_exit() {
  echo "Usage: $*" >&2
  exit 2
}

# Thresholds (override via environment)
CPU_WARN="${CPU_WARN:-80}"
CPU_CRIT="${CPU_CRIT:-95}"
MEM_WARN="${MEM_WARN:-80}"
MEM_CRIT="${MEM_CRIT:-95}"
DISK_WARN="${DISK_WARN:-80}"
DISK_CRIT="${DISK_CRIT:-90}"
LOAD_PER_CORE_WARN="${LOAD_PER_CORE_WARN:-1.0}"
LOAD_PER_CORE_CRIT="${LOAD_PER_CORE_CRIT:-2.0}"

