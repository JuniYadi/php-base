# ===============================================
# Multi-Version PHP Base Image
# ===============================================
# Supports: PHP 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5
# Build with:
#   - Alpine:  docker build --build-arg BASE_IMAGE=alpine -t php:8.5-alpine .
#   - Debian:  docker build --build-arg BASE_IMAGE=debian -t php:8.5-debian .
# ===============================================

# Build arguments
ARG PHP_VERSION=8.5
ARG BASE_IMAGE=alpine  # Options: alpine, debian

# ===============================================
# Stage 1: Base PHP Runtime
# ===============================================
# Alpine base (default - smaller footprint)
FROM php:${PHP_VERSION}-fpm-alpine AS php-base-alpine

# Debian base (better glibc compatibility)
FROM php:${PHP_VERSION}-fpm-bookworm AS php-base-debian

# Common base stage selector
FROM php-base-${BASE_IMAGE} AS php-base

# Install build dependencies based on base OS
ARG BASE_IMAGE
RUN if [ "${BASE_IMAGE}" = "debian" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            libcurl4-openssl-dev libzip-dev libpng-dev libjpeg-dev libfreetype6-dev \
            libicu-dev libsqlite3-dev libpq-dev libonig-dev libxml2-dev && \
        rm -rf /var/lib/apt/lists/* /tmp/*; \
    else \
        apk add --no-cache \
            curl-dev libzip-dev libpng-dev libjpeg-turbo-dev freetype-dev \
            icu-dev sqlite-dev postgresql-dev oniguruma-dev linux-headers libxml2-dev && \
        rm -rf /var/cache/apk/* /tmp/*; \
    fi

# Configure GD with FreeType and JPEG support
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg

# Install core extensions (includes curl for Laravel HTTP client)
RUN docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        mysqli \
        curl

RUN docker-php-ext-install -j$(nproc) \
        mbstring \
        gd \
        intl \
        zip \
        bcmath

# Install core extensions individually to isolate build issues
# Note: json, fileinfo, tokenizer are built into PHP 8.x core
RUN docker-php-ext-install sockets
RUN docker-php-ext-install xml
RUN docker-php-ext-install xmlwriter

# Enable opcache (built into PHP 8.5 base image - use directives, not zend_extension)
RUN echo "opcache.enable=1" > /usr/local/etc/php/conf.d/opcache.ini

# Create extension configuration directories
RUN mkdir -p /usr/local/etc/php/conf.d \
             /usr/local/etc/php-fpm.d

# Copy configuration templates
COPY docker/php/php.ini.tpl /usr/local/etc/php/php.ini.tpl
COPY docker/php/php-fpm.conf.tpl /usr/local/etc/php-fpm/php-fpm.conf.tpl

# ===============================================
# Stage 2: Runtime Image
# ===============================================
FROM php-base AS php-runtime

# Install runtime dependencies based on base OS
ARG BASE_IMAGE
RUN if [ "${BASE_IMAGE}" = "debian" ]; then \
        apt-get update && apt-get install -y --no-install-recommends \
            nginx supervisor curl ca-certificates bash && \
        rm -rf /var/lib/apt/lists/* /tmp/*; \
    else \
        apk add --no-cache \
            nginx supervisor curl ca-certificates bash && \
        rm -rf /var/cache/apk/* /tmp/*; \
    fi

# Create directories
RUN mkdir -p /var/www/html \
             /var/log/supervisor \
             /etc/nginx/http.d \
             /etc/supervisor.d \
             /var/log/php \
             /var/run/php-fpm

# Copy nginx configuration
COPY docker/nginx/default.conf /etc/nginx/http.d/default.conf

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
    NGINX_CLIENT_BODY_BUFFER=16k

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
      base.image="${BASE_IMAGE}"
