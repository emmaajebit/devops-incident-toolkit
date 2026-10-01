# Linux host runbook

Use this when the unit of failure is a VM or bare-metal box.

## First 60 seconds

```bash
./scripts/server_health.sh
```

Read, in this order:

1. Failed systemd units
2. Disk and inode percentages
3. Memory used vs MemAvailable
4. Load per core
5. Listening sockets — is the app even bound?

## Distro notes

- Debian/Ubuntu: `journalctl`, `apt`, `/var/log/auth.log`
- RHEL/Alma/Rocky: `journalctl`, `dnf`, `/var/log/secure`
- Amazon Linux: mix of the above; CloudWatch agent may own `/opt/aws`

Scripts call `systemctl` and `journalctl` when present and otherwise skip.

## Privilege

Run as root when you can (SSM `AmazonSSMRole` sessions often already are). Without root you still get load, memory, `df`, and process lists. You lose `lastb`, some `lsof`, `dmesg` on locked-down kernels, and firewall dumps.

## What “healthy” looks like

- Load per core well under 1.0
- MemAvailable not in the low single-digit percent of MemTotal
- Disks under the warning threshold on both space and inodes
- Zero failed units
- The application port is `LISTEN`

Healthy is not “idle.” A busy, correctly sized box can sit at 60–70% CPU indefinitely.

## Related docs

[CPU](cpu.md) · [Memory](memory.md) · [Disk](disk.md) · [Network](network.md) · [Logs](logs.md) · [Safety](safety.md)
