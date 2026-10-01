# Symptom index

Use `./ir suggest "<phrase>"` during an incident. This page is the long form.

| Phrase | Start | Then |
| --- | --- | --- |
| site down | `./ir health` or `./ir k8s` | classify resource |
| high CPU | `./ir cpu` | steal vs us vs wa; T-family credits |
| load high, CPU idle | `./ir disk` + `./ir cpu` | D-state / NFS |
| OOM / killed | `./ir mem` | cgroup limit vs host |
| crashloop | `./ir k8s-app ns name` | `--previous` logs |
| image pull | `./ir k8s ns` events | registry / pull secret |
| pending pod | `./ir k8s-node` | requests, taints, PVC |
| 502 / 503 / 504 | `./ir k8s-net ns svc` | endpoints + readiness |
| DNS in cluster | `./ir k8s-net ns` | CoreDNS + ndots |
| node NotReady | `./ir k8s-node name` | pressure + cloud status |
| scrape down | `./ir prom` | ServiceMonitor selector |
| alert not paging | `./ir prom` | Alertmanager route / silence |
| instance unreachable | `./ir ec2 i-…` | system vs instance check |
| disk full | `./ir disk /` | inodes vs blocks vs deleted-open |
| container restart | `./ir docker name` | OOMKilled / exit code |
