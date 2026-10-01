# Safety and assumptions

## Read-mostly

Every script in `scripts/` is intended to be **observational**. They:

- Do not restart units, pods, or instances
- Do not prune Docker or vacuum journals automatically
- Do not write to `/etc`
- Do not use `aws ec2 stop-instances` or `kubectl delete`

If you wrap them in cron, redirect stdout; do not pipe them into `sh`.

## Secrets

- `ec2_debug.sh` prints security group CIDRs. That is usually acceptable in an incident channel; it is not acceptable in a public gist if the groups are tightly scoped to office IPs.
- Kubernetes scripts list object names (including Secret names), never values.
- `prometheus_debug.sh` only GETs HTTP APIs and `kubectl get`. It does not silence alerts or delete series.
- Never commit kubeconfigs, `.env`, or AWS keys. See `.gitignore`.

## Reliability of output

Commands are wrapped so a missing binary does not abort the whole run (`set -u` is on; `set -e` is not, by design). A `[WARN] missing command` line means that section is incomplete, not that the host is healthy.

## Tested shapes

Written against Bash 4+ on systemd Linux. BusyBox `ps`/`df` flags differ; do not expect full output on distroless or Alpine *inside* a container unless you exec onto a debug image.

