#!/usr/bin/env bash
# Run this on your Mac (not the VM) to test the stack locally, without Caddy/TLS.
# Kimai is reachable directly at http://localhost:8001 once containers are healthy.
set -euo pipefail

cd "$(dirname "$0")/.."

if [ ! -f .env ]; then
  echo "Missing .env -- copy .env.example to .env first (dummy values are fine locally)." >&2
  exit 1
fi

docker compose -f docker-compose.yml -f docker-compose.local.yml up -d sqldb kimai
docker compose -f docker-compose.yml -f docker-compose.local.yml ps

echo ""
echo "Waiting for Kimai to become reachable on http://localhost:8001 ..."
for i in $(seq 1 30); do
  if curl -fs -o /dev/null "http://localhost:8001/en/login"; then
    echo "Up. Visit: http://localhost:8001"
    exit 0
  fi
  sleep 2
done

echo "Not reachable yet -- check logs with:"
echo "  docker compose -f docker-compose.yml -f docker-compose.local.yml logs kimai --tail=100"
