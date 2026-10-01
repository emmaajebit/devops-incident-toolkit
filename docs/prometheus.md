# Prometheus and Alertmanager

Scripts:

- `scripts/prometheus_debug.sh [http://prometheus:9090]`
- `scripts/promql/k8s.promql` — copy-paste queries for incidents

Related: [Kubernetes](kubernetes.md), `k8s_debug.sh`, `k8s_node_debug.sh`.

## When the page is “from Prometheus”

Do not start in Grafana. Confirm the pipeline is intact, then interpret the firing alert.

```text
scrape target → TSDB → rule eval → Alertmanager → receiver
```

A broken link anywhere produces “we are not paging” or “we are paging on stale data.”

## 1. Is Prometheus itself up?

```bash
# port-forward if needed
kubectl -n monitoring port-forward svc/prometheus-operated 9090:9090
PROM_URL=http://127.0.0.1:9090 ./scripts/prometheus_debug.sh
```

| Probe | Meaning |
| --- | --- |
| `/-/healthy` | Process alive |
| `/-/ready` | WAL replay finished; queries should work |
| `up == 0` | Something Prometheus *scrapes* is down — not Prometheus itself |
| `prometheus_tsdb_head_series` | Cardinality pressure |
| `prometheus_rule_evaluation_failures_total` | Rules that never fire because they error |
| `prometheus_notifications_dropped_total` | Alertmanager unreachable or overloaded |

## 2. Unhealthy targets

The script lists `health!=up` from `/api/v1/targets`. Typical causes:

- ServiceMonitor `selector` / `namespaceSelector` does not match the Service
- scrape timeout too low for a slow `/metrics`
- kubelet HTTPS + 10250 blocked from the Prometheus pod
- NetworkPolicy deny
- `honorLabels: true` colliding with relabel drops (looks like “wrong job”)
- pod restarted; target flap in `kube_pod_container_status_restarts_total`

Fix discovery first. Querying a missing metric wastes the incident.

## 3. Cardinality incidents

Symptoms: query timeouts, compaction lag, Prometheus OOM, rule eval duration climbing.

Usual offenders: `user_id`, `email`, `pod_uid`, raw `path`, unbounded `status_detail`.

Mitigations (in order of reversibility):

1. Drop the label in `metricRelabelings`
2. Add a recording rule that aggregates *before* dashboards use the raw series
3. Raise memory only after you can name the series that grew

## 4. Alerts fire in UI but nobody got paged

Check, in order:

1. Alert `state` is `firing` (not `pending`)
2. Alertmanager `/api/v2/alerts` sees it
3. No matching silence
4. Route `matchers` actually select the alert
5. Receiver secret / webhook is valid
6. Inhibition is not swallowing it

`prometheus_debug.sh` probes Alertmanager on `:9093` by default; override with `AM_URL`.

## 5. Correlating with Kubernetes

| Symptom | PromQL (see `scripts/promql/k8s.promql`) | Next script |
| --- | --- | --- |
| CrashLoop | `increase(kube_pod_container_status_restarts_total[1h])` | `k8s_workload_debug.sh` |
| OOM | `kube_pod_container_status_last_terminated_reason{reason="OOMKilled"}` | `k8s_workload_debug.sh` + `memory_debug.sh` on the node |
| Throttle | `rate(container_cpu_cfs_throttled_seconds_total[5m])` | `k8s_node_debug.sh` |
| Node NotReady | `kube_node_status_condition` | `k8s_node_debug.sh` + `ec2_debug.sh` if it is a VM |
| Empty Service | `kube_endpoint_address_not_ready` | `k8s_network_debug.sh` |

## 6. kube-prometheus-stack specifics

Operator objects to inspect (the discovery section of the script already lists them):

- `Prometheus` CR — retention, replicas, remote write, resources
- `ServiceMonitor` / `PodMonitor` / `Probe`
- `PrometheusRule` — the source of truth for what you think is alerting
- `Alertmanager` CR + secret with receivers

A rule edited only in Grafana will vanish on the next operator reconcile. Change `PrometheusRule` manifests.

## 7. Safety

The script only calls `GET` on Prometheus HTTP APIs and `kubectl get`. It does not reload config, silence alerts, or delete series.
