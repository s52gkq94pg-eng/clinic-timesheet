#!/usr/bin/env bash
# Run this ON THE VM, from inside the cloned repo directory.
# Brings up (or updates) the Kimai stack. Safe to re-run: `docker compose up -d`
# only recreates containers whose config actually changed.
set -euo pipefail

if [ ! -f .env ]; then
  echo "Missing .env -- copy .env.example to .env and fill in real values first." >&2
  exit 1
fi

docker compose pull
docker compose up -d
docker compose ps

echo ""
echo "If this is the first run, wait ~30-60s for Kimai's DB migrations to finish, then visit:"
echo "  https://\$(grep ^DOMAIN .env | cut -d= -f2)"
echo "Log in with ADMIN_EMAIL / ADMIN_PASSWORD from .env, then immediately change the password"
echo "and create the real employee accounts."
