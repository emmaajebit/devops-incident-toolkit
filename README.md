# DevOps Incident Response Toolkit

A production-oriented collection of Bash scripts and troubleshooting documentation for Linux servers, AWS EC2, Docker, and Kubernetes.

During production incidents, engineers lose minutes reconstructing the same commands. This toolkit gives you one-command health snapshots, specialized follow-up scripts, and written runbooks that tell you *what the output means*.

## What you get

- One-command host health checks
- Structured troubleshooting workflows (CPU, memory, disk, network, logs)
- Reusable, copy-paste-safe Bash scripts with shared helpers
- AWS EC2 diagnostics via the AWS CLI
- Kubernetes and Docker triage (cluster, node, workload, Service/DNS)
- Prometheus / Alertmanager health and incident PromQL
- A single `./ir` command (symptom suggestions + evidence pack)
- Step-by-step documentation and sample output, including a developer cheatsheet

## Repository layout

| Folder | Purpose |
| --- | --- |
| `scripts/` | Executable Bash scripts |
| `scripts/lib/` | Shared helpers (`common.sh`) |
| `docs/` | Troubleshooting guides and the incident workflow |
| `examples/` | Sample outputs captured from a healthy lab host |
| `assets/` | Diagrams (Mermaid source in Markdown) |

## Quick start

```bash
git clone https://github.com/emmaajebit/devops-incident-toolkit.git
cd devops-incident-toolkit

chmod +x ir scripts/*.sh scripts/lib/common.sh

./ir help
./ir health
./ir suggest crashloop
./ir k8s production
./ir pack
```

Developers: start with [docs/cheatsheet.md](docs/cheatsheet.md) and [docs/for-developers.md](docs/for-developers.md). You can keep calling `./scripts/foo.sh` directly; `./ir` is only a dispatcher.

Scripts degrade gracefully when they lack root, optional packages (`sysstat`, `lsof`), or cloud credentials. Set `NO_COLOR=1` to disable ANSI color.

Optional environment thresholds (defaults shown):

```bash
export CPU_WARN=80 CPU_CRIT=95
export MEM_WARN=80 MEM_CRIT=95
export DISK_WARN=80 DISK_CRIT=90
export LOAD_PER_CORE_WARN=1.0 LOAD_PER_CORE_CRIT=2.0
```

## Available scripts

| Script | Purpose | Typical arguments |
| --- | --- | --- |
| `server_health.sh` | Full Linux health snapshot | none |
| `cpu_debug.sh` | Load, steal, run queue, top PIDs | none |
| `memory_debug.sh` | RSS, PSI, swap, OOM | none |
| `disk_debug.sh` | Capacity, inodes, IO, largest files | `[path]` default `/` |
| `network_debug.sh` | Interfaces, DNS, sockets, drops | `[host]` for ping |
| `log_debug.sh` | Journal + file/unit triage | `[unit-or-path] [lines]` |
| `docker_debug.sh` | Engine, stats, events, one container | `[container]` |
| `k8s_debug.sh` | Cluster, namespace, pod | `[namespace] [pod]` |
| `k8s_node_debug.sh` | Node conditions, taints, allocatable | `[node]` |
| `k8s_workload_debug.sh` | Deploy/STS/HPA/PDB, logs | `<namespace> [name]` |
| `k8s_network_debug.sh` | Service, endpoints, DNS, policies | `<namespace> [service]` |
| `prometheus_debug.sh` | Prometheus health, targets, PromQL | `[http://host:9090]` |
| `ec2_debug.sh` | Instance, status, EBS, SG, CloudWatch | `<instance-id> [region]` |
| `ir.sh` (`./ir`) | Dispatcher, menu, `suggest`, docs | `<command> [args]` |
| `collect_evidence.sh` | Snapshot + tarball under `evidence/` | `[out-dir]` |

## Incident response workflow

When an alert arrives:

1. `./ir health` on the host, or `./ir k8s <ns>` if the unit is a cluster.
2. `./ir suggest "<what you see>"` if you are unsure which script to run.
3. Run the matching command (`cpu`, `mem`, `k8s-app`, `k8s-net`, `prom`, …).
4. `./ir pack` before you restart anything; attach the tarball when you escalate.
5. Escalate with evidence: timestamps, thresholds crossed, and the exact command output.

See [docs/incident-workflow.md](docs/incident-workflow.md) for the longer form, including severity, comms, and post-incident notes.

## Documentation index

- [Cheatsheet](docs/cheatsheet.md) · [For developers](docs/for-developers.md) · [Symptom index](docs/symptom-index.md)
- [Incident workflow](docs/incident-workflow.md)
- [Linux host runbook](docs/linux-host.md)
- [CPU](docs/cpu.md) · [Memory](docs/memory.md) · [Disk](docs/disk.md) · [Network](docs/network.md) · [Logs](docs/logs.md)
- [Docker](docs/docker.md)
- [Kubernetes](docs/kubernetes.md) · [Prometheus](docs/prometheus.md)
- [AWS EC2](docs/ec2.md)
- [Safety and assumptions](docs/safety.md)

## Requirements

| Area | Tools |
| --- | --- |
| Host scripts | Bash 4+, standard `procps`, `iproute2`, `coreutils` |
| Richer CPU/disk | `sysstat` (`mpstat`, `iostat`), `lsof` |
| Docker | Docker CLI talking to a live engine |
| Kubernetes | `kubectl` with a working kubeconfig |
| Prometheus | `curl` + optional `PROM_URL` / `PROM_TOKEN`; `kubectl` for operator discovery |
| EC2 | AWS CLI v2, credentials, and `ec2:Describe*` / `cloudwatch:GetMetricStatistics` / optional `ssm:DescribeInstanceInformation` |

Scripts are written for modern Linux (systemd, cgroup v1 or v2). They are read-mostly: they do not restart services, resize volumes, or mutate cluster objects.

## License

MIT. See [LICENSE](LICENSE).
