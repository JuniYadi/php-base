# Runtime Supervision and Health Checks

This image runs `php-fpm` and `nginx` under `supervisord`.

## Process model

- `docker-entrypoint.sh` generates runtime config from environment variables.
- `/usr/local/bin/start.sh` starts `supervisord` in foreground mode.
- `supervisord` manages:
  - `php-fpm` via `/etc/supervisor.d/php-fpm.conf`
  - `nginx` via `/etc/supervisor.d/nginx.conf`
- Additional framework/app processes can be added with extra files in `/etc/supervisor.d/*.conf`.

## Why this model

- Single process manager for all long-running services.
- Unified restart behavior (`autorestart=true`) per program.
- Simpler framework integration (Laravel, WordPress, queue workers, schedulers) with one supervisor tree.

## Health check strategy

No Dockerfile `HEALTHCHECK` is enforced in base image by default.

Define health checks at deployment layer:

- Docker Compose `healthcheck`
- Kubernetes `livenessProbe` / `readinessProbe`
- Platform-specific probes (ECS, Nomad, etc.)

Typical probe targets:

- `127.0.0.1:9000` for `php-fpm`
- `127.0.0.1:80` for `nginx`
