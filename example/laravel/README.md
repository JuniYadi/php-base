# Laravel Integration Example

This example shows how to run a Laravel app on `ghcr.io/juniyadi/php-base` without `ENTRYPOINT`/`CMD` conflicts.

## Startup Contract

- Do not override `ENTRYPOINT`.
- Keep base runtime setup by using the image default entrypoint: `/usr/local/bin/docker-entrypoint.sh`.
- Put framework boot logic in `APP_BOOTSTRAP_CMD`.
- Keep runtime process management on `/usr/local/bin/start.sh`.

## Why Laravel Needs `NGINX_DOCROOT=/var/www/html/public`

Laravel serves `index.php` from `public/`.  
Set `NGINX_DOCROOT=/var/www/html/public` so static files and front controller routing are correct.

## Dockerfile Notes

The example `Dockerfile` uses:

- Multi-stage Composer install (`composer:2.8`) to keep final image smaller.
- Base runtime from `ghcr.io/juniyadi/php-base:8.5`.
- `APP_BOOTSTRAP_CMD` for one-time startup tasks:
  - `php artisan migrate --force`
  - `php artisan config:cache`
  - `php artisan route:cache`
  - `php artisan view:cache`
- `CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]` to run PHP-FPM + Nginx under base supervisor.

## Minimal docker-compose Example

```yaml
services:
  app:
    build:
      context: .
      dockerfile: example/laravel/Dockerfile
    ports:
      - "8080:80"
    environment:
      APP_ENV: production
      APP_DEBUG: "false"
      DB_CONNECTION: mysql
      DB_HOST: db
      DB_PORT: "3306"
      DB_DATABASE: laravel
      DB_USERNAME: laravel
      DB_PASSWORD: secret
    depends_on:
      - db

  db:
    image: mysql:8.4
    environment:
      MYSQL_DATABASE: laravel
      MYSQL_USER: laravel
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root
```

## Common Mistakes

- Overriding `ENTRYPOINT` in child image.
- Starting `php-fpm` and `nginx` directly in app `CMD` instead of delegating to `start.sh`.
- Leaving Laravel on default docroot (`/var/www/html`) which causes wrong entrypoint pathing.
