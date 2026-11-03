#!/bin/sh
set -e
cd /
for pair in etc:/etc/stalwart data:/var/lib/stalwart etc-v1:/etc/stalwart-v1 data-v1:/var/lib/stalwart-v1 migrate-state:/var/lib/stalwart-migrate; do
  target="/data/${pair%%:*}"; path="${pair#*:}"
  mkdir -p "$target"
  if [ ! -L "$path" ]; then rm -rf "$path"; ln -sfn "$target" "$path"; fi
done

# Answers Railway's healthcheck, so the deployment stays up after the work is done.
mkdir -p /srv/healthz; echo ok > /srv/healthz/live
health() { busybox httpd -f -p "${PORT:-8080}" -h /srv & health_pid=$!; }
health
export HEALTH_PID=$health_pid

if [ "${STALWART_MIGRATE_ACTION:-migrate}" = revert ]; then
  /revert.sh || echo "revert failed"
else
  /migrate.sh || echo "migration failed: the 0.16 store is still in place"
fi

health
exec sleep infinity
