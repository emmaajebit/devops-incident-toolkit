# Decision tree

Start at `./ir help` or `./ir suggest "<symptom>"`.

```
Alert
 ├─ Host / VM ────────────── ./ir health
 │    ├─ CPU / load / steal ─ ./ir cpu
 │    ├─ Memory / OOM ─────── ./ir mem
 │    ├─ Disk / inodes ────── ./ir disk /
 │    ├─ Network / DNS ────── ./ir net
 │    └─ Service logs ─────── ./ir logs <unit>
 ├─ Docker ────────────────── ./ir docker [name]
 ├─ Kubernetes
 │    ├─ Cluster snapshot ─── ./ir k8s [ns] [pod]
 │    ├─ Node NotReady ────── ./ir k8s-node [node]
 │    ├─ CrashLoop / HPA ──── ./ir k8s-app <ns> [name]
 │    └─ 502 / endpoints ──── ./ir k8s-net <ns> [svc]
 ├─ Prometheus / paging ───── PROM_URL=… ./ir prom
 └─ EC2 unreachable ───────── ./ir ec2 i-… [region]

Always snapshot before you change anything:
  ./ir pack
```

Long form: `docs/symptom-index.md`, `docs/cheatsheet.md`, `docs/incident-workflow.md`.
