#!/bin/bash
# cpu_debug.sh — CPU saturation, steal, runaway processes, and throttling.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ir_header "CPU Troubleshooting"

ir_section "Hardware / topology"
echo "model:   $(awk -F: '/model name/{print $2; exit}' /proc/cpuinfo | sed 's/^ //')"
echo "cores:   $(nproc)"
echo "sockets: $(grep 'physical id' /proc/cpuinfo 2>/dev/null | sort -u | wc -l)"
lscpu 2>/dev/null | grep -E 'Architecture|CPU\(s\)|Thread|Core|Socket|MHz|Hypervisor|Virtualization' || true

ir_section "Load & run queue"
uptime
echo "loadavg raw: $(cat /proc/loadavg)"
echo "procs: running=$(awk '{print $4}' /proc/loadavg)"
if [[ -r /proc/stat ]]; then
  echo
  echo "/proc/stat (first 3 lines):"
  head -n 3 /proc/stat
fi

ir_section "CPU time breakdown (1s sample)"
if command -v mpstat >/dev/null; then
  mpstat -P ALL 1 1
elif command -v vmstat >/dev/null; then
  echo "vmstat 1 5 (r = run queue, us/sy/id/wa/st):"
  vmstat 1 5
else
  ir_warn "install sysstat (mpstat) or use vmstat for richer samples"
  top -bn1 | head -n 12
fi

ir_section "Steal / hypervisor pressure"
if grep -q cpu /proc/stat; then
  awk '/^cpu /{tot=$2+$3+$4+$5+$6+$7+$8+$9+$10; st=$9; printf "steal ticks=%s total=%s steal%%=%.2f\n", st, tot, (tot?st*100/tot:0)}' /proc/stat
fi
# High steal on EC2 often means noisy neighbor or undersized instance.

ir_section "Top consumers"
ps -eo pid,ppid,user,ni,pri,pcpu,pmem,rss,stat,wchan:16,comm,args --sort=-pcpu | head -n 16

ir_section "Runnable / D-state / zombies"
echo "STAT legend: R=run D=uninterruptible sleep Z=zombie"
ps -eo stat,pid,user,pcpu,comm --sort=stat | awk 'NR==1 || $1 ~ /[RDZ]/' | head -n 25
DCOUNT="$(ps -eo stat= | awk '$1 ~ /^D/ {c++} END{print c+0}')"
ZCOUNT="$(ps -eo stat= | awk '$1 ~ /^Z/ {c++} END{print c+0}')"
[[ "$DCOUNT" -gt 0 ]] && ir_warn "D-state processes: ${DCOUNT} (often I/O or NFS)"
[[ "$ZCOUNT" -gt 0 ]] && ir_warn "zombie processes: ${ZCOUNT} (parent not reaping)"
[[ "$DCOUNT" -eq 0 && "$ZCOUNT" -eq 0 ]] && ir_ok "no D-state or zombie processes"

ir_section "CPU throttling / thermal (if available)"
if [[ -d /sys/devices/system/cpu/cpu0/cpufreq ]]; then
  echo "governor: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor 2>/dev/null || echo n/a)"
  echo "cur freq: $(cat /sys/devices/system/cpu/cpu0/cpufreq/scaling_cur_freq 2>/dev/null || echo n/a) kHz"
fi
command -v turbostat >/dev/null && ir_info "turbostat is available for deeper package C-state analysis"

ir_section "Suggested next checks"
cat <<'EOF'
  1. If steal% is high on EC2: check instance type, credit balance (T-family),
     and CloudWatch CPUCreditBalance / CPUSurplusCreditsCharged.
  2. If wa% (iowait) is high: run disk_debug.sh — CPU is waiting on storage.
  3. If one process dominates: capture stack with `perf top` or `pidstat -t`.
  4. If load >> cores but CPU idle: look for uninterruptible I/O or thread explosion.
EOF

