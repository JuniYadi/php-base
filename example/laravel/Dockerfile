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

COPY --from=vendor --chown=www-data:www-data /app /var/www/html

ENV APP_ENV=production \
    APP_DEBUG=false \
    NGINX_DOCROOT=/var/www/html/public \
    NGINX_FRONT_CONTROLLER="/index.php?\$query_string" \
    PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_LIMIT=64M \
    APP_BOOTSTRAP_CMD="php artisan migrate --force && php artisan config:cache || true && php artisan route:cache || true && php artisan view:cache || true"

EXPOSE 80

# Keep php-base ENTRYPOINT. Hand off to base process supervisor.
CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]
