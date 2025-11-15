# n8n Setup on Raspberry Pi 3B+ (Legacy OS 32-bit)

This repository documents how to install and run **n8n** on a **Raspberry Pi 3B+ (1 GB RAM)** using:

- **Raspberry Pi OS (Legacy) Lite – 32-bit (Bookworm)**
- **Node.js 18.x (from Raspberry Pi OS repository)**
- **n8n 1.60.0** (light and stable for Pi 3B+)
- **systemd service** so n8n auto-starts after reboot

> ⚠️ Pi 3B+ has only 1GB RAM — this setup is optimized for stability.

---

## Quick install (one-liner)

```bash
curl -fsSL https://raw.githubusercontent.com/muroztm/n8n-raspberry-pi-3bplus-setup/refs/heads/main/install_n8n_rpi3b.sh | sudo bash
```

## OR Step by Step

# ⭐ 1. Prepare Raspberry Pi

1. Flash **Raspberry Pi OS (Legacy) Lite – 32-bit** using Raspberry Pi Imager.
2. In Imager advanced settings:
   - Enable **SSH**
   - Create your own user (e.g. `murat`)
   - Set Wi-Fi, timezone, hostname
3. Boot the Pi and connect via SSH:

```bash
ssh murat@<raspberry_pi_ip>
```

---

# ⭐ 2. Update System

```bash
sudo apt update
sudo apt upgrade -y
```

---

# ⭐ 3. Increase Swap to 1GB (Recommended for Pi 3B+)

n8n installation requires more memory on Pi 3B+.

Install swap manager:

```bash
sudo apt install -y dphys-swapfile
```

Edit swap size:

```bash
sudo nano /etc/dphys-swapfile
```

Find the line:

```
CONF_SWAPSIZE=
```

Set it to:

```
CONF_SWAPSIZE=1024
```

Apply changes:

```bash
sudo systemctl restart dphys-swapfile
free -h
```

You should see ~1.0 GB swap.

---

# ⭐ 4. Install Node.js, npm and Build Tools

Install packages:

```bash
sudo apt install -y \
  nodejs npm \
  build-essential \
  python3 python3-dev python3-distutils \
  libsqlite3-dev
```

Check versions:

```bash
node -v
npm -v
```

Expected:

- `v18.x.x`
- `9.x.x` or `10.x.x`

---

# ⭐ 5. Install n8n (Stable Version for Pi 3B+)

Install n8n:

```bash
sudo env "NODE_OPTIONS=--max_old_space_size=512" \
  npm install -g --unsafe-perm n8n@1.60.0
```

Check version:

```bash
n8n --version
```

Expected:

```
1.60.0
```

---

# ⭐ 6. Create Dedicated n8n User

```bash
sudo adduser --system --group --home /var/lib/n8n n8n
sudo mkdir -p /var/lib/n8n
sudo chown -R n8n:n8n /var/lib/n8n
```

---

# ⭐ 7. Install systemd Service

Create service file:

```bash
sudo nano /etc/systemd/system/n8n.service
```

Insert the following:

```ini
[Unit]
Description=n8n - Workflow Automation
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
User=n8n
WorkingDirectory=/var/lib/n8n
ExecStart=/usr/local/bin/n8n
Restart=always
RestartSec=5

Environment=NODE_ENV=production
Environment=N8N_PORT=5678
Environment=N8N_SECURE_COOKIE=false

[Install]
WantedBy=multi-user.target
```

Enable + start service:

```bash
sudo systemctl daemon-reload
sudo systemctl enable n8n
sudo systemctl start n8n
sudo systemctl status n8n
```

You should see:

```
Active: active (running)
```

---

# ⭐ 8. Access n8n Editor

From your PC browser:

```
http://<raspberry_pi_ip>:5678
```

Example:

```
http://192.168.50.111:5678
```

---

# ⭐ 9. Troubleshooting

Check service status:

```bash
sudo systemctl status n8n
```

Check logs:

```bash
journalctl -u n8n -n 40 --no-pager
```

Which n8n is being used?

```bash
which n8n
```

Expected:

```
/usr/local/bin/n8n
```

Test from Raspberry Pi:

```bash
curl http://localhost:5678
```

If you see HTML output → n8n is running.

---

# ⭐ 10. Notes

This setup is optimized for a small device (Pi 3B+).

Newer n8n versions are heavier and may fail to install on 1GB RAM.

Use this setup for:

- home automations  
- Telegram bots  
- small workflows  
- local API endpoints  

For heavier workflows, use a PC, Pi 4, or VPS.

---

# 🎉 You are ready!

Your Raspberry Pi now runs:

- n8n **1.60.0**
- auto-starts with systemd
- stable setup tuned for Pi 3B+

Enjoy your automations 🚀
