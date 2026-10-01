# Incident runbook

Operational playbook for this toolkit. Use it during an active incident. Architecture notes and command tables live in [README.md](README.md). The one-page version is [docs/cheatsheet.md](docs/cheatsheet.md).

This document assumes you can clone or already have the repo on the jump host / laptop you use for production access.

```bash
cd devops-incident-toolkit
chmod +x ir scripts/*.sh
export NO_COLOR=1                 # optional; easier to paste
```

---

## 1. Roles and communications

Do this before the second command.

| Role | Job |
| --- | --- |
| Incident commander | Owns severity, comms cadence, go/no-go on risky changes |
| Operator | Types commands. One person only. |
| Scribe | Timeline: UTC time, hypothesis, action, result |
| Comms | Updates stakeholders on the agreed interval |

**First message (copy and fill):**

```text
INCIDENT declared
Impact: <user-facing / internal / single tenant>
Since: <UTC>
Owner: <name>
Next update: <now + 15 min>
Working theory: <one sentence or "unknown">
```

Rules:

- One operator. Pairing is fine; two people pasting `kubectl` is not.
- Observation first. Do not restart, scale, prune, or vacuum until a snapshot exists.
- Speak in UTC. Align timestamps with the alert window.

---

## 2. Severity

| Sev | User impact | Cadence | Toolkit posture |
| --- | --- | --- | --- |
| SEV1 | Full outage or data risk | Every 15 min | Snapshot fast, skip niceties, commander on the call |
| SEV2 | Major degradation | Every 30 min | Full `./ir health` or `./ir k8s` before changes |
| SEV3 | Partial / single tenant | Hourly or at milestones | Specialized script + logs |
| SEV4 | Latent risk | Ticket | Run the check, do not page more people |

Escalate severity if blast radius grows or if you cannot name a working theory after one full snapshot cycle.

---

## 3. First five minutes

1. Declare the incident (section 1).
2. Identify the **unit of failure**:
   - one VM / instance → section 5
   - one container host → section 6
   - a Kubernetes object → section 7
   - “instance unreachable” in AWS → section 8
   - a page / missing metrics → section 9
3. Run the matching first command.
4. `./ir pack` if you may lose the box or restart a crash-looping pod.
5. Classify. “The site is down” is not a diagnosis.

Unsure which script?

```bash
./ir suggest crashloop
./ir suggest oom
./ir suggest 502
./ir suggest scrape
./ir suggest steal
```

---

## 4. Evidence (do this before you change anything)

```bash
export IR_NS=production IR_SVC=api IR_CONTAINER=api
export PROM_URL=http://127.0.0.1:9090          # if you have a port-forward
export EC2_INSTANCE_ID=i-… AWS_DEFAULT_REGION=us-east-1
./ir pack
# → evidence/<UTC>/ and evidence/<UTC>.tar.gz
```

Attach the tarball when you escalate. Redact SG CIDRs and customer hostnames if the channel is public.

You must capture, at minimum:

| Artifact | Why it dies if you restart first |
| --- | --- |
| `kubectl logs --previous` / `docker logs` | New container has no stack |
| `OOMKilled` / last state | Reset on the next start |
| `dmesg` OOM lines | Ring buffer rolls |
| Deleted-but-open files | Disappear when the process exits |
| Failed unit journal from this boot | `journalctl -b` is boot-scoped |

---

## 5. Linux host / VM

**Start**

```bash
./ir health
# same as ./scripts/server_health.sh
```

Read output in this order:

1. Failed systemd units
2. Disk **and** inode percentages
3. MemAvailable (not “used”, which includes cache)
4. Load per core vs `nproc`
5. Listening sockets — is the app bound where you think?

Then branch:

