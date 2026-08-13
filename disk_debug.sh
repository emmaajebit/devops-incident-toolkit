#!/bin/bash
# disk_debug.sh - Locate what's filling the disk or inode exhaustion

set -euo pipefail

GREEN='\033[0;32m'; YELLOW='\033[1;33m'; RED='\033[0;31m'; NC='\033[0m'
print_header() { echo -e "\n${GREEN}=== $1 ===${NC}"; }

if [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 - Check disk space, inodes, large files, deleted-but-open files."
  exit 0
fi

print_header "DISK DEBUG"

print_header "Filesystem Usage"
df -hT

print_header "Inode Usage (watch for 100%!)"
df -ih

print_header "Largest Directories (/var)"
du -xh /var --max-depth=2 2>/dev/null | sort -rh | head -8

print_header "Files > 100MB"
find / -type f -size +100M 2>/dev/null | head -10 || echo "Search may take time..."

print_header "Deleted but Open Files (lsof +L1)"
lsof +L1 2>/dev/null | head -10 || echo "lsof not available or no deleted files"

echo -e "\n${GREEN}Disk debug complete.${NC}"