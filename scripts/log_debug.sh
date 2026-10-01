#!/bin/bash
# log_debug.sh — service journal + common log file triage.
# Usage: log_debug.sh [unit-or-path] [lines]
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET="${1:-}"
LINES="${2:-100}"

ir_header "Log Analysis"

ir_section "Journal disk usage"
if command -v journalctl >/dev/null; then
  journalctl --disk-usage 2>/dev/null || true
  echo
  echo "boot list (last 5):"
  journalctl --list-boots 2>/dev/null | tail -n 5 || true
else
  ir_warn "journalctl not available"
fi

ir_section "System errors (priority err+, last ${LINES})"
if command -v journalctl >/dev/null; then
  journalctl -p err -n "$LINES" --no-pager 2>/dev/null || true
fi

if [[ -n "$TARGET" ]]; then
  if [[ -e "$TARGET" ]]; then
    ir_section "Tail of file ${TARGET}"
    tail -n "$LINES" "$TARGET"
    echo
    echo "error-like lines:"
    grep -iE 'error|exception|fatal|panic|oom|denied|timeout' "$TARGET" | tail -n 40 || true
  elif command -v systemctl >/dev/null && systemctl list-units --all --no-legend 2>/dev/null | awk '{print $1}' | grep -qx "${TARGET}.service\|${TARGET}"; then
    ir_section "journal for unit ${TARGET}"
    journalctl -u "$TARGET" -n "$LINES" --no-pager 2>/dev/null
    echo
    systemctl status "$TARGET" --no-pager -l 2>/dev/null | head -n 30 || true
  else
    ir_section "journal grep: ${TARGET}"
    journalctl -g "$TARGET" -n "$LINES" --no-pager 2>/dev/null || true
  fi
fi

ir_section "Common application log paths (existence only)"
for p in \
  /var/log/syslog /var/log/messages /var/log/auth.log \
  /var/log/nginx/error.log /var/log/httpd/error_log /var/log/apache2/error.log \
  /var/log/mysql/error.log /var/log/postgresql/ /var/log/containers/ \
  /var/log/pods/; do
  if [[ -e "$p" ]]; then
    ir_ok "$p"
  fi
done

ir_section "Auth / sudo (last 15 interesting lines)"
for f in /var/log/auth.log /var/log/secure; do
  if [[ -r "$f" ]]; then
    grep -iE 'Failed|Invalid|Accepted|sudo' "$f" | tail -n 15
    break
  fi
done
journalctl -u sshd -n 15 --no-pager 2>/dev/null || true

ir_section "Suggested next checks"
cat <<'EOF'
  Usage examples:
    ./scripts/log_debug.sh
    ./scripts/log_debug.sh nginx
    ./scripts/log_debug.sh /var/log/nginx/error.log 200

  Persistent noise: raise rate limits only after you understand the cause.
  Correlation: match timestamps with cpu_debug / network_debug around the same window.
EOF

