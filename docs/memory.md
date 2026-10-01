# Memory troubleshooting

Script: `scripts/memory_debug.sh`

## Mental model

`free` “used” includes cache. **MemAvailable** is the number that predicts whether the next allocation succeeds.

| Observation | Meaning |
| --- | --- |
| Used high, MemAvailable high | Cache; usually fine |
| MemAvailable collapsing, `si`/`so` > 0 | Real pressure; latency will climb |
| OOM killer lines in dmesg | Already lost a process; find the cgroup that blew up |
| RSS modest, VSZ huge | Mapping leak or a language runtime reservation |
| Host fine, pod OOMKilled | Container limit, not the node |

## PSI

`/proc/pressure/memory` (`some` / `full` over 10s, 60s, 300s) is the best early-warning signal on kernels ≥ 4.20. Rising `full` means tasks are actually stalled.

## After an OOM

1. Keep the script output (it greps dmesg/journal).
2. Identify the killed PID and the cgroup (`oom-kill` lines include both).
3. If it was a container: `docker inspect` / `kubectl describe pod` for `OOMKilled=true`.
4. Raise the limit *or* fix the leak. Raising the limit without a graph of RSS over time just delays the next page.