| Signal | Command | Notes |
| --- | --- | --- |
| Load / `us` / steal high | `./ir cpu` | Steal on T-family → credits, not your code |
| Load high, CPU idle | `./ir cpu` then `./ir disk` | D-state / NFS / await |
| MemAvailable collapsing, swap `si/so`, OOM | `./ir mem` | Confirm cgroup vs host |
| `df` or inodes critical | `./ir disk /` | Blocks ≠ inodes; check `lsof +L1` |
| No listener / DNS / drops | `./ir net [target]` | Then cloud SG / NACL |
| Unit failed / 5xx in logs | `./ir logs nginx` or path | |

Deep dives: [docs/linux-host.md](docs/linux-host.md), [docs/cpu.md](docs/cpu.md), [docs/memory.md](docs/memory.md), [docs/disk.md](docs/disk.md), [docs/network.md](docs/network.md), [docs/logs.md](docs/logs.md).

**Small mitigations (after snapshot)**

- Vacuum journal: `journalctl --vacuum-size=500M` (mitigation, not root cause).
- Restart **one** service unit, not the host.
- Do not `rm` under `/var/lib/docker` or `/var/lib/kubelet`.

---

## 6. Docker

```bash
./ir docker
./ir docker api
```

Split engine vs container:

- Engine: `docker info` errors, overlay2 full, dockerd down.
- Container: restart loop, `OOMKilled=true`, exit `137` (SIGKILL), exit `1/2` (app).

`docker system df` before anyone types `prune`. json-file logs without `max-size` fill the root filesystem.

See [docs/docker.md](docs/docker.md).

---

## 7. Kubernetes

**Order that usually saves time**

```bash
export IR_NS=production
./ir k8s $IR_NS
./ir k8s-app $IR_NS api
./ir k8s-net $IR_NS api
./ir k8s-node <node>
```

1. Can you reach the API? (`cluster-info`, `readyz`)
2. Are nodes Ready? MemoryPressure / DiskPressure / PIDPressure / NetworkUnavailable?
3. Which pods are not Running/Succeeded?
4. **Events before logs** for scheduling and image pull.
5. `describe` + current logs + **previous** logs.

| Symptom | First look | Command |
| --- | --- | --- |
| ImagePullBackOff | Image name, pull secret, node egress | `./ir k8s $NS` events |
| CrashLoopBackOff | previous logs, probes, required Secret, OOM | `./ir k8s-app $NS $NAME` |
| Pending | requests vs allocatable, PVC, taints | `./ir k8s-node` |
| 0/1 Ready, empty Endpoints | readiness + selector vs labels | `./ir k8s-net $NS $SVC` |
| Ingress 502/504 | backend Service + controller logs | `./ir k8s-net` |
| HPA stuck at min | metrics-server / adapter missing | `./ir k8s-app` + `./ir prom` |
| Drain hangs | PDB `maxUnavailable=0` | `./ir k8s-app` |
| Node NotReady | kubelet, disk, CNI, cloud | `./ir k8s-node` then section 8 |

This toolkit never `kubectl delete`, `rollout restart`, or scale. Those are mitigations you take **after** the snapshot.

**Small mitigations**

- Bounce **one** pod, not the Deployment.
- Cordon **one** node, not the ASG.
- Fix a wrong probe or missing env rather than raising every limit.

See [docs/kubernetes.md](docs/kubernetes.md).

---

## 8. AWS EC2 “instance unreachable”

```bash
./ir ec2 i-0123456789abcdef0 us-east-1
```

| Status check | Meaning | Next |
| --- | --- | --- |
| System reachability failed | AWS path / hypervisor | Stop-start or AWS support; stop debugging userspace |
| Instance reachability failed | Guest kernel hung | Serial console, SSM, snapshot + mount elsewhere |
| Both OK, app down | Guest is up | SSH/SSM and `./ir health` |

Burstable types (`t3`, `t3a`, `t4g`): 100% CPU with empty `CPUCreditBalance` is not an application bug. Confirm CloudWatch before you profile.

See [docs/ec2.md](docs/ec2.md).

---

## 9. Prometheus, Alertmanager, “the page is wrong”

Pipeline:

```text
scrape target → TSDB → rule evaluation → Alertmanager → receiver
```

