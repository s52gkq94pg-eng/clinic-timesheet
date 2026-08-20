#!/usr/bin/env bash
# Run this LOCALLY (your Mac), not on the server.
# Prerequisites: `gcloud` CLI installed and `gcloud auth login` already done,
# a GCP project created, and billing enabled on it. See docs/GCP_SETUP.md.
#
# Creates the free-tier-eligible pieces: one e2-micro VM, a reserved static
# IP, and firewall rules for HTTP/HTTPS. SSH (port 22) uses GCP's default
# "default-allow-ssh" firewall rule that new projects already have.
set -euo pipefail

# ---- edit these ----
PROJECT_ID="your-gcp-project-id"
REGION="us-central1"        # must be us-central1, us-east1, or us-west1 for Always Free
ZONE="us-central1-a"
INSTANCE_NAME="clinic-timesheet"
IP_NAME="clinic-timesheet-ip"
# ---------------------

gcloud config set project "${PROJECT_ID}"
gcloud services enable compute.googleapis.com

# Reserve a static external IP first, so the VM keeps the same address
# across reboots/stop-start cycles (needed for a stable DNS record).
gcloud compute addresses create "${IP_NAME}" --region="${REGION}"
STATIC_IP="$(gcloud compute addresses describe "${IP_NAME}" --region="${REGION}" --format='get(address)')"
echo "Reserved static IP: ${STATIC_IP}"

# e2-micro + Standard PD (not Balanced PD) + Debian 12 = stays in Always Free.
gcloud compute instances create "${INSTANCE_NAME}" \
  --zone="${ZONE}" \
  --machine-type=e2-micro \
  --image-family=debian-12 \
  --image-project=debian-cloud \
  --boot-disk-size=30GB \
  --boot-disk-type=pd-standard \
  --address="${STATIC_IP}" \
  --tags=http-server,https-server

# Firewall rules for the tags above (idempotent-ish: will error harmlessly if they already exist).
gcloud compute firewall-rules create allow-http \
  --allow=tcp:80 --target-tags=http-server --direction=INGRESS --source-ranges=0.0.0.0/0 || true
gcloud compute firewall-rules create allow-https \
  --allow=tcp:443 --target-tags=https-server --direction=INGRESS --source-ranges=0.0.0.0/0 || true

echo ""
echo "Done. Point your domain's DNS A record at: ${STATIC_IP}"
echo "Then SSH in with:  gcloud compute ssh ${INSTANCE_NAME} --zone=${ZONE}"
