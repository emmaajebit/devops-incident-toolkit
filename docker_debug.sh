#!/bin/bash
# docker_debug.sh - Debug Docker containers and resource usage

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 - List containers, stats, disk usage, exited containers."
  exit 0
fi

print_header "DOCKER DEBUG"

print_header "Running Containers"
docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"

print_header "All Containers (including stopped)"
docker ps -a --format "table {{.Names}}\t{{.Status}}"

print_header "Container Resource Stats"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"

print_header "Docker Disk Usage"
docker system df

print_header "Exited Containers (exit code 137 = OOM likely)"
docker ps -a --filter "status=exited" --format "{{.Names}} {{.Status}}" | grep -E '137|exited' || echo "No exited containers"

echo -e "\n${GREEN}Docker debug complete.${NC}"