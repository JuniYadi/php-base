# ===============================================
# Multi-Version PHP Base Image
# ===============================================
# Supports: PHP 7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5
# Build with: --build-arg PHP_VERSION=8.4
# ===============================================

# Build argument for PHP version
ARG PHP_VERSION=8.4

# ===============================================
# Stage 1: Base PHP Runtime
# ===============================================
# Contains PHP + all common extensions
# This layer is cached per PHP version
# ===============================================
FROM php:${PHP_VERSION}-fpm-alpine AS php-base

# Install build dependencies for extensions
RUN apk add --no-cache \
    curl \
    libzip-dev \
    libpng-dev \
    libjpeg-turbo-dev \
    freetype-dev \
    icu-dev \
    sqlite-dev \
    oniguruma-dev \
    unzip \
    zip \
    git \
    && rm -rf /var/cache/apk/*

# Configure GD with FreeType and JPEG support
RUN docker-php-ext-configure gd \
        --with-freetype \
        --with-jpeg

# Install core extensions (always enabled)
RUN docker-php-ext-install -j$(nproc) \
        pdo \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        mysqli \
        mbstring \
        gd \
        intl \
        zip \
        bcmath \
        sockets \
        json \
        xml \
        tokenizer \
        xmlwriter \
        fileinfo \
        opcache \
        oniguruma \
    && rm -rf /var/cache/apk/* \
    && rm -rf /tmp/*

# ===============================================
# Stage 2: Optional Extensions
# ===============================================
# These extensions are installed but disabled by default
# Enable via PHP_EXT_* environment variables at runtime
# ===============================================

# Redis extension
RUN apk add --no-cache \
        php84-pecl-redis \
    || apk add --no-cache \
        php83-pecl-redis \
    || apk add --no-cache \
        php82-pecl-redis \
    || apk add --no-cache \
        php81-pecl-redis \
    || apk add --no-cache \
        php80-pecl-redis \
    || apk add --no-cache \
        php74-pecl-redis \
    || true

# Memcached extension
RUN apk add --no-cache \
        php84-pecl-memcached \
    || apk add --no-cache \
        php83-pecl-memcached \
    || apk add --no-cache \
        php82-pecl-memcached \
    || apk add --no-cache \
        php81-pecl-memcached \
    || apk add --no-cache \
        php80-pecl-memcached \
    || apk add --no-cache \
        php74-pecl-memcached \
    || true

# Create extension configuration directories
RUN mkdir -p /usr/local/etc/php/conf.d \
             /usr/local/etc/php-fpm.d

# Copy configuration templates
COPY docker/php/php.ini.tpl /usr/local/etc/php/php.ini.tpl
COPY docker/php/php-fpm.conf.tpl /usr/local/etc/php-fpm/php-fpm.conf.tpl

# ===============================================
# Stage 3: Runtime Image
# ===============================================
# Production-ready image with Nginx and supervisor
# ===============================================
FROM php-base AS php-runtime

# Install runtime dependencies
RUN apk add --no-cache \
    nginx \
    supervisor \
    curl \
    ca-certificates \
    bash \
    && rm -rf /var/cache/apk/*

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
RUN addgroup -g 1000 -S www-data && \
    adduser -u 1000 -S www-data -G www-data

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
LABEL org.opencontainers.image.title="PHP ${PHP_VERSION} Base Image" \
      org.opencontainers.image.description="Multi-version PHP runtime with configurable extensions and Nginx" \
      org.opencontainers.image.version="${PHP_VERSION}" \
      maintainer="juniyadi" \
      php.version="${PHP_VERSION}"
