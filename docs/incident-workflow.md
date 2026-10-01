# Incident response workflow

This is the operational path the toolkit is designed around. It is deliberately linear so a tired on-call engineer does not have to invent structure at 02:00.

## 0. Stabilize communications

- Declare the incident in your chat channel. State: what is broken, who is investigating, next update time.
- One person drives commands. Another takes notes (timeline + hypotheses).
- Do not change production yet. Observation first.

## 1. Confirm the blast radius

Ask, in order:

1. Is this one host, one AZ, one cluster, or everywhere?
2. Is user traffic failing, or only a probe?
3. When did it start relative to a deploy, scaling event, or certificate expiry?

If the alert is host-level, SSH/SSM in and run:

```bash
./scripts/server_health.sh
```

If the alert is Kubernetes, start with:

```bash
./scripts/k8s_debug.sh
./scripts/k8s_debug.sh <namespace>
./scripts/k8s_workload_debug.sh <namespace> <deploy>
./scripts/k8s_network_debug.sh <namespace> <service>
./scripts/k8s_node_debug.sh <node>
```

If the alert is a Prometheus rule or “metrics missing”:

```bash
PROM_URL=http://127.0.0.1:9090 ./scripts/prometheus_debug.sh
```

If the alert is “instance unreachable” from AWS:

```bash
./scripts/ec2_debug.sh i-… <region>
```

## 2. Classify the scarce resource

`server_health.sh` prints `[OK]`, `[WARN]`, and `[FAIL]` against load, memory, and disk. Use that classification:

| Signal | Follow-up |
| --- | --- |
| Load / steal / us% high | `cpu_debug.sh` |
| MemAvailable low, swap activity, OOM | `memory_debug.sh` |
| Filesystem or inode pressure, high await | `disk_debug.sh` |
| Packet drops, DNS failure, no listeners | `network_debug.sh` |
| Unit failed, HTTP 5xx, crash loops | `log_debug.sh`, then Docker/K8s scripts |

Do not skip classification. “The site is down” is not a diagnosis.

## 3. Collect evidence before you change anything

Capture:

- UTC timestamps (`date -u`) aligned with the alert window
- The script output itself (redirect to a file if you need to paste later)
- One round of application logs
- For crash-looping containers: *previous* logs (`kubectl logs --previous`, `docker inspect .State.OOMKilled`)

Changing a thing before you have a snapshot makes the post-incident review impossible and can destroy the only copy of the failure mode (OOM traces, deleted-open files, last journal boot).

## 4. Mitigate with the smallest reversible action

Examples of *small* actions, not a playbook you must follow blindly:

- Restart one replica, not the Deployment
- Cordon one node, not the ASG
- Vacuum the journal, not `rm -rf /var/log`
- Fail over traffic, not “reboot the instance”

Record the action and the time.

## 5. Escalate with a packet, not a feeling

A useful escalation looks like:

> 03:12 UTC `api-prod-3` load 18 on 2 cores, steal 22%, T3 credits depleted (CloudWatch). `cpu_debug.sh` attached. Request: move workload to m6i or enable unlimited credits.

## 6. After mitigation

- Watch the same scripts until the original signal is green for a full alert cycle.
- File the post-incident note: detection gap, what the toolkit showed, what you still wish it showed.
- Add that gap to this repo (new check, better threshold, extra doc section).

## Severity cheat sheet

| Sev | User impact | Toolkit posture |
| --- | --- | --- |
| SEV1 | Full outage | Workflow above, skip niceties, update every 15 min |
| SEV2 | Major degradation | Full health + specialized script before changes |
| SEV3 | Partial / single tenant | Specialized script + logs only |
| SEV4 | Latent risk | Run the check, open a ticket, do not page more people |
