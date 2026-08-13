#!/bin/bash
# cpu_debug.sh - Investigate high CPU usage

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 - Diagnose high CPU. Shows architecture, load, top processes, vmstat."
  exit 0
fi

print_header "CPU DEBUG"

echo "CPU Info:"
lscpu | grep -E 'CPU\(s\)|Core|Thread'

echo -e "\nLoad: $(uptime | awk -F'load average:' '{print $2}')"
echo "Cores: $(nproc)"

print_header "TOP CPU PROCESSES"
ps aux --sort=-%cpu | head -8

print_header "VMSTAT (5 snapshots)"
vmstat 1 5

print_header "INTERRUPTS & CONTEXT SWITCHES"
vmstat -s | grep -E 'interrupts|context switches' | head -4

echo -e "\n${GREEN}CPU debug complete.${NC}"