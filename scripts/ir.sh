#!/bin/bash
# ir.sh — single entrypoint for the Incident Response Toolkit.
# Usage: ir.sh <command> [args...]
#        ir.sh                    # interactive menu when stdin is a TTY
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

run_script() {
  local name="$1"; shift || true
  local path="${SCRIPT_DIR}/${name}"
  if [[ ! -f "$path" ]]; then
    ir_fail "missing ${path}"
    return 1
  fi
  bash "$path" "$@"
}

print_help() {
  cat <<EOF
${C_BOLD}Incident Response Toolkit${C_RST}  v${IR_TOOLKIT_VERSION}

${C_BOLD}Usage${C_RST}
  ./ir <command> [args]
  ./scripts/ir.sh <command> [args]

${C_BOLD}Start here${C_RST}
  health                  Linux host snapshot          (server_health.sh)
  pack                    Capture evidence tarball     (collect_evidence.sh)
  suggest <text>          Map a symptom to commands
  menu                    Interactive picker

${C_BOLD}Host${C_RST}
  cpu | mem | disk [path] | net [host] | logs [unit|file] [lines]

${C_BOLD}Containers & cluster${C_RST}
  docker [container]
  k8s [ns] [pod]
  k8s-node [node]
  k8s-app <ns> [name]
  k8s-net <ns> [service]
  prom [http://prometheus:9090]

${C_BOLD}Cloud${C_RST}
  ec2 <instance-id> [region]

${C_BOLD}Docs${C_RST}
  cheat                   Print the one-page cheatsheet
  docs                    List runbooks

${C_DIM}Env: NO_COLOR=1  IR_NS=production  PROM_URL=...  AWS_DEFAULT_REGION=...
     DISK_WARN DISK_CRIT MEM_WARN MEM_CRIT CPU_WARN CPU_CRIT${C_RST}
EOF
}

suggest() {
  local q
  q="$(echo "$*" | tr '[:upper:]' '[:lower:]')"
  ir_header "Symptom → command"
  case "$q" in
    *cpu*|*load*|*throttle*|*steal*|*credit*)
      echo "  ./ir cpu"
      echo "  ./ir k8s-node            # if the workload is on Kubernetes"
      echo "  PROM_QUERY='sum(rate(container_cpu_cfs_throttled_seconds_total[5m])) by (namespace,pod)' ./ir prom"
      echo "  docs: docs/cpu.md docs/prometheus.md"
      ;;
    *mem*|*oom*|*rss*|*swap*)
      echo "  ./ir mem"
      echo "  ./ir k8s-app \$IR_NS <deploy>"
      echo "  ./ir docker <container>  # look for OOMKilled"
      echo "  docs: docs/memory.md"
      ;;
    *disk*|*inode*|*space*|*full*|*iowait*|*await*)
      echo "  ./ir disk /"
      echo "  ./ir docker              # overlay2 + json-file logs"
      echo "  docs: docs/disk.md"
      ;;
    *dns*|*tcp*|*timeout*|*connect*|*reset*|*5xx*|*502*|*503*|*504*|*ingress*|*endpoint*)
      echo "  ./ir net"
      echo "  ./ir k8s-net \${IR_NS:-default} <service>"
      echo "  docs: docs/network.md docs/kubernetes.md"
      ;;
    *crash*|*restart*|*backoff*|*probe*|*unhealthy*|*pending*|*imagepull*)
      echo "  ./ir k8s \${IR_NS:-default}"
      echo "  ./ir k8s-app \${IR_NS:-default} <name>"
      echo "  ./ir logs <unit>"
      echo "  docs: docs/kubernetes.md docs/logs.md"
      ;;
    *prom*|*metric*|*alert*|*grafana*|*scrape*|*cardinality*)
      echo "  PROM_URL=http://127.0.0.1:9090 ./ir prom"
      echo "  docs: docs/prometheus.md"
      echo "  queries: scripts/promql/k8s.promql"
      ;;
    *ec2*|*instance*|*status.check*|*ssm*)
      echo "  ./ir ec2 i-xxxxxxxx <region>"
      echo "  docs: docs/ec2.md"
      ;;
    *docker*|*container*|*compose*)
      echo "  ./ir docker"
      echo "  ./ir docker <name>"
      echo "  docs: docs/docker.md"
      ;;
    *slow*|*latency*|*p99*)
      echo "  ./ir health && ./ir cpu && ./ir disk && ./ir net"
      echo "  ./ir k8s-app \${IR_NS:-default} <name>"
      echo "  ./ir prom                 # histogram_quantile in scripts/promql/k8s.promql"
      ;;
    *)
      echo "  No exact match. Start with:"
      echo "    ./ir health"
      echo "    ./ir k8s \${IR_NS:-default}"
      echo "    ./ir suggest crashloop"
      echo "    ./ir suggest oom"
      echo "    ./ir suggest 502"
      echo "    ./ir suggest scrape"
      ;;
  esac
}

menu() {
  print_help
  echo
  if [[ ! -t 0 ]]; then
    ir_info "stdin is not a TTY — pass a command instead of menu"
    return 0
  fi
  echo -n "command> "
  local line
  read -r line || return 0
  # Recurse without menu to avoid loops
  # shellcheck disable=SC2086
  main $line
}

show_cheat() {
  if [[ -f "${ROOT_DIR}/docs/cheatsheet.md" ]]; then
    cat "${ROOT_DIR}/docs/cheatsheet.md"
  else
    ir_warn "docs/cheatsheet.md missing"
  fi
}

list_docs() {
  ir_header "Runbooks"
  ls -1 "${ROOT_DIR}/docs"/*.md 2>/dev/null
}

main() {
  local cmd="${1:-}"
  if [[ -z "$cmd" ]]; then
    if [[ -t 0 ]]; then
      menu
      return 0
    fi
    print_help
    return 0
  fi
  shift || true
  case "$cmd" in
    -h|--help|help) print_help ;;
    health|host)    run_script server_health.sh "$@" ;;
    cpu)            run_script cpu_debug.sh "$@" ;;
    mem|memory)     run_script memory_debug.sh "$@" ;;
    disk)           run_script disk_debug.sh "$@" ;;
    net|network)    run_script network_debug.sh "$@" ;;
    logs|log)       run_script log_debug.sh "$@" ;;
    docker)         run_script docker_debug.sh "$@" ;;
    k8s|kube)       run_script k8s_debug.sh "$@" ;;
    k8s-node|node)  run_script k8s_node_debug.sh "$@" ;;
    k8s-app|app|workload) run_script k8s_workload_debug.sh "$@" ;;
    k8s-net|svc)    run_script k8s_network_debug.sh "$@" ;;
    prom|prometheus) run_script prometheus_debug.sh "$@" ;;
    ec2)            run_script ec2_debug.sh "$@" ;;
    pack|evidence)  run_script collect_evidence.sh "$@" ;;
    suggest|why)    suggest "$*" ;;
    menu)           menu ;;
    cheat|cheatsheet) show_cheat ;;
    docs)           list_docs ;;
    *)
      ir_fail "unknown command: ${cmd}"
      echo
      print_help
      return 2
      ;;
  esac
}

main "$@"
