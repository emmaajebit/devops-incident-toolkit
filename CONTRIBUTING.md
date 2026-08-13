# Contributing to DevOps Incident Toolkit

Thanks for helping improve this toolkit!

## How to Contribute

1. Fork the repo
2. Create a feature branch: `git checkout -b feature/your-improvement`
3. Make your changes
4. Test on a real or simulated incident if possible
5. Submit a pull request

## What We're Looking For

- New diagnostic scripts for other platforms (GCP, Azure, bare metal)
- Improvements to existing scripts (better output parsing, more checks)
- Documentation enhancements
- Edge case handling
- Performance improvements

## Script Guidelines

- Always include a header comment explaining purpose
- Use color-coded output: GREEN for OK, YELLOW for warning, RED for critical
- Add `--help` flag support
- Keep it read-only where possible (no destructive commands by default)
- Make output easy to read at 3 AM during an incident

## Testing

Before submitting, run:

```bash
./server_health.sh --help
./cpu_debug.sh
# etc.
```

## Questions?

Open an issue or reach out. Happy troubleshooting!