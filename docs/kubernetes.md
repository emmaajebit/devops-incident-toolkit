# Kubernetes troubleshooting

Scripts:

| Script | Use when |
| --- | --- |
| `k8s_debug.sh [ns] [pod]` | First cluster snapshot |
| `k8s_node_debug.sh [node]` | NotReady, pressure, allocatable vs requests |
| `k8s_workload_debug.sh <ns> [name]` | CrashLoop, HPA, PDB, restart counters |
| `k8s_network_debug.sh <ns> [svc]` | Empty endpoints, Ingress 5xx, DNS, NetworkPolicy |
| `prometheus_debug.sh [url]` | Metrics pipeline, targets, firing alerts |

Metrics companion: [prometheus.md](prometheus.md) and `scripts/promql/k8s.promql`.

## Order of operations

1. Can you reach the API? (`cluster-info`, `readyz`)
2. Are nodes Ready? DiskPressure / MemoryPressure / NetworkUnavailable taints?
3. Which pods are not Running/Succeeded?
4. Events for that object — *events beat logs* for scheduling and image pull.
5. `describe pod` + current logs + **previous** logs.

## Failure mode map

| Symptom | First look |
| --- | --- |
| ImagePullBackOff | Image name, pull secret, node egress, registry outage |
| CrashLoopBackOff | `logs --previous`, probes, required env, OOM |
| Pending | Requests vs allocatable, PVC unbound, affinity, taints |
| 5xx behind Service | Endpoints empty, readiness probe, NetworkPolicy |
| Node NotReady | kubelet journal, CNI, disk, cloud controller |

## What this script will not do

It never `kubectl delete`, `rollout restart`, or scale. Those are mitigations you take *after* the snapshot.
