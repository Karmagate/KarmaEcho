# KarmaEcho Quick Installation Guide

## Prerequisites

- **VPS Server**: Ubuntu 22.04 LTS (1 vCPU, 1GB RAM minimum)
- **Domain**: Managed by Cloudflare
- **Access**: Root SSH access to server

---

## Step 1: Configure Cloudflare DNS

Before running the installation script, configure DNS in Cloudflare:

### 1.1 Add DNS Records

Go to **Cloudflare Dashboard → Your Domain → DNS → Records**

Add these records (**Proxy Status must be "DNS only" - grey cloud!**):

| Type | Name | Content | Proxy Status |
|------|------|---------|--------------|
| A | ns1 | YOUR_SERVER_IP | DNS only (grey) |
| A | ns2 | YOUR_SERVER_IP | DNS only (grey) |
| A | @ | YOUR_SERVER_IP | DNS only (grey) |
| A | * | YOUR_SERVER_IP | DNS only (grey) |

⚠️ **Important**: The proxy MUST be OFF (grey cloud icon, not orange)!

### 1.2 Create API Token (for HTTPS)

If you want HTTPS/WSS support:

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Select template: **Edit zone DNS**
4. Configure:
   - Permissions: Zone → DNS → Edit
   - Zone Resources: Include → Specific zone → Your Domain
5. Click **Continue to summary** → **Create Token**
6. **Copy the token** (shown only once!)

---

## Step 2: Run Installation Script

SSH into your server and run:

```bash
# Download and run the installer
curl -sSL https://raw.githubusercontent.com/karmagate/karmaecho/main/scripts/install-karmaecho.sh | sudo bash
```

Or manually:

```bash
# Download
wget https://raw.githubusercontent.com/karmagate/karmaecho/main/scripts/install-karmaecho.sh

# Make executable
chmod +x install-karmaecho.sh

# Run
sudo ./install-karmaecho.sh
```

The script will ask for:
- Your domain name
- Server IP (auto-detected)
- Cloudflare API token (optional, for HTTPS)
- Authentication token (auto-generated if empty)

---

## Step 3: Verify Installation

After installation, test:

```bash
# Check service status
systemctl status karmaecho

# View logs
tail -f /var/log/karmaecho/server.log

# Test HTTP
curl http://yourdomain.com

# Test HTTPS (if enabled)
curl https://yourdomain.com
```

---

## Step 4: Use the Client

On your local machine:

```bash
# Install client
go install github.com/karmagate/karmaecho/cmd/karmaecho-client@latest

# Connect
karmaecho-client -s yourdomain.com -t YOUR_TOKEN
```

---

## Troubleshooting

### Server won't start
```bash
journalctl -u karmaecho -n 50
cat /var/log/karmaecho/error.log
```

### Port 53 in use
```bash
systemctl stop systemd-resolved
systemctl disable systemd-resolved
```

### Firewall blocking connections
```bash
ufw status
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 53
ufw reload
```

### SSL certificate issues
```bash
# Check certificate
ls -la /etc/letsencrypt/live/yourdomain.com/

# Manually request certificate
certbot certonly --dns-cloudflare \
  --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
  -d "yourdomain.com" -d "*.yourdomain.com"
```

---

## Files & Locations

| File | Description |
|------|-------------|
| `/usr/local/bin/karmaecho-server` | Server binary |
| `/usr/local/bin/karmaecho-client` | Client binary |
| `/etc/karmaecho/token` | Authentication token |
| `/etc/karmaecho/config` | Configuration |
| `/etc/systemd/system/karmaecho.service` | Systemd service |
| `/var/log/karmaecho/server.log` | Server logs |
| `/var/log/karmaecho/error.log` | Error logs |
| `/etc/letsencrypt/live/DOMAIN/` | SSL certificates |

---

## Service Commands

```bash
# Status
systemctl status karmaecho

# Start
systemctl start karmaecho

# Stop  
systemctl stop karmaecho

# Restart
systemctl restart karmaecho

# View token
cat /etc/karmaecho/token
```

---

## Payload Formats

| Protocol | Format |
|----------|--------|
| DNS | `[correlation-id].yourdomain.com` |
| HTTP | `http://[correlation-id].yourdomain.com` |
| HTTPS | `https://[correlation-id].yourdomain.com` |
| WebSocket | `wss://[correlation-id].yourdomain.com/ws` |
| SMTP | `test@[correlation-id].yourdomain.com` |
| LDAP | `ldap://[correlation-id].yourdomain.com` |
