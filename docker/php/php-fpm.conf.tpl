[global]
; Daemon configuration
daemonize = no
error_log = /var/log/php-fpm/error.log
log_level = notice
emergency_restart_interval = ${PHP_EMERGENCY_RESTART_INTERVAL}
include = /usr/local/etc/php-fpm.d/*.conf
