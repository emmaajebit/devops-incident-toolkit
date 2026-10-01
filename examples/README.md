# Sample outputs

These files were captured on a lab Linux host so you can recognize a *healthy-ish* shape before an incident distorts it.

| File | Notes |
| --- | --- |
| `server_health.sample.txt` | Full host snapshot |
| `cpu_debug.sample.txt` | Load, steal, top PIDs |
| `memory_debug.sample.txt` | `free`, PSI if present, OOM grep |
| `disk_debug.sample.txt` | `df` + short scan of `/tmp` |
| `network_debug.sample.txt` | addresses, routes, sockets |
| `log_debug.sample.txt` | journal errors |
| `docker_debug.sample.txt` | CLI missing on the lab host — see annotated expected shape below |
| `k8s_debug.sample.txt` | same |
| `ec2_debug.sample.txt` | usage error when instance-id omitted |

Re-generate:

```bash
export NO_COLOR=1
bash scripts/server_health.sh > examples/server_health.sample.txt
```

When Docker / kubectl / aws are installed, replace the short samples with live output from a non-production account.
