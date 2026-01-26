#!/bin/bash
set -e

# ===============================================
# Multi-Version PHP Base Image Entrypoint
# ===============================================
# Configures PHP, PHP-FPM, and Nginx at runtime
# based on environment variables
# ===============================================

echo "=== PHP Base Image Entrypoint ==="
echo "PHP Version: $(php -r 'echo PHP_VERSION;')"

# ===============================================
# Helper: Check if extension is available
# ===============================================
is_extension_available() {
    local ext="$1"
    # Try to find the extension ini file
    find /usr/local/etc/php/conf.d -name "docker-php-ext-${ext}.ini" 2>/dev/null | grep -q . || \
    ls /usr/lib/php/*/extensions/*${ext}.so 2>/dev/null | grep -q . || \
    command -v php >/dev/null 2>&1 && php -m 2>/dev/null | grep -qi "^${ext}$"
}

# ===============================================
# Configure PHP Extensions
# ===============================================
configure_extensions() {
    echo "Configuring PHP extensions..."

    # List of optional extensions that can be enabled via ENV
    # Format: EXT_NAME (env var: PHP_EXT_NAME)
    local optional_exts="redis memcached imagick soap ssh2 xsl xmlrpc yaml apcu opcache"

    for ext in $optional_exts; do
        local env_var="PHP_EXT_${ext^^}"
        local enabled="${!env_var:-0}"
        if [ "$enabled" = "1" ]; then
            if is_extension_available "$ext"; then
                echo "Enabling extension: $ext"
                docker-php-ext-enable "$ext" 2>/dev/null || {
                    # Manual enable for pecl extensions
                    local ext_so=$(find /usr/lib/php -name "*${ext}*.so" 2>/dev/null | head -1)
                    if [ -n "$ext_so" ]; then
                        echo "extension=${ext_so}" > "/usr/local/etc/php/conf.d/docker-php-ext-${ext}.ini"
                    fi
                }
            else
                echo "Warning: Extension $ext requested but not available"
            fi
        fi
    done

    # Disable extensions if requested
    local disabled_exts="${PHP_EXT_DISABLE:-}"
    if [ -n "$disabled_exts" ]; then
        for ext in $disabled_exts; do
            echo "Disabling extension: $ext"
            rm -f "/usr/local/etc/php/conf.d/docker-php-ext-${ext}.ini" 2>/dev/null || true
        done
    fi
}

# ===============================================
# Configure PHP INI Settings
# ===============================================
configure_php_ini() {
    echo "Configuring PHP INI settings..."

    local ini_file="/usr/local/etc/php/conf.d/zzz-runtime.ini"

    # Memory limit
    if [ -n "$PHP_MEMORY_LIMIT" ]; then
        echo "memory_limit = ${PHP_MEMORY_LIMIT}" >> "$ini_file"
    fi

    # Upload limit
    if [ -n "$PHP_UPLOAD_LIMIT" ]; then
        echo "upload_max_filesize = ${PHP_UPLOAD_LIMIT}" >> "$ini_file"
        echo "post_max_size = ${PHP_UPLOAD_LIMIT}" >> "$ini_file"
    fi

    # Timezone
    if [ -n "$PHP_TIMEZONE" ]; then
        echo "date.timezone = ${PHP_TIMEZONE}" >> "$ini_file"
    fi

    # Error reporting
    if [ -n "$PHP_ERROR_REPORTING" ]; then
        echo "error_reporting = ${PHP_ERROR_REPORTING}" >> "$ini_file"
    fi

    # Display errors
    if [ "$PHP_DISPLAY_ERRORS" = "1" ]; then
        echo "display_errors = On" >> "$ini_file"
        echo "display_startup_errors = On" >> "$ini_file"
    fi

    # Realpath cache TTL (performance)
    if [ -n "$PHP_REALPATH_CACHE_TTL" ]; then
        echo "realpath_cache_ttl = ${PHP_REALPATH_CACHE_TTL}" >> "$ini_file"
    fi

    # Additional custom INI settings
    if [ -n "$PHP_CUSTOM_INI" ]; then
        echo "$PHP_CUSTOM_INI" >> "$ini_file"
    fi

    echo "PHP INI configured successfully"
}

# ===============================================
# Configure PHP-FPM
# ===============================================
configure_php_fpm() {
    echo "Configuring PHP-FPM..."

    local fpm_conf="/usr/local/etc/php-fpm/php-fpm.conf"

    # Ensure base config exists
    if [ -f "/usr/local/etc/php-fpm/php-fpm.conf.tpl" ]; then
        # Process template if envsubst is available
        if command -v envsubst >/dev/null 2>&1; then
            envsubst < /usr/local/etc/php-fpm/php-fpm.conf.tpl > "$fpm_conf"
        else
            cp /usr/local/etc/php-fpm/php-fpm.conf.tpl "$fpm_conf"
        fi
    fi

    # Fallback: create minimal config if template doesn't exist
    if [ ! -f "$fpm_conf" ]; then
        cat > "$fpm_conf" << 'EOF'
[global]
daemonize = no
error_log = /var/log/php-fpm/error.log

[www]
listen = 127.0.0.1:9000
listen.owner = www-data
listen.group = www-data
listen.mode = 0660
EOF
    fi

    # Override settings from environment
    if [ -n "$PHP_MAX_CHILDREN" ]; then
        sed -i "s/^pm\.max_children =.*/pm.max_children = ${PHP_MAX_CHILDREN}/" "$fpm_conf"
    fi

    if [ -n "$PHP_START_SERVERS" ]; then
        sed -i "s/^pm\.start_servers =.*/pm.start_servers = ${PHP_START_SERVERS}/" "$fpm_conf"
    fi

    if [ -n "$PHP_MIN_SPARE_SERVERS" ]; then
        sed -i "s/^pm\.min_spare_servers =.*/pm.min_spare_servers = ${PHP_MIN_SPARE_SERVERS}/" "$fpm_conf"
    fi

    if [ -n "$PHP_MAX_SPARE_SERVERS" ]; then
        sed -i "s/^pm\.max_spare_servers =.*/pm.max_spare_servers = ${PHP_MAX_SPARE_SERVERS}/" "$fpm_conf"
    fi

    if [ -n "$PHP_MAX_REQUESTS" ]; then
        sed -i "s/^pm\.max_requests =.*/pm.max_requests = ${PHP_MAX_REQUESTS}/" "$fpm_conf"
    fi

    if [ -n "$PHP_REQUEST_TERMINATE_TIMEOUT" ]; then
        sed -i "s/^request_terminate_timeout =.*/request_terminate_timeout = ${PHP_REQUEST_TERMINATE_TIMEOUT}/" "$fpm_conf"
    fi

    # Create PHP-FPM run directory
    mkdir -p /var/run/php-fpm
    chown www-data:www-data /var/run/php-fpm

    echo "PHP-FPM configured successfully"
}

