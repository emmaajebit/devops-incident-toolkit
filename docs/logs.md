# Log analysis

Script: `scripts/log_debug.sh [unit-or-path] [lines]`

## Usage

```bash
./scripts/log_debug.sh
./scripts/log_debug.sh nginx
./scripts/log_debug.sh nginx.service 200
./scripts/log_debug.sh /var/log/nginx/error.log 200
```

If the argument is a file that exists, the script tails it. If it looks like a systemd unit, it uses `journalctl -u`. Otherwise it uses `journalctl -g` as a grep.

## Correlation

Pick the first error timestamp and look at the *same minute* in `cpu_debug.sh` / `memory_debug.sh` output or CloudWatch. Isolated “error” lines without a matching resource spike are often retry noise.

## Journal hygiene

`journalctl --disk-usage` is in the script because journals have filled root filesystems in real incidents. Vacuuming is a mitigation, not a root-cause fix — find the unit that is logging at tens of MB/s.
