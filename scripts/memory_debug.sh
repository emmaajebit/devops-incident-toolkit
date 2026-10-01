#!/bin/bash
# memory_debug.sh — RSS/VSZ, cache, swap, OOM, and cgroup pressure.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

ir_header "Memory Troubleshooting"

ir_section "Overview"
free -h
echo
[[ -r /proc/meminfo ]] && cat /proc/meminfo | awk '
  /MemTotal|MemFree|MemAvailable|Buffers|Cached|SwapTotal|SwapFree|Dirty|Writeback|AnonPages|Mapped|Shmem|SReclaimable|CommitLimit|Committed_AS/ {
    printf "%-18s %10s kB\n", $1, $2
  }'

ir_section "Pressure / PSI (Linux 4.20+)"
if [[ -r /proc/pressure/memory ]]; then
  cat /proc/pressure/memory
else
  ir_info "PSI not available on this kernel"
fi

ir_section "Top RSS consumers"
ps -eo pid,user,pmem,rss,vsz,comm,args --sort=-rss | head -n 16
echo
echo "top VSZ (virtual — watch for leaks that have not faulted in):"
ps -eo pid,user,vsz,rss,comm --sort=-vsz | head -n 8

ir_section "Slab / kernel caches"
if [[ -r /proc/slabinfo ]]; then
  echo "largest slabs:"
  awk 'NR>2 {print $3*$4, $1}' /proc/slabinfo 2>/dev/null | sort -nr | head -n 8 | awk '{printf "  %-32s %s pages-ish\n",$2,$1}'
fi
command -v slabtop >/dev/null && ir_info "run: slabtop -o | head"

ir_section "Swap activity"
swapon --show 2>/dev/null || true
if command -v vmstat >/dev/null; then
  echo "vmstat 1 5 (si/so = swap in/out):"
  vmstat 1 5
fi

ir_section "OOM history"
echo "dmesg / journal OOM killer events:"
(dmesg -T 2>/dev/null || journalctl -k --no-pager) | grep -i -E 'out of memory|oom-kill|killed process' | tail -n 20 || ir_ok "no recent OOM lines in current buffer"

if [[ -r /var/log/kern.log ]]; then
  grep -i oom /var/log/kern.log | tail -n 10 || true
fi

ir_section "cgroup memory (v1/v2)"
if [[ -f /sys/fs/cgroup/cgroup.controllers ]]; then
  ir_info "cgroup v2"
  head -n 20 /sys/fs/cgroup/memory.current 2>/dev/null || true
  [[ -r /sys/fs/cgroup/memory.stat ]] && head -n 15 /sys/fs/cgroup/memory.stat
elif [[ -d /sys/fs/cgroup/memory ]]; then
  ir_info "cgroup v1"
  echo "usage: $(cat /sys/fs/cgroup/memory/memory.usage_in_bytes 2>/dev/null)"
fi

ir_section "Suggested next checks"
cat <<'EOF'
  1. MemAvailable low + cache high is often healthy (cache will shrink).
  2. Committed_AS >> CommitLimit with overcommit=0 will cause allocation failures.
  3. Repeated OOM: capture /proc/<pid>/smaps_rollup before the next crash.
  4. Containerized? Check docker stats / kubectl top and cgroup limits — the
     host may look fine while a pod is hitting its own memory.max.
EOF

