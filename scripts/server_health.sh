#!/bin/bash
# server_health.sh — one-command Linux host health snapshot.
# Safe to run as a non-root user; privileged sections degrade gracefully.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ir_header "Linux Server Health Check"

ir_need_root || true

ir_section "Identity & Uptime"
echo "hostname:     ${IR_HOSTNAME}"
echo "kernel:       $(uname -srm)"
echo "os:           $(. /etc/os-release 2>/dev/null && echo "${PRETTY_NAME:-unknown}" || echo unknown)"
echo "uptime:       $(uptime -p 2>/dev/null || uptime)"
echo "boot:         $(who -b 2>/dev/null | awk '{print $3,$4}' || true)"
echo "users:        $(who | wc -l) logged in"
command -v timedatectl >/dev/null && timedatectl status 2>/dev/null | sed -n '1,6p' || date

ir_section "CPU & Load"
CORES="$(nproc 2>/dev/null || grep -c ^processor /proc/cpuinfo || echo 1)"
LOAD="$(awk '{print $1,$2,$3}' /proc/loadavg)"
L1="$(awk '{print $1}' /proc/loadavg)"
echo "cores:        ${CORES}"
echo "loadavg:      ${LOAD}  (1/5/15)"
awk -v l="$L1" -v c="$CORES" -v w="$LOAD_PER_CORE_WARN" -v crit="$LOAD_PER_CORE_CRIT" 'BEGIN{
  r=l/c;
  if (r>=crit) exit 2;
  if (r>=w) exit 1;
  exit 0
}'
case $? in
  0) ir_ok   "load per core $(awk -v l="$L1" -v c="$CORES" 'BEGIN{printf "%.2f", l/c}')" ;;
  1) ir_warn "load per core elevated" ;;
  2) ir_fail "load per core critical" ;;
esac

if command -v top >/dev/null; then
  echo
  echo "top CPU processes:"
  ps -eo pid,user,pcpu,pmem,comm --sort=-pcpu | head -n 8
fi

ir_section "Memory"
if command -v free >/dev/null; then
  free -h
  USED_PCT="$(free | awk '/Mem:/{printf "%.0f", $3/$2*100}')"
  if   [[ "$USED_PCT" -ge "$MEM_CRIT" ]]; then ir_fail "memory ${USED_PCT}% used"
  elif [[ "$USED_PCT" -ge "$MEM_WARN" ]]; then ir_warn "memory ${USED_PCT}% used"
  else ir_ok "memory ${USED_PCT}% used"; fi
fi
[[ -r /proc/meminfo ]] && awk '/MemAvailable|SwapTotal|SwapFree|Dirty|Writeback/{printf "  %-16s %s\n",$1,$2}' /proc/meminfo

ir_section "Disk"
df -hT -x tmpfs -x devtmpfs -x squashfs 2>/dev/null || df -h
echo
df -P -x tmpfs -x devtmpfs 2>/dev/null | awk 'NR>1 {gsub("%","",$5); print $5,$6}' | while read -r pct mnt; do
  if   [[ "$pct" -ge "$DISK_CRIT" ]]; then ir_fail "disk ${mnt} ${pct}%"
  elif [[ "$pct" -ge "$DISK_WARN" ]]; then ir_warn "disk ${mnt} ${pct}%"
  else ir_ok "disk ${mnt} ${pct}%"; fi
done
echo
echo "inodes:"
df -i -x tmpfs -x devtmpfs 2>/dev/null | head -n 12 || true

ir_section "Network (brief)"
ip -br addr 2>/dev/null || ifconfig -a 2>/dev/null | head -n 40
echo
echo "listening sockets (top 20):"
if command -v ss >/dev/null; then
  ss -lntup 2>/dev/null | head -n 21 || ss -lnt | head -n 21
else
  netstat -lntup 2>/dev/null | head -n 21 || true
fi

ir_section "Failed / degraded systemd units"
if command -v systemctl >/dev/null; then
  FAILED="$(systemctl --failed --no-pager --no-legend 2>/dev/null || true)"
  if [[ -z "$FAILED" ]]; then
    ir_ok "no failed units"
  else
    ir_fail "failed units present"
    echo "$FAILED"
  fi
  echo
  echo "recent journal errors (last 20):"
  journalctl -p err -n 20 --no-pager 2>/dev/null || true
else
  ir_info "systemd not available"
fi

ir_section "Security snapshot"
echo "open files:   $(awk '{print $1}' /proc/sys/fs/file-nr 2>/dev/null) / $(awk '{print $3}' /proc/sys/fs/file-nr 2>/dev/null)"
id
[[ -f /etc/ssh/sshd_config ]] && grep -E '^(PermitRootLogin|PasswordAuthentication|Port)\s' /etc/ssh/sshd_config 2>/dev/null || true
if command -v lastb >/dev/null && [[ -r /var/log/btmp ]]; then
  echo "recent failed logins:"
  lastb -n 5 2>/dev/null || true
fi

ir_section "Next steps"
cat <<'EOF'
  • High CPU     → ./scripts/cpu_debug.sh
  • High memory  → ./scripts/memory_debug.sh
  • Disk full    → ./scripts/disk_debug.sh
  • Connectivity → ./scripts/network_debug.sh
  • App errors   → ./scripts/log_debug.sh [unit|path]
  • Containers   → ./scripts/docker_debug.sh
  • Kubernetes   → ./scripts/k8s_debug.sh
  • AWS EC2      → ./scripts/ec2_debug.sh <instance-id> <region>
EOF

echo
ir_ok "health check complete"

