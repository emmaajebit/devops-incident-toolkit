# For application developers

You do not need to be the cluster admin to use this repo. The goal is: **get a snapshot a platform engineer can use**, and avoid destroying the only copy of the failure (previous logs, OOM reason, empty endpoints).

## Mental model

| Layer | Your question | Command |
| --- | --- | --- |
| My process on a VM | Is the box sick? | `./ir health` |
| My container | Did Docker kill it? | `./ir docker <name>` |
| My Deployment | Why is the ReplicaSet not Ready? | `./ir k8s-app <ns> <name>` |
| My Service / Ingress | Why 502 if pods look up? | `./ir k8s-net <ns> <svc>` |
| The page I got | Is Prometheus scraping me? | `./ir prom` |

## A realistic 10-minute path

Alert: `prod/api` CrashLoopBackOff.

```bash
cd devops-incident-response-toolkit
chmod +x ir scripts/*.sh

export IR_NS=prod
./ir suggest crashloop
./ir k8s $IR_NS
./ir k8s-app $IR_NS api
```

Read, in this order, from the output:

1. `Restart Count` and `Last State` / `OOMKilled`
2. Events (`FailedMount`, `Unhealthy`, `Backoff`)
3. **Previous** logs — the current container may only have “starting…”
4. Readiness/liveness probe lines from `describe`

Then pick *one* reversible action: fix the env/secret, relax a too-tight probe, or bounce **one** pod — not the whole Deployment — after the snapshot exists.

```bash
./ir pack    # if IR_NS / IR_POD / PROM_URL are set they are included
```

Hand the tarball to whoever owns the node or the cluster.

## What “my app is slow” usually is

Run `./ir suggest slow`. In practice it is one of:

- CPU throttle (`container_cpu_cfs_throttled_seconds_total`) — limit too low, not “need a bigger cluster”
- Disk await — log volume or EBS burst
- Downstream timeouts — `./ir net` + application 5xx labels in Prometheus
- Hot endpoint / missing index — logs + p99 query in `scripts/promql/k8s.promql`

The toolkit will not profile your code. It tells you whether the *platform* is the bottleneck so you do not spend the incident in the profiler while the node is `DiskPressure`.

## Conventions the scripts expect

- Namespace via argument or `IR_NS`
- Prometheus via `PROM_URL` (port-forward is your job; the script only `GET`s)
- No kubeconfig in the repo (`.gitignore` already excludes it)

## After the incident

Add the command you wish you had to `scripts/` and a row to this file. See `CONTRIBUTING.md`.
