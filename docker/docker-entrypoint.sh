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
# Check OpenSSL Version and Availability
# ===============================================
check_openssl() {
    echo "Checking OpenSSL availability..."

    # Check if OpenSSL extension is loaded
    if php -r 'exit(extension_loaded("openssl") ? 0 : 1);' 2>/dev/null; then
        echo "✓ OpenSSL extension: LOADED"

        # Get OpenSSL version from PHP
        local openssl_version=$(php -r 'echo OPENSSL_VERSION_TEXT;' 2>/dev/null)
        echo "  Version: $openssl_version"

        # Check if OpenSSL version is relatively recent (check for known vulnerabilities)
        # OpenSSL 1.1.1+ and 3.0+ are considered secure
        local version_number=$(php -r 'echo OPENSSL_VERSION_NUMBER;' 2>/dev/null)
        local openssl_major=$(php -r 'echo (int)substr(OPENSSL_VERSION_TEXT, -9, 1);' 2>/dev/null)

        if [ "$openssl_major" -ge 3 ] 2>/dev/null; then
            echo "  Status: ✓ Modern (3.x series - latest security features)"
        elif php -r 'exit(version_compare(OPENSSL_VERSION_TEXT, "1.1.1", ">=") ? 0 : 1);' 2>/dev/null; then
            echo "  Status: ✓ Secure (1.1.1+ series)"
        else
            echo "  Status: ⚠ WARNING - OpenSSL version may be outdated"
            echo "  Recommendation: Update to OpenSSL 1.1.1+ or 3.0+"
        fi
    else
        echo "✗ OpenSSL extension: NOT LOADED"
        echo "  Impact: HTTPS requests, encryption, and signed JWT tokens will not work"
        echo "  Action: Install with 'docker-php-ext-install openssl' (usually in base image)"
    fi

    # Also check system OpenSSL binary
    if command -v openssl >/dev/null 2>&1; then
        local system_openssl=$(openssl version 2>/dev/null)
        echo "  System binary: $system_openssl"
    fi

    echo ""
}

check_openssl

# ===============================================
# Check and Warn About Security Overrides
# ===============================================
check_security_overrides() {
    echo "Checking security configuration overrides..."

    local has_override=0

    # Check PHP_DISABLE_FUNCTIONS override
    if [ -n "$PHP_DISABLE_FUNCTIONS" ]; then
        echo "⚠️  WARNING: PHP_DISABLE_FUNCTIONS override detected!"
        echo "   Value: $PHP_DISABLE_FUNCTIONS"
        echo "   Impact: Security restrictions may be reduced"
        echo "   Recommendation: Use default secure settings unless required"
        has_override=1
    fi

    # Check PHP_DISABLE_CLASSES override
    if [ -n "$PHP_DISABLE_CLASSES" ]; then
        echo "⚠️  WARNING: PHP_DISABLE_CLASSES override detected!"
        echo "   Value: $PHP_DISABLE_CLASSES"
        echo "   Impact: Class restrictions may be reduced"
        has_override=1
    fi

    # Check if dangerous functions are being re-enabled
    local default_dangerous="exec shell_exec system passthru proc_open popen"
    if [ -n "$PHP_DISABLE_FUNCTIONS" ]; then
        for func in $default_dangerous; do
            if echo "$PHP_DISABLE_FUNCTIONS" | grep -qv "$func"; then
                echo "🔴 SECURITY: '$func' has been ENABLED - Command execution is possible!"
            fi
        done
    else
        echo "✓ Default: Dangerous command execution functions are disabled"
    fi

    if [ "$has_override" -eq 1 ]; then
        echo ""
    fi
}