# ===============================================
# Configure Nginx
# ===============================================
configure_nginx() {
    echo "Configuring Nginx..."

    local nginx_conf="/etc/nginx/nginx.conf"

    if [ -n "$NGINX_WORKER_PROCESSES" ]; then
        sed -i "s/worker_processes.*auto;/worker_processes ${NGINX_WORKER_PROCESSES};/" "$nginx_conf"
    fi

    if [ -n "$NGINX_WORKER_CONNECTIONS" ]; then
        sed -i "s/worker_connections.*1024;/worker_connections ${NGINX_WORKER_CONNECTIONS};/" "$nginx_conf"
    fi

    if [ -n "$NGINX_CLIENT_BODY_BUFFER" ]; then
        sed -i "s/client_body_buffer_size.*128k;/client_body_buffer_size ${NGINX_CLIENT_BODY_BUFFER};/" "$nginx_conf"
    fi

    # Create required directories
    mkdir -p /var/log/nginx /var/run/nginx
    touch /var/log/nginx/access.log /var/log/nginx/error.log

    echo "Nginx configured successfully"
}

# ===============================================
# Ensure writable directories
# ===============================================
ensure_directories() {
    echo "Ensuring writable directories..."

    # Standard Laravel/Laravel-like directories
    local dirs="/var/www/html/storage/framework/cache \
                /var/www/html/storage/framework/sessions \
                /var/www/html/storage/framework/views \
                /var/www/html/storage/logs \
                /var/www/html/bootstrap/cache"

    for dir in $dirs; do
        mkdir -p "$dir" 2>/dev/null || true
    done

    # Set permissions
    chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache 2>/dev/null || true
    chown -R www-data:www-data /var/www/html 2>/dev/null || true
}

# ===============================================
# Run configurations
# ===============================================
echo "Starting configuration..."

configure_extensions
configure_php_ini
configure_php_fpm
configure_nginx
ensure_directories

echo "Configuration complete!"
echo "================================"

# Execute the main command
exec "$@"