```bash
kubectl -n monitoring port-forward svc/prometheus-operated 9090:9090
PROM_URL=http://127.0.0.1:9090 ./ir prom
```

Without `PROM_URL`, the script lists operator / exporter pods and `ServiceMonitor` / `PrometheusRule` CRs via kubectl.

| Finding | Meaning |
| --- | --- |
| `/-/healthy` fail | Process down |
| `/-/ready` fail | WAL replay / not serving queries |
| Many targets `DOWN` | ServiceMonitor selector, NetworkPolicy, scrape timeout, kubelet :10250 |
| `prometheus_tsdb_head_series` exploding | Cardinality (user_id, raw path, pod UID) |
| `rule_evaluation_failures_total` | Rules error; they will never page correctly |
| `notifications_dropped_total` | Alertmanager unreachable |
| Alert firing in UI, nobody paged | Silence, route matchers, inhibit, bad receiver |

Query pack: [scripts/promql/k8s.promql](scripts/promql/k8s.promql).

Correlate:

| PromQL idea | Next |
| --- | --- |
| `increase(kube_pod_container_status_restarts_total[1h])` | `./ir k8s-app` |
| `..._last_terminated_reason{reason="OOMKilled"}` | workload + `./ir mem` on the node |
| `rate(container_cpu_cfs_throttled_seconds_total[5m])` | limit too low — `./ir k8s-node` |
| `kube_node_status_condition` | `./ir k8s-node` |
| `kube_endpoint_address_not_ready` | `./ir k8s-net` |

See [docs/prometheus.md](docs/prometheus.md).

---

## 10. “My app is slow”

`./ir suggest slow` then run host + workload + PromQL p99. In practice it is one of:

- CPU throttle (`cfs_throttled`) — limit, not “need more nodes”
- Disk await — logs or EBS burst
- Downstream timeouts — `./ir net` + 5xx ratio
- Hot code path — only profile after the platform looks healthy

The toolkit will not profile your binary. It tells you whether the platform is the bottleneck.

---

## 11. Escalation packet

Paste this, attach `evidence/*.tar.gz`:

```text
Time (UTC):
Sev:
Impact:
Unit of failure (host / pod / node / account):
Commands run:
Working theory:
What we already changed:
What we need from you:
```

A useful example:

> 03:12 UTC `api-prod-3` load 18 on 2 cores, steal 22%, T3 credits depleted (CloudWatch). `./ir cpu` + `./ir ec2` attached. Ask: move workload off T-family or enable unlimited credits.

---

## 12. After mitigation

1. Watch the **same** command until the original signal is green for a full alert cycle.
2. Do not leave a “temporary” scale-up undocumented.
3. Write the post-incident note while timestamps are in chat history:
   - detection gap
   - what the toolkit showed
   - what you still wish it showed
4. Open a PR: new `./ir suggest` phrase, extra PromQL, or a doc sentence. See [CONTRIBUTING.md](CONTRIBUTING.md).

---

## 13. Safety constraints (non-negotiable during the call)

From [docs/safety.md](docs/safety.md):

- No `kubectl delete`, no `docker system prune -af`, no `rm -rf /var/log`.
- No pasting Secret **values** or raw office-IP SG CIDRs into a public channel.
- Missing-binary `[WARN]` means that section is incomplete, not that the host is healthy.
- Distroless / Alpine *inside* a container may not understand GNU `ps`/`df` flags — exec onto a debug image or the node.

---

## 14. Command cheat sheet

```bash
./ir help
./ir health
./ir cpu | mem | disk / | net 1.1.1.1 | logs nginx 200
./ir docker api
./ir k8s prod
./ir k8s-app prod api
./ir k8s-net prod api
./ir k8s-node ip-10-0-1-23
PROM_URL=http://127.0.0.1:9090 ./ir prom
./ir ec2 i-0123456789abcdef0 us-east-1
./ir pack
./ir cheat
```

Decision tree: [DECISION_TREE.md](DECISION_TREE.md). Symptom table: [docs/symptom-index.md](docs/symptom-index.md).
