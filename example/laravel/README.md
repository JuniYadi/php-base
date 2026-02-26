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
- A Laravel-specific override for `/etc/nginx/snippets/dynamic-routes.conf` to support Livewire and Flux routes.
- `APP_BOOTSTRAP_CMD` for one-time startup tasks:
  - `php artisan migrate --force`
  - `php artisan config:cache`
  - `php artisan route:cache`
  - `php artisan view:cache`
- `CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]` to run PHP-FPM + Nginx under base supervisor.

## Laravel Dynamic Routes Override

The Laravel example image replaces `/etc/nginx/snippets/dynamic-routes.conf` by default with:

```nginx
location ~ ^/livewire-[a-f0-9]+/ {
    try_files $uri $uri/ /index.php?$query_string;
}

location ~* ^/flux/flux(\.min)?\.(js|css)$ {
    expires off;
    try_files $uri $uri/ /index.php?$query_string;
}
```

This avoids routing issues where Nginx does not correctly forward Livewire and Flux requests to Laravel.

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

## Running Crontab (Laravel Scheduler)

If you want cron-based scheduler execution in the container, add a cron file like this:

```sh
# Create cron entry for Laravel scheduler
local cron_file="/etc/cron.d/laravel-scheduler"

# Create cron file
cat > "$cron_file" << 'EOF'
# Laravel Scheduler - Run every minute
* * * * * echo "Cron running at $(date)" && /usr/local/bin/php /var/www/html/artisan schedule:run --no-interaction -vvv 2>&1
EOF

# Set proper permissions for cron file
chmod 644 "$cron_file"
```

The base image now runs `cron` under `supervisord` by default, so files in `/etc/cron.d/` are picked up automatically.

## Common Mistakes

- Overriding `ENTRYPOINT` in child image.
- Starting `php-fpm` and `nginx` directly in app `CMD` instead of delegating to `start.sh`.
- Leaving Laravel on default docroot (`/var/www/html`) which causes wrong entrypoint pathing.
