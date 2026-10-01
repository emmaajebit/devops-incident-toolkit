#!/usr/bin/env bash
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
exec bash "${ROOT}/scripts/docker_debug.sh" "$@"
