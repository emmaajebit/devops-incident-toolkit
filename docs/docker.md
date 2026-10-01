# Docker troubleshooting

Script: `scripts/docker_debug.sh [container]`

## Engine vs container

Treat these as two incidents until proven otherwise:

- Engine: `docker info` errors, `overlay2` disk full, dockerd down, cgroup driver mismatch.
- Container: restart loop, OOMKilled, broken healthcheck, bad env, port not published.

## Restart loops

```text
docker inspect --format 'oom={{.State.OOMKilled}} exit={{.State.ExitCode}} health={{.State.Health.Status}}'
docker logs --tail 80 <name>
```

The toolkit prints those fields when you pass a container name.

Exit `137` is almost always SIGKILL (OOM or an operator). Exit `1`/`2` is the application.

## Disk

`docker system df` before you prune. The json-file log driver without `max-size` is a frequent root-filesystem filler.
