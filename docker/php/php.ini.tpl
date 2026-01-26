; PHP INI Configuration Template
; Runtime settings can be overridden via environment variables

[PHP]
; Memory and execution
memory_limit = ${PHP_MEMORY_LIMIT:-128M}
max_execution_time = 300
max_input_time = 300
post_max_size = ${PHP_UPLOAD_LIMIT:-64M}
upload_max_filesize = ${PHP_UPLOAD_LIMIT:-64M}
max_file_uploads = 20

; Error handling
error_reporting = ${PHP_ERROR_REPORTING:-E_ALL & ~E_DEPRECATED & ~E_STRICT}
display_errors = ${PHP_DISPLAY_ERRORS:-0}
display_startup_errors = ${PHP_DISPLAY_STARTUP_ERRORS:-0}
log_errors = On
error_log = /var/log/php/error.log

; Date and timezone
date.timezone = ${PHP_TIMEZONE:-UTC}

; Session settings
session.gc_maxlifetime = 1440

; OPCache settings
opcache.enable=1
opcache.memory_consumption=128
opcache.interned_strings_buffer=8
opcache.max_accelerated_files=10000
opcache.revalidate_freq=2
opcache.validate_timestamps=1
opcache.save_comments=1

; File uploads
file_uploads = On
upload_tmp_dir = /tmp

; Basic functions
disable_functions = ${PHP_DISABLE_FUNCTIONS:-}
disable_classes = ${PHP_DISABLE_CLASSES:-}
