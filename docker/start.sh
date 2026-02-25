#!/bin/sh
set -e

# Thin launcher for the base process manager.
SUPERVISORD_BIN="${SUPERVISORD_BIN:-supervisord}"
SUPERVISORD_CONF="${SUPERVISORD_CONF:-/etc/supervisor/supervisord.conf}"

mkdir -p /var/log/supervisor /var/run /etc/supervisor.d

exec "$SUPERVISORD_BIN" -n -c "$SUPERVISORD_CONF"
