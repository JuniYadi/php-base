# ===============================================
# Multi-Version PHP Base Image
# ===============================================
# Supports: PHP 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5
#
# Build Examples:
#   - Alpine:  docker build --build-arg BASE_IMAGE=alpine -t php:8.5-alpine .
#   - Debian:  docker build --build-arg BASE_IMAGE=debian -t php:8.5-debian .
#
# Optional Extensions (set to 0 to disable):
#   - --build-arg INSTALL_REDIS=0  (default: 1)
#   - --build-arg INSTALL_APCU=0   (default: 1)
#   - --build-arg INSTALL_YAML=0   (default: 1)
#
# Example - Disable Redis and YAML:
#   docker build --build-arg INSTALL_REDIS=0 --build-arg INSTALL_YAML=0 -t php:minimal .
# ===============================================

# Build arguments
ARG PHP_VERSION=8.5
ARG BASE_IMAGE=alpine  # Options: alpine, debian

# Optional PECL extensions (set to 0 to disable)
ARG INSTALL_REDIS=1
ARG INSTALL_APCU=1
ARG INSTALL_YAML=1

# ===============================================
# Stage 1: Base PHP Runtime
# ===============================================
# Alpine base (default - smaller footprint)
FROM php:${PHP_VERSION}-fpm-alpine AS php-base-alpine

# Debian base (better glibc compatibility)
FROM php:${PHP_VERSION}-fpm-bookworm AS php-base-debian

# Common base stage selector
FROM php-base-${BASE_IMAGE} AS php-base

# Propagate ARGs to ENV for use in this stage
ARG INSTALL_REDIS
ARG INSTALL_APCU
ARG INSTALL_YAML
ENV PHP_EXTENSIONS_REDIS=${INSTALL_REDIS}
ENV PHP_EXTENSIONS_APCU=${INSTALL_APCU}
ENV PHP_EXTENSIONS_YAML=${INSTALL_YAML}

