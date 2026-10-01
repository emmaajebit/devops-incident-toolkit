# Incident cheatsheet (print this)

```text
./ir help
./ir health
./ir suggest "crashloop" | "oom" | "502" | "scrape down" | "slow"
./ir pack                          # evidence/<utc>/ + .tar.gz
```

## First 5 minutes

1. Say what is broken, who is driving, next update time.
2. `./ir health` on the box **or** `./ir k8s $NS` if the unit is a cluster.
3. Do not restart yet. Snapshot first (`./ir pack` if you may lose the box).
4. Follow the specialized command `./ir` printed under “Next steps”.
5. Escalate with the tarball + timestamps, not a vibe.

## Symptom → command

| I see… | Run |
| --- | --- |
| Page / high load / steal | `./ir cpu` |
| OOMKilled / swap / RSS | `./ir mem` then `./ir k8s-app $NS $APP` |
| Disk full / iowait | `./ir disk /` |
| Timeouts, DNS, no listen | `./ir net` / `./ir k8s-net $NS $SVC` |
| CrashLoop / probe fail | `./ir k8s-app $NS $APP` |
| 502/empty endpoints | `./ir k8s-net $NS $SVC` |
| Node NotReady | `./ir k8s-node $NODE` |
| Alert but metrics look empty | `PROM_URL=… ./ir prom` |
| Instance unreachable | `./ir ec2 i-… $REGION` |
| Container restart loop | `./ir docker $NAME` |

## Kubernetes one-liners (also wrapped by `./ir`)

```bash
export IR_NS=production
./ir k8s $IR_NS
./ir k8s-app $IR_NS api
./ir k8s-net $IR_NS api
kubectl logs -n $IR_NS deploy/api --tail=80 --all-containers
kubectl logs -n $IR_NS deploy/api --tail=80 --previous   # after a crash
```

## Prometheus

```bash
kubectl -n monitoring port-forward svc/prometheus-operated 9090:9090
PROM_URL=http://127.0.0.1:9090 ./ir prom
# queries: scripts/promql/k8s.promql
```

## Environment

```bash
export NO_COLOR=1                  # paste-friendly
export IR_NS=production IR_POD= IR_SVC=api IR_CONTAINER=api
export PROM_URL=http://127.0.0.1:9090
export EC2_INSTANCE_ID=i-… AWS_DEFAULT_REGION=us-east-1
```

`./ir pack` honours those variables and only runs the sections that apply.

## Do / don’t

- Do capture `--previous` logs before a restart.
- Do record UTC time next to every action.
- Don’t `docker system prune -af` or `kubectl delete` from this toolkit — it will not do that for you.
- Don’t paste Secret values or raw SG CIDRs into a public channel.
