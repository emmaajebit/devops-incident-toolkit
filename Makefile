# Run checks from repo root: make check
.PHONY: check help health

help:
	@bash ./ir help

check:
	@bash -n ir
	@bash -n scripts/lib/common.sh
	@for f in scripts/*.sh; do bash -n "$$f" || exit 1; done
	@echo "bash -n OK"

health:
	@NO_COLOR=1 bash ./ir health
