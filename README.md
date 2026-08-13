# DevOps Incident Toolkit

Production-ready troubleshooting toolkit for Linux, Docker, Kubernetes, and AWS incidents.

## Quick Start

```bash
# Clone the repo
git clone https://github.com/emmaajebit/devops-incident-toolkit.git
cd devops-incident-toolkit

# Make scripts executable
chmod +x *.sh

# Run general health check first
./server_health.sh
```

## The 9 Scripts

| Script | Purpose | When to Use |
|--------|---------|-------------|
| `server_health.sh` | General first-aid for any Linux server | "Server is slow", "App behaving strangely" |
| `cpu_debug.sh` | Investigate high CPU usage | Monitoring shows CPU > 90% |
| `memory_debug.sh` | Find memory pressure and OOM kills | App slow, requests timing out, memory at 95% |
| `disk_debug.sh` | Locate what's filling the disk | Disk alert > 90%, or can't create files |
| `network_debug.sh` | Test connectivity and ports | Connection timeout to DB or external service |
| `log_debug.sh` | Extract service and application logs | Service running but users seeing errors |
| `docker_debug.sh` | Debug Docker containers | App runs in Docker, container exited or high resource use |
| `k8s_debug.sh` | Troubleshoot Kubernetes workloads | Pod in CrashLoopBackOff, ImagePullBackOff, etc. |
| `ec2_debug.sh` | Inspect AWS infrastructure around EC2 | Suspect security group, EBS, or AWS status check issue |

## Recommended Incident Workflow

1. Start with `./server_health.sh`
2. Follow the alert → hypothesis → evidence → fix path
3. Use the specific debug script for the failing component
4. Check logs last if nothing else explains it

## Features

- Color-coded output (green=OK, yellow=warn, red=critical)
- Safe to run in production (read-only where possible)
- Consistent structure across all scripts
- Built-in help with `--help`
- Decision tree for quick navigation

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

## License

MIT License - free to use and modify at work or anywhere else.