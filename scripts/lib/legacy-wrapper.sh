#!/usr/bin/env bash
# Backward-compatible entrypoints for the original flat repo layout.
# Prefer: ./ir <command>
set -u
ROOT="$(cd "$(dirname "$0")" && pwd)"
name="$(basename "$0")"
exec bash "${ROOT}/scripts/${name}" "$@"
