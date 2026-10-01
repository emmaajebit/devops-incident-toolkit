# DevOps Incident Response Toolkit

Production-oriented Bash diagnostics and runbooks for Linux hosts, AWS EC2, Docker, Kubernetes, and Prometheus.

During an incident, people lose time reconstructing the same commands. This repository gives you a **single entrypoint** (`./ir`), specialized follow-up scripts, and written guidance that explains *what the output means* — without mutating production.

**Repository:** [github.com/emmaajebit/devops-incident-toolkit](https://github.com/emmaajebit/devops-incident-toolkit)

---

## Why it exists

On-call pages arrive as symptoms (“API 502”, “node NotReady”, “CPU 100%”), not diagnoses. The toolkit is built so a developer who does not own the cluster, and an SRE who does, can:

1. Snapshot the system before anyone restarts anything.
2. Classify the scarce resource (CPU, memory, disk, network, control plane, scrape pipeline).
3. Hand the same evidence pack to the next person.

Scripts are **read-mostly**. They do not restart units, prune Docker, silence alerts, or call `kubectl delete` / `ec2 stop-instances`.

---

## Quick start

```bash
git clone https://github.com/emmaajebit/devops-incident-toolkit.git
cd devops-incident-toolkit
chmod +x ir scripts/*.sh scripts/lib/common.sh

./ir help
./ir health                         # Linux host snapshot
./ir suggest crashloop              # map a symptom to commands
./ir k8s production                 # cluster snapshot
./ir pack                           # evidence/<utc>/ + tarball
```

Print the one-pager: `./ir cheat` or open [docs/cheatsheet.md](docs/cheatsheet.md).

The **operational playbook** (roles, severity, per-symptom steps, comms templates) lives in **[RUNBOOK.md](RUNBOOK.md)**.

Root scripts such as `./server_health.sh` still work; they exec into `scripts/`. Prefer `./ir`.

---

## What you get

| Capability | How you use it |
| --- | --- |
| One-command host health | `./ir health` — load, memory, disk/inodes, listeners, failed units |
| Specialized host triage | `./ir cpu` `mem` `disk` `net` `logs` |
| Docker | `./ir docker [container]` — engine, stats, OOMKilled, logs |
| Kubernetes | `./ir k8s` `k8s-node` `k8s-app` `k8s-net` |
| Prometheus / Alertmanager | `PROM_URL=http://127.0.0.1:9090 ./ir prom` |
| AWS EC2 | `./ir ec2 i-… us-east-1` |
| Symptom router | `./ir suggest "502"` / `"oom"` / `"scrape down"` |
| Evidence pack | `./ir pack` → `evidence/<utc>.tar.gz` |
| Decision tree | [DECISION_TREE.md](DECISION_TREE.md) |
| Sample output | [examples/](examples/) |

---

## Repository layout

```text
.
├── ir                         # dispatcher (run this)
├── RUNBOOK.md                 # full incident playbook
├── DECISION_TREE.md           # symptom flowchart
├── server_health.sh …         # backward-compatible wrappers
├── scripts/
│   ├── ir.sh
│   ├── collect_evidence.sh
│   ├── lib/common.sh
│   ├── *_debug.sh
│   └── promql/k8s.promql
├── docs/                      # deep runbooks per subsystem
├── examples/                  # captured / annotated output
├── assets/                    # mermaid flow
└── .github/workflows/syntax.yml
```

---

## `./ir` command reference

| Command | Arguments | Script |
| --- | --- | --- |
| `help` / `menu` | | usage / TTY picker |
| `health` | | `server_health.sh` |
| `cpu` | | `cpu_debug.sh` |
| `mem` | | `memory_debug.sh` |
| `disk` | `[path]` default `/` | `disk_debug.sh` |
| `net` | `[host]` | `network_debug.sh` |
| `logs` | `[unit-or-path] [lines]` | `log_debug.sh` |
| `docker` | `[container]` | `docker_debug.sh` |
| `k8s` | `[namespace] [pod]` | `k8s_debug.sh` |
| `k8s-node` | `[node]` | `k8s_node_debug.sh` |
| `k8s-app` | `<namespace> [name]` | `k8s_workload_debug.sh` |
| `k8s-net` | `<namespace> [service]` | `k8s_network_debug.sh` |
| `prom` | `[http://host:9090]` | `prometheus_debug.sh` |
| `ec2` | `<instance-id> [region]` | `ec2_debug.sh` |
| `suggest` | `<free text>` | symptom map |
| `pack` | `[out-dir]` | `collect_evidence.sh` |
| `cheat` | | prints cheatsheet |
| `docs` | | lists `docs/*.md` |

Equivalent long form: `./scripts/<name>.sh`.

---

## Environment

```bash
export NO_COLOR=1                 # paste-friendly output
export IR_NS=production
export IR_POD=                    # optional pack/k8s focus
export IR_SVC=api
export IR_CONTAINER=api
export PROM_URL=http://127.0.0.1:9090
export PROM_TOKEN=                # optional bearer
export AM_URL=                    # Alertmanager, default guessed :9093
export EC2_INSTANCE_ID=i-0123456789abcdef0
export AWS_DEFAULT_REGION=us-east-1

# Thresholds (defaults)
export CPU_WARN=80 CPU_CRIT=95
export MEM_WARN=80 MEM_CRIT=95
export DISK_WARN=80 DISK_CRIT=90
export LOAD_PER_CORE_WARN=1.0 LOAD_PER_CORE_CRIT=2.0
```

`./ir pack` only runs Docker / kubectl / Prometheus / EC2 sections when the binary or the matching variable is present. Each section is capped at 45 seconds.

---

## Requirements

| Area | Tools |
| --- | --- |
| Host | Bash 4+, `procps`, `iproute2`, `coreutils` |
| Richer CPU/disk | `sysstat` (`mpstat`, `iostat`), `lsof` |
| Docker | Docker CLI against a live engine |
| Kubernetes | `kubectl` + kubeconfig |
| Prometheus | `curl`; optional `PROM_URL` / `PROM_TOKEN` |
| EC2 | AWS CLI v2 with `ec2:Describe*`, `cloudwatch:GetMetricStatistics`, optional `ssm:DescribeInstanceInformation` |

Missing binaries print `[WARN]` and continue. A warning is **not** a clean bill of health.

Verify scripts locally:

```bash
make check    # bash -n on ir + scripts/*.sh
```

---

## Incident path (short)

1. Declare owner + next update time (see [RUNBOOK.md](RUNBOOK.md)).
2. `./ir health` on a VM, or `./ir k8s <ns>` if the unit of failure is a cluster.
3. If unsure: `./ir suggest "<what you see>"`.
4. `./ir pack` **before** a restart so previous logs and OOM reasons survive.
5. Smallest reversible change. Watch the same command you used to diagnose.
6. Escalate with the tarball and UTC timestamps, not a feeling.

---

## Documentation map

| Doc | Audience |
| --- | --- |
| [RUNBOOK.md](RUNBOOK.md) | Anyone on call — full playbook |
| [docs/cheatsheet.md](docs/cheatsheet.md) | Printable first 5 minutes |
| [docs/for-developers.md](docs/for-developers.md) | App engineers who do not own the node |
| [docs/symptom-index.md](docs/symptom-index.md) | Phrase → command |
| [docs/incident-workflow.md](docs/incident-workflow.md) | Comms + severity skeleton |
| [docs/linux-host.md](docs/linux-host.md) | VM / bare metal |
| [docs/cpu.md](docs/cpu.md) · [memory.md](docs/memory.md) · [disk.md](docs/disk.md) · [network.md](docs/network.md) · [logs.md](docs/logs.md) | Host subsystems |
| [docs/docker.md](docs/docker.md) | Engine vs container |
| [docs/kubernetes.md](docs/kubernetes.md) | API, nodes, workloads, Services |
| [docs/prometheus.md](docs/prometheus.md) | Scrape → TSDB → rules → Alertmanager |
| [docs/ec2.md](docs/ec2.md) | Status checks, credits, SGs |
| [docs/safety.md](docs/safety.md) | What the scripts will never do |
| [scripts/promql/k8s.promql](scripts/promql/k8s.promql) | Copy-paste incident queries |

---

## Safety

- Observational only: `GET` Prometheus APIs, `kubectl get` / `describe` / `logs`, AWS `Describe*` / `GetMetricStatistics`.
- Kubernetes listings may include **Secret names**, never values.
- `ec2_debug.sh` prints security-group CIDRs — fine in a private channel, not in a public gist.
- Do not commit kubeconfigs, `.env`, or AWS keys (see `.gitignore`).
- Do not pipe script output into `sh`.

---

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). New checks belong in `scripts/`, should degrade without optional tools, and must stay non-mutating.

## License

MIT. See [LICENSE](LICENSE).
