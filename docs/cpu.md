# CPU troubleshooting

Script: `scripts/cpu_debug.sh`

## Mental model

Load average counts runnable *and* uninterruptible threads. High load with idle CPU is usually I/O (`D` state) or a thread explosion, not “we need a bigger CPU.”

| Observation | Likely cause |
| --- | --- |
| `us` high, one PID | Application hot loop, missing index, regex, JSON parse |
| `sy` high | Syscalls, too many threads, overlayfs, netfilter |
| `wa` high | Disk or NFS — switch to `disk_debug.sh` |
| `st` (steal) high | Hypervisor contention or T-family credit exhaustion |
| Load >> cores, CPU idle | D-state, NFS, or disk errors |

## Commands the script already wraps

- `nproc`, `lscpu`, `/proc/loadavg`, `/proc/stat`
- `mpstat -P ALL 1 1` or `vmstat 1 5`
- `ps` sorted by `%cpu`
- Count of `D` and `Z` states

## Follow-ups the script does not run (they are heavier)

```bash
pidstat -t 1 5
perf top -g          # needs debug symbols to be useful
timeout 30 strace -c -p <pid>
```

## Cloud-specific

On AWS burstable types (`t3`, `t3a`, `t4g`) always pair this script with `ec2_debug.sh` and the `CPUCreditBalance` metric. Guest `top` will show 100% CPU and you will waste time profiling an application that is simply out of credits.
