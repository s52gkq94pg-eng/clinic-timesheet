#!/usr/bin/env bash
# Run this ON THE VM (after `gcloud compute ssh clinic-timesheet --zone=...`).
# One-time setup: OS updates, Docker, and the swap file that keeps a 1 GB
# e2-micro from OOM-killing MariaDB instead of just slowing down.
set -euo pipefail

sudo apt-get update -y
sudo apt-get upgrade -y

# --- Docker + Compose plugin, official repo ---
sudo apt-get install -y ca-certificates curl gnupg
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
sudo apt-get update -y
sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
sudo usermod -aG docker "$USER"

# --- 2 GB swap file (critical on 1 GB RAM) ---
if [ ! -f /swapfile ]; then
  sudo fallocate -l 2G /swapfile
  sudo chmod 600 /swapfile
  sudo mkswap /swapfile
  sudo swapon /swapfile
  echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
fi
# Prefer keeping things in RAM until necessary, but allow swap as a safety net
# rather than letting the OOM killer take out MariaDB.
sudo sysctl -w vm.swappiness=10
echo 'vm.swappiness=10' | sudo tee -a /etc/sysctl.conf

# --- Minimal host firewall (defense in depth alongside GCP's firewall rules) ---
sudo apt-get install -y ufw
sudo ufw allow OpenSSH
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

echo ""
echo "Server prep done. Log out and back in once so the 'docker' group membership takes effect,"
echo "then clone the repo and run scripts/03-deploy.sh."
