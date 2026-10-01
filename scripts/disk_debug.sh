#!/bin/bash
# disk_debug.sh — capacity, inodes, IO wait, and largest files/directories.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET="${1:-/}"

ir_header "Disk Troubleshooting"
echo "scan root: ${TARGET}"

ir_section "Filesystems"
df -hT
echo
echo "inodes:"
df -ih

ir_section "Threshold evaluation"
df -P -x tmpfs -x devtmpfs | awk 'NR>1 {gsub("%","",$5); printf "%s %s %s\n",$5,$6,$1}' | while read -r pct mnt fs; do
  if   [[ "$pct" -ge "$DISK_CRIT" ]]; then ir_fail "${mnt} (${fs}) ${pct}% full"
  elif [[ "$pct" -ge "$DISK_WARN" ]]; then ir_warn "${mnt} (${fs}) ${pct}% full"
  else ir_ok   "${mnt} (${fs}) ${pct}% used"; fi
done

ir_section "Block devices & scheduler"
lsblk -o NAME,SIZE,TYPE,FSTYPE,MOUNTPOINT,ROTA,SCHED,RA 2>/dev/null || lsblk
echo
[[ -r /proc/mdstat ]] && { echo "/proc/mdstat:"; cat /proc/mdstat; }

ir_section "IO activity"
if command -v iostat >/dev/null; then
  iostat -xz 1 3
elif command -v vmstat >/dev/null; then
  echo "vmstat 1 5:"
  vmstat 1 5
else
  ir_warn "install sysstat for iostat -xz"
fi

if [[ -r /proc/diskstats ]]; then
  echo
  echo "/proc/diskstats (raw, last 8 lines):"
  tail -n 8 /proc/diskstats
fi

ir_section "Largest directories under ${TARGET} (depth 2, may take time)"
if command -v du >/dev/null; then
  du -xhd2 "${TARGET}" 2>/dev/null | sort -h | tail -n 20
fi

ir_section "Largest files under ${TARGET} (cap 5 minutes of find)"
# Avoid walking huge network mounts: -xdev
timeout 60 find "${TARGET}" -xdev -type f -printf '%s %p\n' 2>/dev/null \
  | sort -nr | head -n 15 \
  | awk '{sz=$1; $1=""; printf "%10.1f MiB  %s\n", sz/1024/1024, $0}' \
  || ir_warn "find timed out or lacked permission — rerun as root"

ir_section "Deleted-but-open files (space not reclaimed)"
if command -v lsof >/dev/null; then
  lsof +L1 2>/dev/null | head -n 20 || ir_ok "no deleted-open files visible (or lsof needs root)"
else
  ir_info "install lsof to find deleted files still held by processes"
  echo "hint: ls -l /proc/*/fd 2>/dev/null | grep deleted"
fi

ir_section "Suggested next checks"
cat <<'EOF'
  1. If df high but du low: deleted-open files or a hidden mount.
  2. If inodes 100% with space free: millions of tiny files (session stores, queues).
  3. If await/svctm high in iostat: storage latency — check EBS burst, RAID, NFS.
  4. Log explosion: journalctl --disk-usage; vacuum with journalctl --vacuum-size=500M
EOF

