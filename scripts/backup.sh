#!/usr/bin/env bash
# Dumps the Kimai database to ./backups/. Run manually, or via cron
# (see docs/RUNBOOK.md for the crontab line). Keeps the last 14 backups.
set -euo pipefail
cd "$(dirname "$0")/.."

source .env
mkdir -p backups
STAMP="$(date +%Y%m%d-%H%M%S)"
FILE="backups/kimai-${STAMP}.sql.gz"

docker compose exec -T sqldb sh -c \
  "mysqldump -uroot -p\"\${MYSQL_ROOT_PASSWORD}\" ${DB_NAME}" | gzip > "${FILE}"

echo "Wrote ${FILE}"

# Prune old backups, keep last 14
ls -1t backups/kimai-*.sql.gz 2>/dev/null | tail -n +15 | xargs -r rm --
