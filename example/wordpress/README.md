# WordPress Integration Example

This example shows how to run WordPress on `ghcr.io/juniyadi/php-base` using standard WordPress webroot layout.

## Startup Contract

- Do not override `ENTRYPOINT`.
- Keep base runtime setup by using the image default entrypoint: `/usr/local/bin/docker-entrypoint.sh`.
- Keep runtime process management on `/usr/local/bin/start.sh`.

## Why WordPress Uses `/var/www/html`

WordPress typically serves from project root, not `/public`.  
Use:

- `NGINX_DOCROOT=/var/www/html`
- `NGINX_INDEX_FILES="index.php index.html"`
- `NGINX_FRONT_CONTROLLER="/index.php?$args"`

This enables permalink routing through `index.php`.

## Dockerfile Notes

The example `Dockerfile` uses:

- Base runtime from `ghcr.io/juniyadi/php-base:8.5`.
- Root web path at `/var/www/html`.
- Standard php-base startup handoff:
  - `CMD ["sh", "-lc", "exec /usr/local/bin/start.sh"]`

## Minimal docker-compose Example

```yaml
services:
  wordpress:
    build:
      context: .
      dockerfile: example/wordpress/Dockerfile
    ports:
      - "8080:80"
    environment:
      WORDPRESS_DB_HOST: db:3306
      WORDPRESS_DB_USER: wp
      WORDPRESS_DB_PASSWORD: secret
      WORDPRESS_DB_NAME: wordpress
    depends_on:
      - db

  db:
    image: mysql:8.4
    environment:
      MYSQL_DATABASE: wordpress
      MYSQL_USER: wp
      MYSQL_PASSWORD: secret
      MYSQL_ROOT_PASSWORD: root
```

## Optional Bootstrap Hook

If you need startup actions, use `APP_BOOTSTRAP_CMD` (for example, permission fixes or cache warmup).  
Do not replace `ENTRYPOINT`.

## Common Mistakes

- Overriding `ENTRYPOINT` in child image.
- Using Laravel docroot (`/var/www/html/public`) for WordPress.
- Replacing base startup with custom process launch scripts.
