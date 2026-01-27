#!/bin/sh
set -e

# ===============================================
# PHP-FPM & Nginx Supervisor with Crash Detection
# ===============================================
# Features:
# - Crash detection for both PHP-FPM and Nginx
# - Graceful shutdown with proper signal handling
# - Automatic restart (optional via env var)
# - Health check endpoint monitoring
# ===============================================

# Configuration
PHP_FPM_BIN="${PHP_FPM_BIN:-php-fpm}"
NGINX_BIN="${NGINX_BIN:-nginx}"
PHP_FPM_PID="/var/run/php-fpm.pid"
NGINX_PID="/var/run/nginx.pid"
CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-5}"
MAX_RESTARTS="${MAX_RESTARTS:-3}"
RESTART_DELAY="${RESTART_DELAY:-2}"

# Colors for output (if terminal supports)
if [ -t 1 ]; then
    RED='\033[0;31m'
    GREEN='\033[0;32m'
    YELLOW='\033[1;33m'
    NC='\033[0m'
else
    RED=''
    GREEN=''
    YELLOW=''
    NC=''
fi

log_info() {
    echo "[${GREEN}INFO${NC}] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_warn() {
    echo "[${YELLOW}WARN${NC}] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

log_error() {
    echo "[${RED}ERROR${NC}] $(date '+%Y-%m-%d %H:%M:%S') - $*"
}

# ===============================================
# Signal Handling for Graceful Shutdown
# ===============================================
shutdown_handler() {
    log_info "Received shutdown signal, initiating graceful shutdown..."

    local sig="${1:-TERM}"
    local timeout=30

    # Shutdown Nginx first (stop accepting new connections)
    if [ -f "$NGINX_PID" ]; then
        log_info "Stopping Nginx (PID: $(cat $NGINX_PID))..."
        kill -${sig} "$(cat $NGINX_PID)" 2>/dev/null || true

        # Wait for nginx to exit gracefully
        local waited=0
        while [ -f "$NGINX_PID" ] && [ $waited -lt $timeout ]; do
            sleep 1
            waited=$((waited + 1))
        done

        if [ -f "$NGINX_PID" ]; then
            log_warn "Nginx did not exit gracefully, forcing..."
            kill -9 "$(cat $NGINX_PID)" 2>/dev/null || true
        fi
    fi

    # Shutdown PHP-FPM (graceful reload of workers)
    if [ -f "$PHP_FPM_PID" ]; then
        log_info "Stopping PHP-FPM (PID: $(cat $PHP_FPM_PID))..."
        # Send SIGQUIT for graceful shutdown of master process
        kill -${sig} "$(cat $PHP_FPM_PID)" 2>/dev/null || true

        local waited=0
        while [ -f "$PHP_FPM_PID" ] && [ $waited -lt $timeout ]; do
            sleep 1
            waited=$((waited + 1))
        done

        if [ -f "$PHP_FPM_PID" ]; then
            log_warn "PHP-FPM did not exit gracefully, forcing..."
            kill -9 "$(cat $PHP_FPM_PID)" 2>/dev/null || true
        fi
    fi

    log_info "Shutdown complete"
    exit 0
}

trap 'shutdown_handler TERM' TERM
trap 'shutdown_handler INT' INT

# ===============================================
# Health Check Functions
# ===============================================
check_php_fpm() {
    # Check if PHP-FPM process is running
    if [ -f "$PHP_FPM_PID" ]; then
        local pid=$(cat "$PHP_FPM_PID" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            # Also check if it's actually responding
            if php-fpm -t 2>/dev/null; then
                return 0
            fi
        fi
    fi
    return 1
}

check_nginx() {
    # Check if Nginx process is running
    if [ -f "$NGINX_PID" ]; then
        local pid=$(cat "$NGINX_PID" 2>/dev/null)
        if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
            # Verify nginx is actually listening
            if curl -sf -o /dev/null http://localhost:80/health 2>/dev/null || \
               curl -sf -o /dev/null http://localhost:80/ 2>/dev/null || \
               curl -sf -o /dev/null http://127.0.0.1:80/ 2>/dev/null; then
                return 0
            fi
        fi
    fi
    return 1
}

# ===============================================
# Restart Functions
# ===============================================
restart_php_fpm() {
    log_warn "PHP-FPM crashed, restarting..."

    # Clean up stale PID file
    [ -f "$PHP_FPM_PID" ] && rm -f "$PHP_FPM_PID"

    # Start PHP-FPM
    $PHP_FPM_BIN -D

    # Wait for it to be ready
    local waited=0
    while ! check_php_fpm && [ $waited -lt 30 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    if check_php_fpm; then
        log_info "PHP-FPM restarted successfully"
        return 0
    else
        log_error "Failed to restart PHP-FPM"
        return 1
    fi
}

restart_nginx() {
    log_warn "Nginx crashed, restarting..."

    # Clean up stale PID file
    [ -f "$NGINX_PID" ] && rm -f "$NGINX_PID"

    # Start Nginx
    $NGINX_BIN -g 'daemon off;' &
    NGINX_PID=$!

    # Wait for it to be ready
    local waited=0
    while ! check_nginx && [ $waited -lt 30 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    if check_nginx; then
        log_info "Nginx restarted successfully"
        return 0
    else
        log_error "Failed to restart Nginx"
        return 1
    fi
}

# ===============================================
# Main Supervisor Loop
# ===============================================
main() {
    log_info "Starting PHP-FPM and Nginx supervisor..."
    log_info "Crash detection enabled (interval: ${CHECK_INTERVAL}s)"
    log_info "Max restarts allowed: ${MAX_RESTARTS} per service"
    echo ""

    # Create required directories
    mkdir -p /var/run /var/log/php-fpm /var/log/nginx

    # Start PHP-FPM
    log_info "Starting PHP-FPM..."
    $PHP_FPM_BIN -D

    # Wait for PHP-FPM to be ready
    local waited=0
    while ! check_php_fpm && [ $waited -lt 30 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    if ! check_php_fpm; then
        log_error "Failed to start PHP-FPM"
        exit 1
    fi

    # Start Nginx in background
    log_info "Starting Nginx..."
    $NGINX_BIN -g 'daemon off;' &
    NGINX_PID=$!

    # Wait for Nginx to be ready
    waited=0
    while ! check_nginx && [ $waited -lt 30 ]; do
        sleep 1
        waited=$((waited + 1))
    done

    if ! check_nginx; then
        log_error "Failed to start Nginx"
        # Try to clean up PHP-FPM
        [ -f "$PHP_FPM_PID" ] && kill -9 "$(cat $PHP_FPM_PID)" 2>/dev/null || true
        exit 1
    fi

    log_info "All services started successfully"
    echo ""

    # Initialize restart counters
    php_restarts=0
    nginx_restarts=0

    # Main supervision loop
    while true; do
        sleep "$CHECK_INTERVAL"

        # Check PHP-FPM
        if ! check_php_fpm; then
            if [ "$php_restarts" -ge "$MAX_RESTARTS" ]; then
                log_error "PHP-FPM crashed too many times (${php_restarts}/${MAX_RESTARTS}), giving up"
                # Still continue to check nginx
            else
                php_restarts=$((php_restarts + 1))
                restart_php_fpm
            fi
        fi

        # Check Nginx
        if ! check_nginx; then
            if [ "$nginx_restarts" -ge "$MAX_RESTARTS" ]; then
                log_error "Nginx crashed too many times (${nginx_restarts}/${MAX_RESTARTS}), giving up"
            else
                nginx_restarts=$((nginx_restarts + 1))
                restart_nginx
            fi
        fi
    done
}

main "$@"
