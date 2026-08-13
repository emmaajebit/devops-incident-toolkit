#!/bin/bash
# memory_debug.sh - Find memory pressure and OOM kills

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }
print_crit() { echo -e "${RED}✗${NC} $1"; }

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 - Check RAM, swap, OOM killer logs, top memory processes."
  exit 0
fi

print_header "MEMORY DEBUG"

print_header "Memory Overview"
free -h

echo -e "\nSwap:"
swapon --show 2>/dev/null || echo "No swap configured"

print_header "Detailed /proc/meminfo (key lines)"
grep -E 'MemTotal|MemFree|MemAvailable|Cached|SwapTotal|SwapFree|Dirty' /proc/meminfo

print_header "TOP MEMORY PROCESSES"
ps aux --sort=-%mem | head -6

print_header "OOM KILLER LOGS"
if journalctl -k | grep -iE 'out of memory|oom|killed process' | tail -5 | grep -q .; then
  journalctl -k | grep -iE 'out of memory|oom|killed process' | tail -5
else
  echo "No recent OOM events found"
fi

echo -e "\n${GREEN}Memory debug complete.${NC}"