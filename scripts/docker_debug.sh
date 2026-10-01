#!/bin/bash
# docker_debug.sh — engine health, container resource use, events, and logs.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

CONTAINER="${1:-}"

ir_header "Docker Troubleshooting"

if ! command -v docker >/dev/null 2>&1; then
  ir_fail "docker CLI not found in PATH"
  exit 1
fi

ir_section "Engine"
docker version --format 'Client={{.Client.Version}} Server={{.Server.Version}} API={{.Server.APIVersion}}' 2>/dev/null \
  || docker version
echo
docker info 2>/dev/null | grep -E 'Server Version|Cgroup|Storage Driver|Logging Driver|Swarm|CPUs|Total Memory|Docker Root|Live Restore|Error' || true

ir_section "Disk used by Docker"
docker system df 2>/dev/null || true

ir_section "Containers"
docker ps -a --format 'table {{.ID}}\t{{.Names}}\t{{.Status}}\t{{.Ports}}\t{{.Image}}' 2>/dev/null || docker ps -a

ir_section "Resource snapshot"
docker stats --no-stream --format 'table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.MemPerc}}\t{{.NetIO}}\t{{.BlockIO}}' 2>/dev/null || true

ir_section "Recent events (15m)"
docker events --since 15m --until 0s --format '{{.Time}} {{.Type}} {{.Action}} {{.Actor.Attributes.name}}' 2>/dev/null | tail -n 40 || true

if [[ -n "$CONTAINER" ]]; then
  ir_section "Inspect ${CONTAINER}"
  docker inspect --format 'status={{.State.Status}} oom={{.State.OOMKilled}} exit={{.State.ExitCode}} error={{.State.Error}} started={{.State.StartedAt}} finished={{.State.FinishedAt}} restart={{.RestartCount}} health={{if .State.Health}}{{.State.Health.Status}}{{else}}n/a{{end}}' "$CONTAINER" 2>/dev/null || ir_fail "cannot inspect $CONTAINER"
  echo
  echo "last 80 log lines:"
  docker logs --tail 80 "$CONTAINER" 2>&1 || true
  echo
  echo "top processes inside:"
  docker top "$CONTAINER" 2>/dev/null || true
fi

ir_section "Dangling / leftover risk"
echo "stopped containers: $(docker ps -aq -f status=exited 2>/dev/null | wc -l)"
echo "dangling images:    $(docker images -f dangling=true -q 2>/dev/null | wc -l)"

ir_section "Suggested next checks"
cat <<'EOF'
  1. Restart loops: docker inspect .State.{OOMKilled,Error,Health} and logs.
  2. Disk full under /var/lib/docker: overlay2 + logs; cap json-file max-size.
  3. "network not found" after compose down: leftover containers on old networks.
  4. Pass a name/id: ./scripts/docker_debug.sh my-api
EOF

