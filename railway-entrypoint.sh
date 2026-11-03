#!/bin/sh
# Stalwart persists two paths: /etc/stalwart holds config.json (the pointer to
# the store) and /var/lib/stalwart holds the RocksDB store itself — accounts,
# mail, and every setting made in the web UI. Railway allows one volume per
# service, so relocate both onto /data. Without this, a redeploy starts the
# server in bootstrap mode again and the previous mailboxes are gone.
set -e

# The image's WORKDIR is one of the paths replaced below; don't sit in it.
cd /

if [ -d /data ]; then
  for pair in etc:/etc/stalwart data:/var/lib/stalwart; do
    target="/data/${pair%%:*}"
    path="${pair#*:}"
    mkdir -p "$target"
    if [ ! -L "$path" ]; then
      # First boot: the image ships both paths empty, nothing to preserve.
      rm -rf "$path"
      ln -sfn "$target" "$path"
    fi
  done
fi

# Stalwart 1.0's setup wizard can't be reached on Railway. Until setup is done
# the admin page only trusts a client id whose scheme matches the connection,
# and Railway ends TLS before the container, so its sign-in fails with "Client
# metadata documents are disabled". Finish setup over loopback on the first boot
# instead; after that the server trusts its hostname and the admin page works.
# Only ever runs without a config.json, so it can't touch an existing store.
first_boot_setup() {
  port="${STALWART_RECOVERY_MODE_PORT:-8080}"
  domain="${STALWART_DEFAULT_DOMAIN:-$RAILWAY_PUBLIC_DOMAIN}"
  /usr/local/bin/stalwart "$@" &
  server=$!

  tries=0
  until curl -fsS -o /dev/null "http://127.0.0.1:$port/healthz/live" 2>/dev/null; do
    tries=$((tries + 1))
    if [ "$tries" -gt 60 ]; then break; fi
    sleep 1
  done

  # The response holds a generated password for admin@<domain>, so it stays out
  # of the logs unless the request failed. Sign in with STALWART_RECOVERY_ADMIN.
  body='{"using":["urn:ietf:params:jmap:core","urn:stalwart:jmap"],"methodCalls":[["x:Bootstrap/set",{"update":{"singleton":{"defaultHostname":"'"$RAILWAY_PUBLIC_DOMAIN"'","defaultDomain":"'"$domain"'","requestTlsCertificate":false,"generateDkimKeys":true,"tracer":{"@type":"Stdout","enable":true,"level":"info"}}}},"0"]]}'
  response=$(curl -sS -m 120 -u "$STALWART_RECOVERY_ADMIN" -H 'Content-Type: application/json' \
    -d "$body" "http://127.0.0.1:$port/jmap/" 2>&1) || true
  case "$response" in
    *'"updated":{"singleton"'*) echo "railway-entrypoint: first-boot setup done for $RAILWAY_PUBLIC_DOMAIN" ;;
    *) echo "railway-entrypoint: first-boot setup failed: $response" >&2 ;;
  esac

  kill "$server" 2>/dev/null || true
  wait "$server" 2>/dev/null || true
}

# Stalwart 1.0 can't open a 0.16 store, but it writes to the store before it
# refuses, and mail not yet flushed to disk is gone afterwards, even after going
# back to 0.16. So never start it on a store that isn't known to be 1.0: a store
# is marked when a fresh install creates it, or by hand after stalwart-migrate.
marker=/etc/stalwart/.stalwart-v1-store
if [ ! -s /etc/stalwart/config.json ]; then
  touch "$marker"
elif [ ! -e "$marker" ]; then
  echo "railway-entrypoint: this volume holds a Stalwart 0.16 store, which this version must not open." >&2
  echo "railway-entrypoint: not starting, and nothing was changed. Roll this service back to its previous deployment." >&2
  echo "railway-entrypoint: moving to 1.0 needs stalwart-migrate: https://github.com/stalwartlabs/stalwart-migrate" >&2
  exit 1
fi

if [ ! -s /etc/stalwart/config.json ] && [ -n "$RAILWAY_PUBLIC_DOMAIN" ] && [ -n "$STALWART_RECOVERY_ADMIN" ]; then
  first_boot_setup "$@"
fi

exec /usr/local/bin/stalwart "$@"
