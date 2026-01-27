# Health Checks and Crash Detection

This document describes the health monitoring, crash detection, and auto-restart features in the docker-php image.

## Overview

The `start.sh` script acts as a supervisor for PHP-FPM and Nginx with the following features:

- **Health Checks**: Regular monitoring of PHP-FPM and Nginx processes
- **Crash Detection**: Automatic detection when services fail
- **Auto-Restart**: Automatic restart of crashed services (configurable)
- **Graceful Shutdown**: Proper signal handling for container stop requests
- **Logging**: Colored, timestamped log output

## Health Check Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `HEALTH_CHECK_INTERVAL` | `5` | Seconds between health checks |
| `MAX_RESTARTS` | `3` | Maximum restart attempts per service |
| `RESTART_DELAY` | `2` | Seconds to wait between restart attempts |
| `PHP_FPM_BIN` | `php-fpm` | PHP-FPM binary path |
| `NGINX_BIN` | `nginx` | Nginx binary path |

### Example Configuration

```bash
# Configure health checks
docker run -e HEALTH_CHECK_INTERVAL=10 \
           -e MAX_RESTARTS=5 \
           -e RESTART_DELAY=3 \
           my-php-image
```

## How It Works

### Startup Sequence

1. Creates required directories for PID files and logs
2. Starts PHP-FPM in daemon mode
3. Waits for PHP-FPM to be healthy (up to 30 seconds)
4. Starts Nginx in background
5. Waits for Nginx to be healthy (up to 30 seconds)
6. Enters main supervision loop

### Supervision Loop

Every `HEALTH_CHECK_INTERVAL` seconds, the script checks:

1. **PHP-FPM Health**:
   - PID file exists and process is running
   - PHP-FPM configuration test passes

2. **Nginx Health**:
   - PID file exists and process is running
   - HTTP response from localhost:80

### Crash Response

If a service is detected as unhealthy:

1. Check if restart count is below `MAX_RESTARTS`
2. Clean up stale PID file
3. Restart the service
4. Wait for service to be healthy
5. Log success or failure

## Graceful Shutdown

When the container receives SIGTERM or SIGINT:

1. **Nginx Shutdown**:
   - Sends SIGTERM to Nginx
   - Waits up to 30 seconds for graceful exit
   - Sends SIGKILL if not exited

2. **PHP-FPM Shutdown**:
   - Sends SIGQUIT to PHP-FPM for graceful shutdown
   - Waits up to 30 seconds for graceful exit
   - Sends SIGKILL if not exited

This ensures:
- Nginx stops accepting new connections first
- PHP-FPM finishes processing current requests
- No data corruption from abrupt termination

## Log Output

Logs are colored and timestamped for easy reading:

```
[INFO] 2024-01-15 10:30:45 - Starting PHP-FPM and Nginx supervisor...
[INFO] 2024-01-15 10:30:45 - Crash detection enabled (interval: 5s)
[INFO] 2024-01-15 10:30:45 - Max restarts allowed: 3 per service
[INFO] 2024-01-15 10:30:45 - Starting PHP-FPM...
[INFO] 2024-01-15 10:30:47 - All services started successfully
[WARN] 2024-01-15 10:35:12 - PHP-FPM crashed, restarting...
[INFO] 2024-01-15 10:35:14 - PHP-FPM restarted successfully
[ERROR] 2024-01-15 10:40:00 - PHP-FPM crashed too many times (3/3), giving up
```

## PID Files

The script manages PID files for both services:

| Service | PID File | Description |
|---------|----------|-------------|
| PHP-FPM | `/var/run/php-fpm.pid` | PHP-FPM master process PID |
| Nginx | `/var/run/nginx.pid` | Nginx master process PID |

These files are used for:
- Checking if services are running
- Sending signals for shutdown/restart
- Detecting crashed services

## Troubleshooting

### Service Won't Start

1. Check if ports are already in use
2. Verify configuration: `php-fpm -t` and `nginx -t`
3. Check logs for errors

### Too Many Restarts

If you see "crashed too many times":

1. Check application logs for the root cause
2. Increase `MAX_RESTARTS` for debugging
3. Check resource limits (memory, CPU)

### Health Checks Failing

1. Verify services are actually running: `ps aux`
2. Check PID files exist: `ls -la /var/run/*.pid`
3. Test manually: `curl http://localhost:80/`

## Disabling Crash Detection

To disable auto-restart (for debugging):

```bash
docker run -e MAX_RESTARTS=0 my-php-image
```

With `MAX_RESTARTS=0`, crashed services will not be restarted and the error will be logged but execution will continue.

## Integration with Container Orchestration

### Docker Healthcheck

You can use Docker's healthcheck feature alongside this script:

```dockerfile
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:80/ || exit 1
```

### Kubernetes Probes

For Kubernetes deployments:

```yaml
apiVersion: v1
kind: Pod
spec:
  containers:
  - name: php
    image: my-php-image
    livenessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 10
      periodSeconds: 10
    readinessProbe:
      httpGet:
        path: /
        port: 80
      initialDelaySeconds: 5
      periodSeconds: 5
```
