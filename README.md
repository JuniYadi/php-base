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
    PHP_MAX_CHILDREN=10

# Build assets (if using Vite/Mix)
RUN npm ci && npm run build

EXPOSE 80

CMD ["sh", "-c", "php artisan config:cache && php-fpm -D && nginx -g 'daemon off;'"]
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

## Available Tags

| Tag | Description |
|-----|-------------|
| `8.5`, `latest` | PHP 8.5 (latest stable) |
| `8.4` | PHP 8.4 |
| `8.3` | PHP 8.3 |
| `8.2` | PHP 8.2 |
| `8.1` | PHP 8.1 |
| `8.0` | PHP 8.0 (EOL) |
| `7.4` | PHP 7.4 (EOL) |
| `8.5-amd64` | PHP 8.5 (AMD64 only) |
| `8.5-arm64` | PHP 8.5 (ARM64 only) |

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
