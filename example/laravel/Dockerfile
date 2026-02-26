FROM composer:2.8 AS vendor

WORKDIR /app

COPY composer.json composer.lock ./
RUN composer install \
    --no-dev \
    --no-interaction \
    --no-progress \
    --prefer-dist \
    --optimize-autoloader

COPY . .
RUN rm -rf bootstrap/cache/*.php

FROM ghcr.io/juniyadi/php-base:8.5

WORKDIR /var/www/html

ENV APP_ENV=production \
    APP_DEBUG=false \
    NGINX_DOCROOT=/var/www/html/public \
    NGINX_FRONT_CONTROLLER="/index.php?\$query_string" \
    PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_LIMIT=64M \
    APP_BOOTSTRAP_CMD="php artisan config:cache || true && php artisan route:cache || true && php artisan view:cache || true"

COPY --chown=www-data:www-data . /var/www/html
COPY --from=vendor --chown=www-data:www-data /app /var/www/html

RUN su www-data -s /bin/sh -c 'composer dump-autoload --optimize' && \
    # Only set permissions on storage and bootstrap/cache for Laravel
    [ -d "/var/www/html/storage" ] && find /var/www/html/storage -type d -exec chmod 775 {} + && \
    [ -d "/var/www/html/storage" ] && find /var/www/html/storage -type f -exec chmod 664 {} + && \
    [ -d "/var/www/html/bootstrap/cache" ] && find /var/www/html/bootstrap/cache -type d -exec chmod 775 {} + && \
    [ -d "/var/www/html/bootstrap/cache" ] && find /var/www/html/bootstrap/cache -type f -exec chmod 664 {} + || true

EXPOSE 80

# Keep php-base ENTRYPOINT. Hand off to base process supervisor.
CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]
