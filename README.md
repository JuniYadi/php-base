# PHP Base Image

Multi-version PHP base image with Nginx, PHP-FPM, and configurable extensions. Published to GitHub Container Registry.

## Supported Versions

| PHP Version | Status | AMD64 | ARM64 |
|-------------|--------|-------|-------|
| 8.5 | Latest | ✅ | ✅ |
| 8.4 | Stable | ✅ | ✅ |
| 8.3 | Stable | ✅ | ✅ |
| 8.2 | Stable | ✅ | ✅ |
| 8.1 | Stable | ✅ | ✅ |
| 8.0 | EOL | ✅ | ❌ |
| 7.4 | EOL | ✅ | ❌ |

## Image Sizes

<!-- SIZE_TABLE_START -->
<!-- This section is auto-updated by CI. Do not edit manually. -->
<!-- SIZE_TABLE_END -->

## Quick Start

```bash
# Pull the latest PHP 8.4 image
docker pull ghcr.io/juniyadi/php-base:8.4

# Or use the latest tag
docker pull ghcr.io/juniyadi/php-base:latest
```

## Basic Usage

```dockerfile
FROM ghcr.io/juniyadi/php-base:8.4

# Copy your application
COPY . /var/www/html

# Your custom entrypoint if needed
COPY docker-entrypoint.sh /usr/local/bin/
```

## Environment Variables

### PHP-FPM Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MAX_CHILDREN` | 5 | Maximum number of child processes |
| `PHP_START_SERVERS` | 1 | Number of child processes created at startup |
| `PHP_MIN_SPARE_SERVERS` | 1 | Minimum number of idle server processes |
| `PHP_MAX_SPARE_SERVERS` | 3 | Maximum number of idle server processes |
| `PHP_MAX_REQUESTS` | 500 | Number of requests each child executes before respawning |

### PHP Runtime Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `PHP_MEMORY_LIMIT` | 128M | PHP memory limit |
| `PHP_UPLOAD_LIMIT` | 64M | Maximum upload file size |
| `PHP_TIMEZONE` | UTC | PHP timezone |
| `PHP_ERROR_REPORTING` | E_ALL & ~E_DEPRECATED & ~E_STRICT | Error reporting level |
| `PHP_DISPLAY_ERRORS` | 0 | Display errors (1=enabled) |

### Extension Configuration

Enable optional extensions by setting environment variables to `1`:

```dockerfile
FROM ghcr.io/juniyadi/php-base:8.4

# Enable Redis extension
ENV PHP_EXT_REDIS=1

# Enable Memcached extension
ENV PHP_EXT_MEMCACHED=1

# Enable multiple extensions
ENV PHP_EXT_REDIS=1 \
    PHP_EXT_MEMCACHED=1 \
    PHP_EXT_IMAGICK=1
```

| Extension | ENV Variable | Notes |
|-----------|--------------|-------|
| Redis | `PHP_EXT_REDIS=1` | Requires `php-redis` package |
| Memcached | `PHP_EXT_MEMCACHED=1` | Requires `php-memcached` package |
| Imagick | `PHP_EXT_IMAGICK=1` | Requires `php-imagick` package |
| SOAP | `PHP_EXT_SOAP=1` | Built-in extension |
| SSH2 | `PHP_EXT_SSH2=1` | Requires `php-ssh2` package |
| YAML | `PHP_EXT_YAML=1` | Requires `php-yaml` package |

### Nginx Configuration

| Variable | Default | Description |
|----------|---------|-------------|
| `NGINX_WORKER_PROCESSES` | auto | Number of worker processes |
| `NGINX_WORKER_CONNECTIONS` | 1024 | Connections per worker |
| `NGINX_CLIENT_BODY_BUFFER` | 16k | Client body buffer size |
| `NGINX_TRUST_CLOUDFLARE` | 0 | Trust Cloudflare proxy IP ranges for real client IP extraction |
| `NGINX_DOCROOT` | `/var/www/html` | Nginx document root path |
| `NGINX_INDEX_FILES` | `index.php index.html` | Nginx index directives |
| `NGINX_FRONT_CONTROLLER` | `/index.php?$query_string` | Front controller fallback for `try_files` |

Default access logs are emitted as JSON to stdout, and security-block logs are emitted as JSON to stderr.

Dynamic routes can be overridden by mounting a custom file at:
- `/etc/nginx/snippets/dynamic-routes.conf`

Main app routing (`location /`) can be fully replaced by mounting:
- `/etc/nginx/snippets/main-location.conf`

Extra supervised processes can be added by mounting one or more files at:
- `/etc/supervisor.d/*.conf`

Control optional supervisord startup:
- `ENABLE_SUPERVISORD=auto` (default: start only if `/etc/supervisor.d/*.conf` exists)
- `ENABLE_SUPERVISORD=0` (disable)
- `ENABLE_SUPERVISORD=1` (force enable when configs are present)

### Startup Contract

- Keep base `ENTRYPOINT` (`/usr/local/bin/docker-entrypoint.sh`) unchanged.
- Use `CMD` for app startup behavior and always hand off to `/usr/local/bin/start.sh`.
- Optional bootstrap tasks can be executed with `APP_BOOTSTRAP_CMD`.