check_security_overrides

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
        : "${PHP_MAX_CHILDREN:=5}"
        : "${PHP_START_SERVERS:=1}"
        : "${PHP_MIN_SPARE_SERVERS:=1}"
        : "${PHP_MAX_SPARE_SERVERS:=3}"
        : "${PHP_MAX_REQUESTS:=500}"
        : "${PHP_EMERGENCY_RESTART_INTERVAL:=60s}"
        : "${PHP_EMERGENCY_RESTART_SIG:=SIGUSR1}"
        : "${PHP_REQUEST_TERMINATE_TIMEOUT:=300s}"

        export PHP_MAX_CHILDREN PHP_START_SERVERS PHP_MIN_SPARE_SERVERS \
               PHP_MAX_SPARE_SERVERS PHP_MAX_REQUESTS PHP_EMERGENCY_RESTART_INTERVAL \
               PHP_EMERGENCY_RESTART_SIG PHP_REQUEST_TERMINATE_TIMEOUT

        if command -v envsubst >/dev/null 2>&1; then
            envsubst '${PHP_MAX_CHILDREN} ${PHP_START_SERVERS} ${PHP_MIN_SPARE_SERVERS} ${PHP_MAX_SPARE_SERVERS} ${PHP_MAX_REQUESTS} ${PHP_EMERGENCY_RESTART_INTERVAL} ${PHP_EMERGENCY_RESTART_SIG} ${PHP_REQUEST_TERMINATE_TIMEOUT}' \
                < /usr/local/etc/php-fpm/php-fpm.conf.tpl > "$fpm_conf"
        else
            cp /usr/local/etc/php-fpm/php-fpm.conf.tpl "$fpm_conf"
            sed -i \
                -e "s|\${PHP_MAX_CHILDREN}|${PHP_MAX_CHILDREN}|g" \
                -e "s|\${PHP_START_SERVERS}|${PHP_START_SERVERS}|g" \
                -e "s|\${PHP_MIN_SPARE_SERVERS}|${PHP_MIN_SPARE_SERVERS}|g" \
                -e "s|\${PHP_MAX_SPARE_SERVERS}|${PHP_MAX_SPARE_SERVERS}|g" \
                -e "s|\${PHP_MAX_REQUESTS}|${PHP_MAX_REQUESTS}|g" \
                -e "s|\${PHP_EMERGENCY_RESTART_INTERVAL}|${PHP_EMERGENCY_RESTART_INTERVAL}|g" \
                -e "s|\${PHP_EMERGENCY_RESTART_SIG}|${PHP_EMERGENCY_RESTART_SIG}|g" \
                -e "s|\${PHP_REQUEST_TERMINATE_TIMEOUT}|${PHP_REQUEST_TERMINATE_TIMEOUT}|g" \
                "$fpm_conf"
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

    # Create PHP-FPM run directory
    mkdir -p /var/run/php-fpm
    chown www-data:www-data /var/run/php-fpm

    # Fail fast if generated config is invalid.
    php-fpm -t -y "$fpm_conf"

    echo "PHP-FPM configured successfully"
}

# ===============================================
# Configure Nginx
# ===============================================
configure_nginx() {
    echo "Configuring Nginx..."

    local nginx_conf="/etc/nginx/nginx.conf"
    local cloudflare_conf="/etc/nginx/conf.d/proxy-trust-cloudflare.conf"
    local runtime_server_conf="/etc/nginx/snippets/runtime-server.conf"
    local main_location_conf="/etc/nginx/snippets/main-location.conf"
    local nginx_docroot="${NGINX_DOCROOT:-/var/www/html}"
    local nginx_index_files="${NGINX_INDEX_FILES:-index.php index.html}"
    local nginx_front_controller="${NGINX_FRONT_CONTROLLER:-/index.php?\$query_string}"

    case "$nginx_docroot" in
        *';'*|*$'\r'*|*$'\n'*)
            echo "ERROR: NGINX_DOCROOT contains invalid characters"
            exit 1
            ;;
    esac

    case "$nginx_index_files" in
        *';'*|*$'\r'*|*$'\n'*)
            echo "ERROR: NGINX_INDEX_FILES contains invalid characters"
            exit 1
            ;;
    esac

    case "$nginx_front_controller" in
        *';'*|*$'\r'*|*$'\n'*)
            echo "ERROR: NGINX_FRONT_CONTROLLER contains invalid characters"
            exit 1
            ;;
    esac

    if [ -n "$NGINX_WORKER_PROCESSES" ]; then
        sed -i "s/worker_processes.*auto;/worker_processes ${NGINX_WORKER_PROCESSES};/" "$nginx_conf"
    fi

    if [ -n "$NGINX_WORKER_CONNECTIONS" ]; then
        sed -i "s/worker_connections.*1024;/worker_connections ${NGINX_WORKER_CONNECTIONS};/" "$nginx_conf"
    fi

    if [ -n "$NGINX_CLIENT_BODY_BUFFER" ]; then
        sed -i "s/client_body_buffer_size.*128k;/client_body_buffer_size ${NGINX_CLIENT_BODY_BUFFER};/" "$nginx_conf"
    fi

    if [ "${NGINX_TRUST_CLOUDFLARE:-0}" = "1" ]; then
        cat > "$cloudflare_conf" << 'EOF'
include /etc/nginx/snippets/proxy-trust-cloudflare.conf;
EOF
        echo "Cloudflare trusted proxies: enabled"
    else
        cat > "$cloudflare_conf" << 'EOF'
# Cloudflare trusted proxy list is disabled by default.
# Set NGINX_TRUST_CLOUDFLARE=1 to enable at runtime.
EOF
        echo "Cloudflare trusted proxies: disabled"
    fi

    cat > "$runtime_server_conf" << EOF
# Generated at container startup. Override via env vars:
# - NGINX_DOCROOT
# - NGINX_INDEX_FILES
root ${nginx_docroot};
index ${nginx_index_files};
EOF

    cat > "$main_location_conf" << EOF
# Generated at container startup. Override via NGINX_FRONT_CONTROLLER.
location / {
    try_files \$uri \$uri/ ${nginx_front_controller};
}
EOF

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

run_app_bootstrap() {
    if [ -n "${APP_BOOTSTRAP_CMD:-}" ]; then
        echo "Running APP_BOOTSTRAP_CMD..."
        sh -lc "$APP_BOOTSTRAP_CMD"
        echo "APP_BOOTSTRAP_CMD completed"
    fi
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
run_app_bootstrap

echo "Configuration complete!"
echo "================================"

# Execute the main command
exec "$@"
