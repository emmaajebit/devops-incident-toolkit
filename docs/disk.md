# Disk troubleshooting

Script: `scripts/disk_debug.sh [path]`

## Two different full conditions

1. **Blocks** (`df -h`) — logs, container layers, databases, leftover images.
2. **Inodes** (`df -i`) — millions of small files (sessions, queued emails, npm caches).

A filesystem can be “100% inodes, 20% blocks.” `df -h` alone will lie to you.

## Classic traps

- `df` high, `du` low → a process holds a deleted file (`lsof +L1`) or a bind mount hides a tree.
- Overlay2 growth under Docker → `docker system df` then log rotation of the json-file driver.
- EBS `gp2` burst credits exhausted → `iostat` `await` in hundreds of ms while `%util` is 100%.
- NFS `D` state army → the remote export is the real incident.

## Safe cleanup patterns

```bash
journalctl --disk-usage
journalctl --vacuum-size=500M

# Docker, only after you understand what you are deleting
docker system df
# docker system prune   # destructive; not run by the toolkit
```

Never `rm` files under `/var/lib/docker` or `/var/lib/kubelet` by hand.
