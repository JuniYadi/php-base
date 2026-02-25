[www]
; Process management
pm = dynamic
pm.max_children = ${PHP_MAX_CHILDREN}
pm.start_servers = ${PHP_START_SERVERS}
pm.min_spare_servers = ${PHP_MIN_SPARE_SERVERS}
pm.max_spare_servers = ${PHP_MAX_SPARE_SERVERS}
pm.max_requests = ${PHP_MAX_REQUESTS}

; Socket settings
listen = 127.0.0.1:9000
listen.owner = www-data
listen.group = www-data
listen.mode = 0660

; Process security
; Chroot and chdir for isolation
chroot =
chdir = /var/www/html

; User and group (set in Dockerfile for www-data)
user = www-data
group = www-data

; Process dump
; process.dumpable = no

; Access logging
; access.log = log/$pool.access.log
; access.format = "%R - %u %t \"%m %r\" %s"

; Slow logging
; slowlog = log/$pool.log.slow
; request_slowlog_timeout = 5s
; request_slowlog_trace_depth = 20

; Termination timeout
; Terminate request after this time - 0 means no limit
request_terminate_timeout = ${PHP_REQUEST_TERMINATE_TIMEOUT}

; Clear environment
clear_env = no

; Catch workers output
decorate_workers_output = no
catch_workers_output = yes
