# MySQL and MariaDB Support

This document describes MySQL and MariaDB support in the PHP Base Image.

## Summary

**YES**, MySQL and MariaDB extensions are **ENABLED BY DEFAULT** in all images.

## Enabled Extensions

The following MySQL/MariaDB extensions are installed and enabled by default:

### 1. **mysqli** - MySQL Improved Extension
- **Status**: ✅ Enabled by default
- **Purpose**: Direct MySQL/MariaDB connection
- **Use Case**: Legacy applications, direct MySQL operations

```php
<?php
$mysqli = new mysqli("localhost", "user", "password", "database");
if ($mysqli->connect_error) {
    die("Connection failed: " . $mysqli->connect_error);
}
echo "Connected successfully";
```

### 2. **pdo_mysql** - PDO Driver for MySQL
- **Status**: ✅ Enabled by default
- **Purpose**: Database abstraction layer
- **Use Case**: Modern applications, framework integration (Laravel, Symfony)

```php
<?php
$dsn = "mysql:host=localhost;dbname=database";
$pdo = new PDO($dsn, "user", "password");
echo "Connected successfully";
```

## Installation Details

These extensions are installed during the Docker image build process in the Dockerfile:

```dockerfile
RUN docker-php-ext-install -j$(nproc) \
        pdo_mysql \
        pdo_pgsql \
        pdo_sqlite \
        mysqli \
        curl
```

## No Configuration Required

Unlike optional extensions (redis, memcached, imagick), MySQL extensions:
- ❌ Do NOT require environment variables to enable
- ❌ Do NOT need `PHP_EXT_MYSQL=1` or similar
- ✅ Are available immediately when container starts
- ✅ Work with all supported PHP versions (7.4, 8.0, 8.1, 8.2, 8.3, 8.4, 8.5)

## Verification

To verify MySQL/MariaDB extensions are loaded:

```bash
# Check loaded extensions
docker run --rm ghcr.io/juniyadi/php-base:8.4 php -m | grep -i mysql

# Check specific extensions
docker run --rm ghcr.io/juniyadi/php-base:8.4 php -r "var_dump(extension_loaded('mysqli'));"
docker run --rm ghcr.io/juniyadi/php-base:8.4 php -r "var_dump(extension_loaded('pdo_mysql'));"
```

## Framework Compatibility

### Laravel
```php
// .env
DB_CONNECTION=mysql
DB_HOST=db
DB_PORT=3306
DB_DATABASE=laravel
DB_USERNAME=root
DB_PASSWORD=secret

// Works out of the box - no additional configuration needed
```

### Symfony
```yaml
# config/packages/doctrine.yaml
doctrine:
    dbal:
        driver: 'pdo_mysql'
        url: '%env(resolve:DATABASE_URL)%'

# Works out of the box - no additional configuration needed
```

### WordPress
```php
// wp-config.php
define('DB_NAME', 'wordpress');
define('DB_USER', 'root');
define('DB_PASSWORD', 'secret');
define('DB_HOST', 'db');
define('DB_CHARSET', 'utf8mb4');
define('DB_COLLATE', '');

// Works out of the box - no additional configuration needed
```

## MariaDB Compatibility

Both `mysqli` and `pdo_mysql` extensions work seamlessly with MariaDB:

```yaml
# docker-compose.yml
version: '3.8'

services:
  app:
    image: ghcr.io/juniyadi/php-base:8.4
    volumes:
      - ./:/var/www/html
    environment:
      - DB_HOST=mariadb
  
  mariadb:
    image: mariadb:11
    environment:
      MYSQL_ROOT_PASSWORD: secret
      MYSQL_DATABASE: myapp
```

## Troubleshooting

### Connection Issues

If you can't connect to MySQL/MariaDB:

1. **Check the extensions are loaded** (they should be):
   ```bash
   php -m | grep -i mysql
   ```

2. **Verify connectivity to database server**:
   ```bash
   # From inside the container
   ping db
   nc -zv db 3306
   ```

3. **Check credentials and permissions**:
   ```sql
   -- On your database server
   SELECT user, host FROM mysql.user WHERE user = 'your_username';
   GRANT ALL PRIVILEGES ON database_name.* TO 'your_username'@'%';
   FLUSH PRIVILEGES;
   ```

### Client Library Version

To check which MySQL client library is being used:

```bash
docker run --rm ghcr.io/juniyadi/php-base:8.4 php -r "echo mysqli_get_client_info();"
```

## Alternative Databases

This image also supports other databases out of the box:

- **PostgreSQL**: `pdo_pgsql` extension (enabled by default)
- **SQLite**: `pdo_sqlite` extension (enabled by default)

## Related Documentation

- [README.md](../README.md) - Full image documentation
- [Environment Variables](../README.md#environment-variables) - Runtime configuration
- [Docker Compose Example](../README.md#docker-compose-example) - Complete setup example
