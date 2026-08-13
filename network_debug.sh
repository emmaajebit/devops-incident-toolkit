#!/bin/bash
# network_debug.sh - Test connectivity, DNS, routing, ports

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

TARGET="${1:-example.com}"
PORT="${2:-443}"

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [target] [port]"
  echo "Default: example.com 443"
  exit 0
fi

print_header "NETWORK DEBUG to $TARGET:$PORT"

print_header "Interfaces & IPs"
ip -br addr

print_header "Routing Table"
ip route | head -6

print_header "DNS Config"
cat /etc/resolv.conf

echo -e "\nResolving $TARGET..."
getent hosts "$TARGET" || echo "DNS resolution failed"

print_header "Ping Test (may be blocked)"
ping -c 2 "$TARGET" 2>/dev/null || echo "Ping failed or blocked"

print_header "HTTP/HTTPS Test"
curl -I --max-time 5 "https://$TARGET" 2>/dev/null || echo "HTTPS check failed"

print_header "Listening Ports"
ss -tulpn | head -10

print_header "TCP Port Test to $TARGET:$PORT"
nc -vz "$TARGET" "$PORT" 2>/dev/null || echo "Port $PORT not reachable"

echo -e "\n${GREEN}Network debug complete.${NC}"