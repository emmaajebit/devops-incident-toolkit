# Contributing

## Adding a check

1. Put shared formatting in `scripts/lib/common.sh`.
2. Keep the new script observational — no restarts, deletes, or cloud mutations.
3. Degrade when a binary or credential is missing (`ir_warn`, then continue).
4. Document the signal in `docs/` and link it from the README table.
5. Check syntax with `bash -n scripts/your_script.sh`.

## Style

- `set -u` and `pipefail`. Avoid `set -e` so one failed `ss` does not abort the snapshot.
- Quote every expansion.
- Prefer `/proc` and `ip`/`ss` over deprecated `ifconfig`/`netstat`, with fallbacks.
- Thresholds belong in environment variables with defaults, not hardcoded magic numbers only.

## What not to add

- Exploit PoCs, credential dumpers, or anything that weakens host security.
- Wrappers that `sudo rm` logs or `docker system prune -af` without an explicit second flag.
