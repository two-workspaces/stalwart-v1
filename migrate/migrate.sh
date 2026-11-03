#!/bin/sh
# Copies the 0.16.27 store into a new 1.0 store and switches the volume over. The
# 0.16 store is kept as /data/data-0.16 and /data/etc-0.16. Stops at the first
# failure, before the switch, so a failed run leaves the 0.16 store in place.
set -eu
state=/var/lib/stalwart-migrate
if [ -e /data/etc/.stalwart-v1-store ]; then echo "already migrated: deploy the normal wrapper."; exit 0; fi
# A run that stopped early leaves a partial target and state behind; start over.
rm -rf /data/data-v1/* /data/etc-v1/* "$state"/*
cp /answers.toml "$state/answers.toml"
echo '{"@type":"RocksDb","path":"/var/lib/stalwart-v1/"}' > /etc/stalwart-v1/config.json

echo "== prepare"
stalwart-migrate prepare --non-interactive --source /etc/stalwart/config.json --state "$state" > "$state/prepare.out" 2>&1 || {
  grep -vE '^\{"timestamp"' "$state/prepare.out" | busybox tail -30; exit 1; }
grep -E '^Summary|^Every question' "$state/prepare.out"

echo "== final copy"
stalwart-migrate run --final --yes --source /etc/stalwart/config.json \
  --target /etc/stalwart-v1/config.json --state "$state" > "$state/run.out" 2>&1 || {
  grep -vE '^\{"timestamp"' "$state/run.out" | busybox tail -30; exit 1; }
grep -E '^run [0-9]+:|^verify:' "$state/run.out" | cut -c1-300

echo "== first boot on v1.0.1"
kill "$HEALTH_PID" 2>/dev/null || true
sleep 1
stalwart-v1.0.1 --config /etc/stalwart-v1/config.json > "$state/v1.0.1.log" 2>&1 &
server=$!
tries=0
until busybox wget -q -O /dev/null http://127.0.0.1:8080/healthz/live 2>/dev/null; do
  tries=$((tries + 1))
  if [ "$tries" -gt 120 ]; then
    kill "$server" 2>/dev/null || true
    echo "v1.0.1 did not come up, nothing was switched:"
    grep -E 'ERROR|Failed' "$state/v1.0.1.log" | busybox tail -10 | cut -c1-200
    exit 1
  fi
  sleep 1
done
echo "v1.0.1 up after ${tries}s"
sleep 10
kill "$server"; wait "$server" || true

echo "== switching the volume"
cd /data
mv data data-0.16
mv etc etc-0.16
mv data-v1 data
mv etc-v1 etc
sed -i 's#/var/lib/stalwart-v1/#/var/lib/stalwart/#' /data/etc/config.json
touch /data/etc/.stalwart-v1-store
echo "done: deploy the normal wrapper now."
