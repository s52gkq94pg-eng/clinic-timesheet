# Clinic Timesheet

Self-hosted [Kimai](https://github.com/kimai/kimai) deployment for tracking
employee hours at a small pediatric clinic (~4 users), running on a Google
Cloud `e2-micro` instance sized to stay inside GCP's Always Free tier.

This repo doesn't fork Kimai -- it deploys the official `kimai/kimai2`
Docker image. What lives here is the deployment config: `docker-compose.yml`,
a memory-tuned database config, provisioning/setup scripts, and docs.

**Scope note:** this tracks staff *work hours*, not patient records --
there's no PHI/HIPAA surface here, just ordinary employee PII (names,
login, hours worked). Still worth basic hygiene: HTTPS, strong passwords,
and backups, all covered below.

## Architecture

```
Internet
   │  HTTPS (443) / HTTP→HTTPS redirect (80)
   ▼
┌─────────────────────────── e2-micro VM (1 vCPU, 1 GB RAM) ───────────────────────────┐
│                                                                                        │
│   ┌────────────┐        ┌──────────────────┐        ┌───────────────────────────┐    │
│   │   Caddy    │──────▶│  kimai/kimai2     │──────▶│  MariaDB 10.11             │    │
│   │ (auto TLS) │        │  (Apache + PHP)   │        │  (low-memory tuned)       │    │
│   └────────────┘        └──────────────────┘        └───────────────────────────┘    │
│                                                                                        │
│   2 GB swap file (safety net so MariaDB degrades instead of getting OOM-killed)       │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

## Cost

| Item | Config | Cost, if kept inside Always Free limits |
|---|---|---|
| Compute | 1x `e2-micro`, `us-central1` | $0 |
| Disk | 30 GB **Standard** PD | $0 (Always Free covers 30 GB) |
| Static IP | 1 reserved, attached to a running instance | $0 (charged only if reserved but *unattached*) |
| Egress | <1 GB/month, 4 users | $0 |
| Domain name | e.g. `timesheet.yourclinic.com` | ~$10-15/year (only real cost) |

If the free e2-micro's 1 GB RAM turns out too tight in practice, the fallback
is `e2-small` (2 GB RAM) at roughly $13/month -- see `docs/RUNBOOK.md` for
the OOM troubleshooting to check before deciding you need it.

## Setup

Full walkthrough: **[docs/GCP_SETUP.md](docs/GCP_SETUP.md)**. Budget about
2 hours end to end (more if it's a brand-new GCP account -- see that doc's
note on identity-verification delays).

Short version:
1. GCP console: create project, enable billing, set a budget alert.
2. `./scripts/01-provision-vm.sh` (local) -- creates the VM, static IP, firewall rules.
3. Point your domain's DNS A record at the static IP it prints.
4. SSH in, `./scripts/02-server-setup.sh` -- Docker, swap file, host firewall.
5. `cp .env.example .env`, fill in real values, `./scripts/03-deploy.sh`.
6. Log in, change the admin password, create the 3 employee accounts.

## Operating it

See **[docs/RUNBOOK.md](docs/RUNBOOK.md)** for backups, updates, and
troubleshooting (especially the low-RAM MariaDB failure mode).

## Why MariaDB instead of Kimai's documented `mysql:8.3`

Kimai's own docs use `mysql:8.3`. On a full 1 GB RAM instance shared with
the OS, Docker, Apache, and PHP, MySQL 8's baseline footprint leaves very
little room. `mariadb:10.11` with the tuned config in
`config/mariadb-lowmem.cnf` (128 MB InnoDB buffer pool, performance_schema
off, capped connections) is materially lighter and still fully compatible
with Kimai's `DATABASE_URL` — Kimai's Doctrine layer supports MariaDB as a
first-class backend. If you ever move off the free tier to a bigger
instance, switching back to stock MySQL is a one-line change.
