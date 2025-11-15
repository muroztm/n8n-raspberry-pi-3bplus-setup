#!/usr/bin/env bash
#
# install_n8n_rpi3b.sh
# n8n 1.60.0 setup script for Raspberry Pi 3B+ (Legacy OS 32-bit)
# Generic enough for other Debian-based systems.

set -euo pipefail

N8N_VERSION="${N8N_VERSION:-1.60.0}"
N8N_USER="${N8N_USER:-n8n}"
N8N_HOME="${N8N_HOME:-/var/lib/n8n}"
SERVICE_FILE="${SERVICE_FILE:-/etc/systemd/system/n8n.service}"

echo "=== n8n install script for Raspberry Pi 3B+ / Debian-based systems ==="

#--------------------------------------------------------------------
# 0. Root check
#--------------------------------------------------------------------
if [[ "$EUID" -ne 0 ]]; then
  echo "This script must be run as root. Example:"
  echo "  sudo $0"
  exit 1
fi

#--------------------------------------------------------------------
# 1. OS info (for logs only)
#--------------------------------------------------------------------
echo
echo "[1/8] Detecting OS..."
if [[ -f /etc/os-release ]]; then
  . /etc/os-release
  echo "Name: ${NAME:-unknown}"
  echo "Version: ${VERSION:-unknown}"
  echo "ID: ${ID:-unknown}, Codename: ${VERSION_CODENAME:-unknown}"
else
  echo "/etc/os-release not found. Assuming a Debian-like system."
fi

#--------------------------------------------------------------------
# 2. apt update / upgrade
#--------------------------------------------------------------------
echo
echo "[2/8] Running apt update & upgrade..."
apt update
apt upgrade -y

#--------------------------------------------------------------------
# 3. Swap to 1024 MB (optional)
#--------------------------------------------------------------------
echo
echo "[3/8] Configuring swap (1024 MB)."
echo "     Set SKIP_SWAP=1 in the environment to skip this step."

if [[ "${SKIP_SWAP:-0}" != "1" ]]; then
  if ! dpkg -s dphys-swapfile >/dev/null 2>&1; then
    apt install -y dphys-swapfile
  fi

  if grep -q '^CONF_SWAPSIZE=' /etc/dphys-swapfile 2>/dev/null; then
    sed -i 's/^CONF_SWAPSIZE=.*/CONF_SWAPSIZE=1024/' /etc/dphys-swapfile
  else
    echo 'CONF_SWAPSIZE=1024' >> /etc/dphys-swapfile
  fi

  systemctl restart dphys-swapfile || true
else
  echo "Skipping swap resize because SKIP_SWAP=1."
fi

echo "Current memory status:"
free -h || true

#--------------------------------------------------------------------
# 4. Install Node.js, npm, build tools, Python, SQLite dev
#--------------------------------------------------------------------
echo
echo "[4/8] Installing Node.js, npm and build tools..."
apt install -y \
  nodejs npm \
  build-essential \
  python3 python3-dev python3-distutils \
  libsqlite3-dev

echo "Node.js version:"
node -v || echo "Node is not available!"
echo "npm version:"
npm -v || echo "npm is not available!"

#--------------------------------------------------------------------
# 5. Install n8n
#--------------------------------------------------------------------
echo
echo "[5/8] Installing n8n@${N8N_VERSION} globally (this may take a while)..."

env NODE_OPTIONS="--max_old_space_size=512" \
  npm install -g --unsafe-perm "n8n@${N8N_VERSION}"

echo "Installed n8n version:"
n8n --version

# Determine executable path for the service
N8N_BIN="$(command -v n8n || true)"
if [[ -z "${N8N_BIN}" ]]; then
  echo "ERROR: Could not find n8n in PATH after installation."
  exit 1
fi
echo "n8n binary path: ${N8N_BIN}"

#--------------------------------------------------------------------
# 6. Create n8n system user and data directory
#--------------------------------------------------------------------
echo
echo "[6/8] Creating n8n system user and home directory..."

if ! id -u "${N8N_USER}" >/dev/null 2>&1; then
  adduser --system --group --home "${N8N_HOME}" "${N8N_USER}"
else
  echo "User '${N8N_USER}' already exists, reusing."
fi

mkdir -p "${N8N_HOME}"
chown -R "${N8N_USER}:${N8N_USER}" "${N8N_HOME}"

#--------------------------------------------------------------------
# 7. Write systemd service
#--------------------------------------------------------------------
echo
echo "[7/8] Writing systemd service file: ${SERVICE_FILE}"

if [[ -f "${SERVICE_FILE}" ]]; then
  echo "Existing service file found. Backing up to: ${SERVICE_FILE}.bak"
  cp "${SERVICE_FILE}" "${SERVICE_FILE}.bak"
fi

cat > "${SERVICE_FILE}" <<EOF
[Unit]
Description=n8n - Workflow Automation
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=${N8N_USER}
WorkingDirectory=${N8N_HOME}
ExecStart=${N8N_BIN}
Restart=always
RestartSec=5

Environment=NODE_ENV=production
Environment=N8N_PORT=5678
Environment=N8N_SECURE_COOKIE=false

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
systemctl daemon-reload

echo "Enabling and restarting n8n service..."
systemctl enable n8n
systemctl restart n8n

echo
echo "n8n service status:"
systemctl status n8n --no-pager || true

#--------------------------------------------------------------------
# 8. Final info
#--------------------------------------------------------------------
echo
IP_ADDR=$(hostname -I 2>/dev/null | awk '{print $1}')
echo "[8/8] Installation finished."
echo
echo "If everything is OK, open n8n in your browser from another device:"
echo "  http://${IP_ADDR:-<raspberry_pi_ip>}:5678"
echo
echo "Check logs with:"
echo "  journalctl -u n8n -n 40 --no-pager"
echo
echo "You can customize this script by setting environment variables, e.g.:"
echo "  N8N_VERSION=1.106.0 N8N_USER=myuser N8N_HOME=/srv/n8n sudo ./install_n8n_rpi3b.sh"
echo
echo "Done. 🚀"
