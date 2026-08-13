#!/bin/bash
# server_health.sh - General first-aid for any Linux server
# Use when: "Server is slow", "App behaving strangely", "Something wrong with EC2"

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }
print_ok() { echo -e "${GREEN}✓${NC} $1"; }
print_warn() { echo -e "${YELLOW}!${NC} $1"; }
print_crit() { echo -e "${RED}✗${NC} $1"; }

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0"
  echo "Collects hostname, uptime, CPU, memory, disk, network, failed services, and system errors."
  exit 0
fi

print_header "SERVER HEALTH CHECK"

echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p 2>/dev/null || uptime)"

echo -e "\nLoad Average: $(uptime | awk -F'load average:' '{print $2}')"
CPU_CORES=$(nproc)
echo "CPU Cores: $CPU_CORES"

print_header "MEMORY"
free -h

print_header "DISK"
df -hT

echo -e "\nInodes:"
df -i | head -5

print_header "TOP CPU PROCESSES"
ps aux --sort=-%cpu | head -6

print_header "TOP MEMORY PROCESSES"
ps aux --sort=-%mem | head -6

print_header "FAILED SERVICES"
if systemctl --failed --no-legend | grep -q .; then
  systemctl --failed --no-legend
else
  print_ok "No failed services"
fi

print_header "RECENT SYSTEM ERRORS"
journalctl -p 3 -xb --no-pager | tail -10 || echo "journalctl not available"

echo -e "\n${GREEN}Health check complete.${NC}"