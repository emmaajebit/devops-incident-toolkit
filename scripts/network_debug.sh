#!/bin/bash
# network_debug.sh — interfaces, routes, DNS, sockets, packet drops.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

TARGET_HOST="${1:-}"

ir_header "Network Diagnostics"

ir_section "Interfaces"
ip -br addr 2>/dev/null || ip addr
echo
ip -s link 2>/dev/null | sed -n '1,80p'

ir_section "Routes"
ip route
echo
echo "rules:"
ip rule 2>/dev/null || true

ir_section "Neighbor / ARP"
ip neigh 2>/dev/null | head -n 20 || arp -an 2>/dev/null | head -n 20

ir_section "DNS"
echo "resolv.conf:"
grep -v '^#' /etc/resolv.conf 2>/dev/null | sed '/^$/d'
if command -v resolvectl >/dev/null; then
  echo
  resolvectl status 2>/dev/null | sed -n '1,40p'
fi
echo
for name in kubernetes.default.svc.cluster.local google.com cloudflare.com; do
  if command -v getent >/dev/null; then
    echo -n "getent ${name}: "
    getent ahosts "$name" 2>/dev/null | head -n 1 || echo "(failed)"
  fi
done

ir_section "Listening sockets"
if command -v ss >/dev/null; then
  ss -lntup 2>/dev/null || ss -lnt
  echo
  echo "socket summary:"
  ss -s 2>/dev/null || true
else
  netstat -lntup 2>/dev/null || netstat -lnt
fi

ir_section "Conntrack / firewall hints"
[[ -r /proc/sys/net/netfilter/nf_conntrack_count ]] && \
  echo "conntrack: $(cat /proc/sys/net/netfilter/nf_conntrack_count) / $(cat /proc/sys/net/netfilter/nf_conntrack_max)"
command -v iptables >/dev/null && echo "iptables filter policy:" && iptables -S 2>/dev/null | head -n 15 || true
command -v nft >/dev/null && nft list ruleset 2>/dev/null | head -n 20 || true

ir_section "Link errors (RX/TX drop, error, overrun)"
if [[ -r /proc/net/dev ]]; then
  awk 'NR>2 {gsub(":","",$1); printf "%-12s rx_bytes=%s rx_errs=%s rx_drop=%s tx_errs=%s tx_drop=%s\n",$1,$2,$4,$5,$12,$13}' /proc/net/dev
fi

if [[ -n "$TARGET_HOST" ]]; then
  ir_section "Reachability to ${TARGET_HOST}"
  ping -c 4 -W 2 "$TARGET_HOST" 2>/dev/null || ir_fail "ping failed"
  command -v traceroute >/dev/null && traceroute -n -w 2 -m 15 "$TARGET_HOST" 2>/dev/null | head -n 20
  command -v curl >/dev/null && curl -sS -o /dev/null -w "curl http://%{url_effective} code=%{http_code} time=%{time_total}s\n" --max-time 5 "http://${TARGET_HOST}/" || true
fi

ir_section "Suggested next checks"
cat <<'EOF'
  1. SYN backlog / TIME_WAIT explosion: ss -s and net.ipv4.tcp_max_syn_backlog.
  2. Intermittent DNS: check systemd-resolved stub vs upstream; try dig @8.8.8.8.
  3. Packet drops on virtio/ena: instance network credits, security groups, NACLs.
  4. Pass a host to this script for ping/traceroute: ./network_debug.sh 1.1.1.1
EOF

