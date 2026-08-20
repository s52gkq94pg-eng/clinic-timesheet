# Runbook

## Backups

There's no managed DB here -- MariaDB lives entirely on the VM's disk, so
back it up yourself.

```bash
./scripts/backup.sh
```

Writes a gzipped SQL dump to `backups/` and keeps the last 14. To automate:

```bash
crontab -e
# add: run nightly at 2am
0 2 * * * /home/<you>/clinic-timesheet/scripts/backup.sh >> /home/<you>/backup.log 2>&1
```

`backups/` is gitignored -- these files contain real data and should never
be committed. Periodically copy them off the VM (e.g. `gcloud compute scp`
to your Mac, or sync to a GCS bucket) so a lost/corrupted disk doesn't take
your only copy with it.

## Restoring from a backup

```bash
gunzip -c backups/kimai-YYYYMMDD-HHMMSS.sql.gz | \
  docker compose exec -T sqldb sh -c 'mysql -uroot -p"${MYSQL_ROOT_PASSWORD}" '"${DB_NAME}"
```

## Updating Kimai

```bash
docker compose pull
docker compose up -d
```

The `kimai` container runs pending DB migrations automatically on startup.
Take a backup first (above) -- if a migration ever misbehaves, restoring is
your rollback path.

## Checking you're still inside the free tier

- GCP Console → Billing → Reports: should read effectively $0 (small
  egress overages, if any, are cents).
- The $1 budget alert from `docs/GCP_SETUP.md` step 1 is your safety net.
- `gcloud compute instances list` should show exactly one instance.

## Troubleshooting: MariaDB OOM / crashing

1 GB RAM is genuinely tight. If MariaDB is getting killed:

```bash
dmesg | grep -i "out of memory"
free -h                       # check swap is actually mounted and being used
docker compose logs sqldb --tail=100
```

If it's a recurring problem, lower `innodb_buffer_pool_size` further in
`config/mariadb-lowmem.cnf` (e.g. to `64M`) and `docker compose restart sqldb`.
If it's still not enough, the honest fix is a bigger instance
(`e2-small`, ~$13/mo) -- see the cost table in the README.

## Troubleshooting: no TLS certificate

Caddy logs will say why:

```bash
docker compose logs caddy --tail=100
```

Almost always one of: DNS hasn't propagated yet, port 80/443 isn't reachable
(check the GCP firewall rules from `scripts/01-provision-vm.sh` actually
applied), or `DOMAIN` in `.env` doesn't match the A record.