Example:

```dockerfile
ENV APP_BOOTSTRAP_CMD="php artisan config:cache || true"
CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]
```

### Framework Integration Guides

- Laravel: `example/laravel/README.md`
- WordPress: `example/wordpress/README.md`

### Startup Regression Testing

Run startup regression tests locally against a built image:

```bash
docker build --build-arg PHP_VERSION=8.5 --build-arg BASE_IMAGE=alpine -t php-base:test-8.5-alpine .
./tests/startup-regression.sh php-base:test-8.5-alpine
```

CI also runs this suite for `8.5-alpine` and `8.5-debian` on pull requests.

## Docker Compose Example

```yaml
version: '3.8'

services:
  app:
    image: ghcr.io/juniyadi/php-base:8.4
    ports:
      - "8080:80"
    environment:
      - PHP_MAX_CHILDREN=10
      - PHP_MEMORY_LIMIT=256M
      - PHP_UPLOAD_LIMIT=128M
      - PHP_TIMEZONE=America/New_York
      - PHP_EXT_REDIS=1
    volumes:
      - ./:/var/www/html
    working_dir: /var/www/html

  redis:
    image: redis:7-alpine
```

## Laravel Example

```dockerfile
FROM ghcr.io/juniyadi/php-base:8.4

# Install Composer
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer

WORKDIR /var/www/html

# Copy composer files
COPY composer.json composer.lock ./

# Install dependencies
RUN composer install --no-dev --optimize-autoloader

# Copy application
COPY . .

# Configure Laravel
ENV APP_ENV=production \
    APP_DEBUG=false \
    PHP_MAX_CHILDREN=10 \
    NGINX_DOCROOT=/var/www/html/public \
    APP_BOOTSTRAP_CMD="php artisan migrate --force && php artisan config:cache || true"

EXPOSE 80

CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]
```

## WordPress Example

```dockerfile
FROM ghcr.io/juniyadi/php-base:8.4

WORKDIR /var/www/html
COPY . /var/www/html

# WordPress works with base defaults. Optional explicit fallback:
ENV NGINX_INDEX_FILES="index.php index.html" \
    NGINX_FRONT_CONTROLLER="/index.php?$args"

CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]
```

## Installed Extensions

### Core Extensions (Always Enabled)
- `pdo`, `pdo_mysql`, `pdo_pgsql`, `pdo_sqlite`
- `mysqli`, `mbstring`, `gd`, `intl`, `zip`
- `bcmath`, `sockets`, `json`, `xml`, `tokenizer`
- `xmlwriter`, `fileinfo`, `opcache`

### Optional Extensions (Enable via ENV)
- `redis`, `memcached`, `imagick`, `soap`
- `ssh2`, `xsl`, `xmlrpc`, `yaml`, `apcu`

## Multi-Architecture Support

All images are **multi-arch** (AMD64 + ARM64) - Docker automatically pulls the correct architecture for your machine.

```bash
# Works on both AMD64 and ARM64 machines
docker pull ghcr.io/juniyadi/php-base:8.5
```

### Available Tags

#### Multi-Arch Tags (Recommended)
These tags work on ALL machines - Docker selects the correct architecture automatically.

| Tag | Base | Description |
|-----|------|-------------|
| `8.5`, `latest` | Debian | PHP 8.5 (default, glibc compatible) |
| `8.5-alpine` | Alpine | PHP 8.5 (minimal, musl) |
| `8.4` | Alpine | PHP 8.4 |
| `8.3` | Alpine | PHP 8.3 |
| `8.2` | Alpine | PHP 8.2 |

#### Explicit Architecture Tags
Pull specific architecture when needed.

| Tag | Base | Arch | Description |
|-----|------|------|-------------|
| `8.5-amd64` | Debian | AMD64 | PHP 8.5 AMD64 only |
| `8.5-arm64` | Debian | ARM64 | PHP 8.5 ARM64 only |
| `8.5-alpine-amd64` | Alpine | AMD64 | PHP 8.5 Alpine AMD64 |
| `8.5-alpine-arm64` | Alpine | ARM64 | PHP 8.5 Alpine ARM64 |

### Tag Priorities

| Pull Command | What You Get |
|--------------|--------------|
| `php-base:8.5` | 8.5 Debian multi-arch |
| `php-base:8.5-alpine` | 8.5 Alpine multi-arch |
| `php-base:8.5-amd64` | 8.5 Debian AMD64 only |
| `php-base:latest` | 8.5 Debian multi-arch |

## Building Locally

```bash
# Build single version
make build PHP_VERSION=8.4

# Build all versions
make build-all

# Test built image
make test PHP_VERSION=8.4

# Open shell
make shell PHP_VERSION=8.4
```

## Publishing

Images are automatically published to GitHub Container Registry on:

1. Push to `main` branch
2. New git tags (e.g., `v8.4.0`)
3. Weekly schedule (for security updates)
4. Manual dispatch via GitHub Actions

## License

MIT License
