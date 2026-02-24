FROM ghcr.io/juniyadi/php-base:8.5

WORKDIR /var/www/html

COPY --chown=www-data:www-data . /var/www/html

ENV NGINX_DOCROOT=/var/www/html \
    NGINX_INDEX_FILES="index.php index.html" \
    NGINX_FRONT_CONTROLLER="/index.php?\$args" \
    PHP_MEMORY_LIMIT=256M \
    PHP_UPLOAD_LIMIT=64M \
    PHP_MAX_CHILDREN=10

EXPOSE 80

# Keep php-base ENTRYPOINT. Hand off to base process supervisor.
CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]
