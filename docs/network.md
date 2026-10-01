# Network troubleshooting

Script: `scripts/network_debug.sh [target-host]`

## Layered checklist

1. **Link** — `ip link` state UP, no flood of RX/TX errors or drops.
2. **Address** — expected IPv4/IPv6 on the interface, not a stale DHCP lease.
3. **Route** — default route exists; policy rules (`ip rule`) have not blackholed a table.
4. **DNS** — `/etc/resolv.conf` and `getent`. Kubernetes pods often fail here first (`ndots:5`).
5. **Listen** — `ss -lntup` shows the application port on the address you think it does.
6. **Policy** — security groups, NACLs, `iptables`/`nft`, NetworkPolicies. The guest can be perfect and still black-holed.

## Conntrack

`nf_conntrack_count` approaching `nf_conntrack_max` produces random new-connection failure that looks like “the app is flaky.” NAT-heavy nodes (kube-proxy iptables mode, Docker masquerade) hit this.

## When to involve the cloud path

If `ec2_debug.sh` status checks pass and the guest `ping` of an external IP works, the problem is above L3 on the box (process, listen address, TLS). If *system* reachability failed, stop debugging userspace — that is the AWS data plane or the hypervisor.
