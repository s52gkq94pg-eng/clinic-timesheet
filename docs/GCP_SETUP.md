# GCP setup walkthrough

Do this a day before your "deploy night" if you're using a brand-new GCP
account -- Google sometimes holds new accounts for identity verification,
which can take hours and will blow your 2-hour budget if it happens mid-setup.

## 1. Console prerequisites (do this first, before any `gcloud` commands)

1. Go to https://console.cloud.google.com and create a project (or reuse one).
2. **Billing → link a billing account.** GCP requires a valid card on file
   even to use Always Free resources -- you will not be charged as long as
   you stay within the free-tier limits below, but the card must be there.
3. **Billing → Budgets & alerts → Create budget.** Set a $1 threshold. This
   is your tripwire: if anything drifts out of the free tier (wrong disk
   type, wrong region, a second instance left running), you get an email
   instead of a surprise on the statement.

## 2. The Always Free limits this setup must stay inside

| Resource | Free limit | This repo uses |
|---|---|---|
| Compute instance | 1x `e2-micro`, non-preemptible | exactly 1 |
| Region | `us-central1`, `us-east1`, or `us-west1` only | `us-central1` |
| Boot disk | 30 GB **Standard** Persistent Disk | 30 GB `pd-standard` |
| Network egress | 1 GB/month (North America) | fine for 4 users |

The most common way people accidentally get billed: the Console's VM
creation wizard defaults the disk to **Balanced PD**, which is not free.
`scripts/01-provision-vm.sh` sets `--boot-disk-type=pd-standard` explicitly,
so if you create the VM via that script instead of clicking through the
Console, you're safe. If you ever edit the VM by hand, double-check that
field.

## 3. Install and authenticate gcloud (local machine)

```bash
brew install --cask google-cloud-sdk
gcloud init                # picks/creates the project, sets default region
gcloud auth login           # opens a browser for OAuth
```

## 4. Create the VM, static IP, and firewall rules

Edit the variables at the top of `scripts/01-provision-vm.sh` (your real
`PROJECT_ID`), then:

```bash
./scripts/01-provision-vm.sh
```

This prints a static IP at the end. That's the address your domain needs to
point at.

## 5. DNS

Add an **A record** for the subdomain you want (e.g. `timesheet.yourclinic.com`)
pointing at the static IP from step 4. Propagation is usually minutes but can
take a few hours -- Caddy (step 7) won't be able to get a TLS certificate
until this resolves, so kick it off early.

If you don't already own a domain, this is the one piece of this project
that isn't free -- a `.com` is roughly $10-15/year. Caddy can't issue a
trusted HTTPS certificate for a bare IP address, and a login page for
clinic staff really should be on HTTPS.

## 6. SSH in and prep the server

```bash
gcloud compute ssh clinic-timesheet --zone=us-central1-a
```

Then, on the VM:

```bash
git clone <this-repo-url>
cd clinic-timesheet
./scripts/02-server-setup.sh
```

Log out and back in (so your user picks up Docker group membership), then:

```bash
cp .env.example .env
nano .env   # fill in DOMAIN, ADMIN_EMAIL/PASSWORD, APP_SECRET, DB_* passwords
./scripts/03-deploy.sh
```

## 7. First login

Visit `https://<your-domain>`. Caddy requests the certificate automatically
on first request, so the very first load may take a few extra seconds.

Log in with `ADMIN_EMAIL` / `ADMIN_PASSWORD` from `.env`, then immediately:

1. Change the admin password (Profile → Password).
2. Create the 3 employee accounts (Administration → Users).
3. Treat the `.env` admin credentials as burned -- they're only the
   bootstrap login.

See `docs/RUNBOOK.md` for backups, updates, and troubleshooting.