# Install build dependencies based on base OS
ARG BASE_IMAGE
RUN if [ "${BASE_IMAGE}" = "debian" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            libcurl4-openssl-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
            libicu-dev libsqlite3-dev libpq-dev libonig-dev libxml2-dev libyaml-dev && \
        rm -rf /var/lib/apt/lists/* /tmp/*; \
    else \
        apk add --no-cache \
            curl-dev libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev \
            icu-dev sqlite-dev postgresql-dev oniguruma-dev linux-headers libxml2-dev yaml-dev && \
        rm -rf /var/cache/apk/* /tmp/*; \
    fi

# Configure GD with FreeType and JPEG support
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg

# Install core extensions (includes curl for Laravel HTTP client)
# Note: pdo, mbstring, xml are already available in PHP base images
RUN docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        mysqli \
        curl

RUN docker-php-ext-install -j$(nproc) \
        gd \
        intl \
        zip \
        bcmath

# Install remaining extensions
# Note: json, fileinfo, tokenizer are built into PHP 8.x core
RUN docker-php-ext-install sockets

# Install build dependencies for PECL extensions
RUN if [ "${BASE_IMAGE}" = "debian" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            autoconf gcc g++ make pkg-config && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        apk add --no-cache \
            autoconf gcc g++ make pkgconfig libc-dev; \
        rm -rf /var/cache/apk/*; \
    fi

# Install PECL extensions (Redis, APCu, YAML) - conditionally enabled
# Usage: --build-arg INSTALL_REDIS=0 to disable Redis, etc.
RUN set -e; \
    extensions=""; \
    if [ "${INSTALL_REDIS}" = "1" ]; then extensions="${extensions} redis"; fi; \
    if [ "${INSTALL_APCU}" = "1" ]; then extensions="${extensions} apcu"; fi; \
    if [ "${INSTALL_YAML}" = "1" ]; then extensions="${extensions} yaml"; fi; \
    if [ -n "${extensions}" ]; then \
        pecl install ${extensions} && \
        docker-php-ext-enable ${extensions}; \
    fi

# Remove build dependencies to reduce image size
RUN if [ "${BASE_IMAGE}" = "debian" ]; then \
        apt-get remove -y --purge autoconf gcc g++ make pkg-config && \
        apt-get autoremove -y && \
        rm -rf /var/lib/apt/lists/*; \
    else \
        apk del autoconf gcc g++ make pkgconfig libc-dev; \
        rm -rf /var/cache/apk/*; \
    fi

# Enable opcache (built into PHP 8.5 base image - use directives, not zend_extension)
RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/opcache.ini

# Create extension configuration directories
RUN mkdir -p /usr/local/etc/php/conf.d \
             /usr/local/etc/php-fpm.d

# Copy configuration templates
COPY docker/php/php.ini.tpl /usr/local/etc/php/php.ini.tpl
COPY docker/php/php-fpm.conf.tpl /usr/local/etc/php-fpm/php-fpm.conf.tpl
COPY docker/php/php-fpm-www.conf.tpl /usr/local/etc/php-fpm.d/www.conf.tpl

# ===============================================
# Stage 2: Runtime Image
# ===============================================
FROM php-base AS php-runtime

# Install runtime dependencies based on base OS
ARG BASE_IMAGE
RUN if [ "${BASE_IMAGE}" = "debian" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            nginx supervisor curl ca-certificates bash cron && \
        rm -rf /var/lib/apt/lists/* /tmp/*; \
    else \
        apk add --no-cache \
            nginx supervisor curl ca-certificates bash dcron && \
        ln -sf /usr/sbin/crond /usr/sbin/cron && \
        rm -rf /var/cache/apk/* /tmp/*; \
    fi

# Create directories
RUN mkdir -p /var/www/html \
             /var/log/supervisor \
             /etc/nginx/conf.d \
             /etc/nginx/http.d \
             /etc/nginx/snippets \
             /etc/supervisor \
             /etc/supervisor.d \
             /var/log/php \
             /var/run/php-fpm

# Copy nginx configuration
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/logging.conf /etc/nginx/conf.d/logging.conf
COPY docker/nginx/proxy-trust-cloudflare.conf /etc/nginx/conf.d/proxy-trust-cloudflare.conf
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf
COPY docker/nginx/snippets/ /etc/nginx/snippets/
COPY docker/supervisor/supervisord.conf /etc/supervisor/supervisord.conf
COPY docker/supervisor/php-fpm.conf /etc/supervisor.d/php-fpm.conf
COPY docker/supervisor/nginx.conf /etc/supervisor.d/nginx.conf
COPY docker/supervisor/cron.conf /etc/supervisor.d/cron.conf
COPY --from=composer:2 /usr/bin/composer /usr/local/bin/composer

# Copy startup scripts
COPY docker/docker-entrypoint.sh /usr/local/bin/docker-entrypoint.sh
COPY docker/start.sh /usr/local/bin/start.sh
RUN chmod +x /usr/local/bin/*.sh

# Create www-data user
RUN groupadd -g 1000 www-data 2>/dev/null || true && \
    useradd -u 1000 -g www-data -s /bin/bash -m www-data 2>/dev/null || true

# Set ownership
RUN chown -R www-data:www-data /var/www/html

# ===============================================
# Environment Variables (Runtime Configuration)
# ===============================================

# PHP-FPM Configuration
ENV PHP_MAX_CHILDREN=5 \
    PHP_START_SERVERS=1 \
    PHP_MIN_SPARE_SERVERS=1 \
    PHP_MAX_SPARE_SERVERS=3 \
    PHP_MAX_REQUESTS=500 \
    PHP_EMERGENCY_RESTART_INTERVAL=60s

# PHP Runtime Configuration
ENV PHP_MEMORY_LIMIT=128M \
    PHP_UPLOAD_LIMIT=64M \
    PHP_TIMEZONE=UTC \
    PHP_ERROR_REPORTING=E_ALL\ \&\ ~E_DEPRECATED\ \&\ ~E_STRICT \
    PHP_DISPLAY_ERRORS=0 \
    PHP_DISPLAY_STARTUP_ERRORS=0

# Nginx Configuration
ENV NGINX_WORKER_PROCESSES=auto \
    NGINX_WORKER_CONNECTIONS=1024 \
    NGINX_CLIENT_BODY_BUFFER=16k \
    NGINX_TRUST_CLOUDFLARE=0 \
    NGINX_DOCROOT=/var/www/html \
    NGINX_INDEX_FILES="index.php index.html" \
    NGINX_FRONT_CONTROLLER="/index.php?\$query_string"

# Optional pre-start app bootstrap command.
ENV APP_BOOTSTRAP_CMD=""

# Default ports
EXPOSE 80 443

# Entrypoint handles configuration at runtime
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]

# Default command starts PHP-FPM and Nginx
CMD ["/usr/local/bin/start.sh"]

# ===============================================
# Image Labels
# ===============================================
LABEL org.opencontainers.image.title="PHP ${PHP_VERSION}" \
      org.opencontainers.image.description="Multi-version PHP runtime with ${BASE_IMAGE} base" \
      org.opencontainers.image.version="${PHP_VERSION}" \
      maintainer="juniyadi" \
      php.version="${PHP_VERSION}" \
      base.image="${BASE_IMAGE}" \
      php.extensions.redis="${PHP_EXTENSIONS_REDIS}" \
      php.extensions.apcu="${PHP_EXTENSIONS_APCU}" \
      php.extensions.yaml="${PHP_EXTENSIONS_YAML}"
