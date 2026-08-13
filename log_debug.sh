#!/bin/bash
# log_debug.sh - Extract service and application logs

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

SERVICE="${1:-nginx}"

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [service-name]"
  echo "Default: nginx"
  exit 0
fi

print_header "LOG DEBUG for $SERVICE"

print_header "Service Status"
systemctl status "$SERVICE" --no-pager || true

echo -e "\nActive: $(systemctl is-active "$SERVICE")"
echo "Restart count: $(systemctl show "$SERVICE" -p NRestarts | cut -d= -f2)"

print_header "Recent Journal Logs (last 1h, errors highlighted)"
journalctl -u "$SERVICE" --since "1 hour ago" --no-pager | tail -20

echo -e "\n${YELLOW}Error/fatal/timeout lines:${NC}"
journalctl -u "$SERVICE" --since "1 hour ago" --no-pager | grep -iE 'error|failed|fatal|exception|timeout' | tail -10 || echo "None found"

echo -e "\n${GREEN}Log debug complete.${NC}"