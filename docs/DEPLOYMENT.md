# KarmaEcho Deployment Guide

## Domain: karmaproxy.com (Cloudflare)

---

## 1. Server Requirements

### Minimum VPS Specs
- **CPU:** 1 vCPU
- **RAM:** 1 GB
- **Disk:** 20 GB SSD
- **OS:** Ubuntu 22.04 LTS
- **Network:** Static Public IP

### Recommended Providers
- DigitalOcean ($6/mo)
- Vultr ($6/mo)
- Hetzner ($4/mo)
- Linode ($5/mo)

### Required Ports
| Port | Protocol | Service |
|------|----------|---------|
| 53 | UDP/TCP | DNS |
| 80 | TCP | HTTP |
| 443 | TCP | HTTPS |
| 25 | TCP | SMTP |
| 587 | TCP | SMTPS |
| 465 | TCP | SMTP AutoTLS |
| 389 | TCP | LDAP |
| 21 | TCP | FTP (optional) |
| 445 | TCP | SMB (optional) |

---

## 2. VPS Setup (Ubuntu 22.04)

### 2.1 Initial Server Setup

```bash
# Connect to server
ssh root@YOUR_SERVER_IP

# Update system
apt update && apt upgrade -y

# Install required packages
apt install -y git curl wget build-essential

# Create user for karmaecho
useradd -m -s /bin/bash karmaecho
usermod -aG sudo karmaecho

# Set password
passwd karmaecho
```

### 2.2 Install Go 1.21+

```bash
# Download Go
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz

# Extract to /usr/local
rm -rf /usr/local/go && tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz

# Add to PATH (add to /etc/profile or ~/.bashrc)
echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile
echo 'export PATH=$PATH:$HOME/go/bin' >> /etc/profile
source /etc/profile

# Verify installation
go version
# Output: go version go1.21.5 linux/amd64
```

### 2.3 Disable systemd-resolved (Required for DNS port 53)

```bash
# Check what's using port 53
sudo lsof -i :53

# If systemd-resolved is using it:
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved

# Update resolv.conf
sudo rm /etc/resolv.conf
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf
echo "nameserver 1.1.1.1" | sudo tee -a /etc/resolv.conf
```

### 2.4 Configure Firewall

```bash
# Install UFW
apt install -y ufw

# Allow SSH first!
ufw allow 22/tcp

# Allow KarmaEcho ports
ufw allow 53/udp
ufw allow 53/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw allow 25/tcp
ufw allow 587/tcp
ufw allow 465/tcp
ufw allow 389/tcp

# Enable firewall
ufw enable
ufw status
```

---

## 3. Cloudflare DNS Configuration

### ⚠️ IMPORTANT: Disable Cloudflare Proxy for these records!

Go to: **Cloudflare Dashboard → karmaproxy.com → DNS**

### 3.1 Create Nameserver Records (Glue Records)

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | ns1 | YOUR_SERVER_IP | ❌ DNS only |
| A | ns2 | YOUR_SERVER_IP | ❌ DNS only |

### 3.2 Create Main Records

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | @ | YOUR_SERVER_IP | ❌ DNS only |
| A | * | YOUR_SERVER_IP | ❌ DNS only |
| NS | @ | ns1.karmaproxy.com | - |
| NS | @ | ns2.karmaproxy.com | - |

### 3.3 Cloudflare Settings

1. **SSL/TLS → Overview** → Set to "Full" or "Full (strict)"
2. **SSL/TLS → Edge Certificates** → Disable "Always Use HTTPS" for this domain
3. **DNS → Settings** → Disable DNSSEC (if enabled, can conflict)

### Visual Guide:
```
Cloudflare DNS Records:
┌──────┬──────────────────────┬─────────────────────┬───────────┐
│ Type │ Name                 │ Content             │ Proxy     │
├──────┼──────────────────────┼─────────────────────┼───────────┤
│ A    │ ns1                  │ 123.45.67.89        │ DNS only  │
│ A    │ ns2                  │ 123.45.67.89        │ DNS only  │
│ A    │ @                    │ 123.45.67.89        │ DNS only  │
│ A    │ *                    │ 123.45.67.89        │ DNS only  │
│ NS   │ karmaproxy.com       │ ns1.karmaproxy.com  │ -         │
│ NS   │ karmaproxy.com       │ ns2.karmaproxy.com  │ -         │
└──────┴──────────────────────┴─────────────────────┴───────────┘
```

---

## 4. Build & Install KarmaEcho

### 4.1 Clone and Build

```bash
# Switch to karmaecho user
su - karmaecho

# Clone repository
git clone https://github.com/karmagate/karmaecho.git
cd karmaecho

# Build server and client
go build -o karmaecho-server ./cmd/karmaecho-server/
go build -o karmaecho-client ./cmd/karmaecho-client/

# Move to /usr/local/bin
sudo mv karmaecho-server /usr/local/bin/
sudo mv karmaecho-client /usr/local/bin/

# Verify
karmaecho-server -version
```

### 4.2 Create Configuration Directory

```bash
sudo mkdir -p /etc/karmaecho
sudo mkdir -p /var/log/karmaecho
sudo chown -R karmaecho:karmaecho /etc/karmaecho /var/log/karmaecho
```

---

## 5. Create Systemd Service

### 5.1 Create Service File

```bash
sudo nano /etc/systemd/system/karmaecho.service
```

**Content:**
```ini
[Unit]
Description=KarmaEcho OOB Interaction Server
After=network.target

[Service]
Type=simple
User=root
Group=root
ExecStart=/usr/local/bin/karmaecho-server \
    -domain karmaproxy.com \
    -ip YOUR_SERVER_IP \
    -auth \
    -ws-timeout 120 \
    -ws-max-conn 50 \
    -metrics
Restart=always
RestartSec=5
StandardOutput=append:/var/log/karmaecho/server.log
StandardError=append:/var/log/karmaecho/error.log

# Security hardening
NoNewPrivileges=false
ProtectSystem=false

[Install]
WantedBy=multi-user.target
```

### 5.2 Enable and Start Service

```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable service (start on boot)
sudo systemctl enable karmaecho

# Start service
sudo systemctl start karmaecho

# Check status
sudo systemctl status karmaecho

# View logs
sudo tail -f /var/log/karmaecho/server.log
```

---

## 6. First Run & Token

### 6.1 Get Authentication Token

When you start the server with `-auth` flag, it generates a random token:

```bash
# Check logs for token
sudo grep "Client Token" /var/log/karmaecho/server.log
```

**Example output:**
```
[INF] Client Token: a1b2c3d4e5f6g7h8i9j0k1l2m3n4o5p6q7r8s9t0u1v2w3x4y5z6
```

**Save this token!** You'll need it for the client.

### 6.2 Or Use Custom Token

Edit the service file to use a custom token:
```bash
sudo nano /etc/systemd/system/karmaecho.service
```

Change:
```ini
ExecStart=/usr/local/bin/karmaecho-server \
    -domain karmaproxy.com \
    -ip YOUR_SERVER_IP \
    -token YOUR_SECRET_TOKEN_HERE \
    ...
```

Then restart:
```bash
sudo systemctl daemon-reload
sudo systemctl restart karmaecho
```

---

## 7. Verify Installation

### 7.1 Check All Services Running

```bash
# Check listening ports
sudo netstat -tlnp | grep karmaecho
# Or
sudo ss -tlnp | grep karmaecho
```

**Expected output:**
```
tcp  LISTEN  0  128  0.0.0.0:80    karmaecho-server
tcp  LISTEN  0  128  0.0.0.0:443   karmaecho-server
tcp  LISTEN  0  128  0.0.0.0:25    karmaecho-server
tcp  LISTEN  0  128  0.0.0.0:587   karmaecho-server
tcp  LISTEN  0  128  0.0.0.0:389   karmaecho-server
udp  LISTEN  0  128  0.0.0.0:53    karmaecho-server
```

### 7.2 Test DNS

```bash
# From another machine:
dig @YOUR_SERVER_IP test.karmaproxy.com

# Or using nslookup:
nslookup test.karmaproxy.com YOUR_SERVER_IP
```

### 7.3 Test HTTP

```bash
# Visit in browser:
http://karmaproxy.com

# Or curl:
curl http://karmaproxy.com
```

### 7.4 Test WebSocket

```bash
# Using websocat (install: cargo install websocat)
websocat wss://test123.karmaproxy.com/ws

# Or JavaScript in browser console:
const ws = new WebSocket('wss://test123.karmaproxy.com/ws');
ws.onopen = () => { ws.send('Hello'); console.log('Connected!'); };
```

---

## 8. Client Usage

### 8.1 Install Client (Local Machine)

```bash
# Build from source
go install github.com/karmagate/karmaecho/cmd/karmaecho-client@latest

# Or download binary
```

### 8.2 Connect to Your Server

```bash
karmaecho-client -server karmaproxy.com -token YOUR_TOKEN_HERE
```

**Example output:**
```
    _                                     _
   | | ____ _ _ __ _ __ ___   __ _  ___  ___| |__   ___
   | |/ / _` | '__| '_ ` _ \ / _` |/ _ \/ __| '_ \ / _ \
   |   < (_| | |  | | | | | | (_| |  __/ (__| | | | (_) |
   |_|\_\__,_|_|  |_| |_| |_|\__,_|\___|\___|_| |_|\___/

[INF] Listing 1 payload for OOB Testing
[INF] c59e3crp82ke7bcnedq0cfjqdpe.karmaproxy.com
```

### 8.3 Generate Payloads

| Protocol | Payload Format |
|----------|---------------|
| DNS | `c59e3crp82ke7bcnedq0.karmaproxy.com` |
| HTTP | `http://c59e3crp82ke7bcnedq0.karmaproxy.com` |
| HTTPS | `https://c59e3crp82ke7bcnedq0.karmaproxy.com` |
| WebSocket | `wss://c59e3crp82ke7bcnedq0.karmaproxy.com/ws` |
| SMTP | Send email to `test@c59e3crp82ke7bcnedq0.karmaproxy.com` |
| LDAP | `ldap://c59e3crp82ke7bcnedq0.karmaproxy.com` |

---

## 9. SSL Certificate

KarmaEcho uses **certmagic** for automatic Let's Encrypt certificates.

### First HTTPS Request
The first time someone accesses via HTTPS, the server will:
1. Automatically request a wildcard certificate from Let's Encrypt
2. Store it for future use
3. Auto-renew before expiration

### Check Certificate
```bash
# View certificate info
echo | openssl s_client -connect karmaproxy.com:443 2>/dev/null | openssl x509 -noout -dates
```

---

## 10. Maintenance

### View Logs
```bash
# Real-time logs
sudo tail -f /var/log/karmaecho/server.log

# Error logs
sudo tail -f /var/log/karmaecho/error.log
```

### Restart Service
```bash
sudo systemctl restart karmaecho
```

### Update KarmaEcho
```bash
cd ~/karmaecho
git pull
go build -o karmaecho-server ./cmd/karmaecho-server/
sudo mv karmaecho-server /usr/local/bin/
sudo systemctl restart karmaecho
```

### Check Metrics
```bash
curl -H "Authorization: YOUR_TOKEN" http://localhost/metrics
```

---

## 11. Security Best Practices

1. **Keep token secret** - Never share your authentication token
2. **Use firewall** - Only open required ports
3. **Monitor logs** - Check for unusual activity
4. **Update regularly** - Keep system and KarmaEcho updated
5. **Backup token** - Store token securely

---

## Quick Reference

### Server Commands
```bash
# Start
sudo systemctl start karmaecho

# Stop
sudo systemctl stop karmaecho

# Restart
sudo systemctl restart karmaecho

# Status
sudo systemctl status karmaecho

# Logs
sudo journalctl -u karmaecho -f
```

### Client Commands
```bash
# Basic usage
karmaecho-client -s karmaproxy.com -t TOKEN

# Multiple payloads
karmaecho-client -s karmaproxy.com -t TOKEN -n 5

# Filter DNS only
karmaecho-client -s karmaproxy.com -t TOKEN -dns-only

# Filter WebSocket only
karmaecho-client -s karmaproxy.com -t TOKEN -websocket-only

# Verbose output
karmaecho-client -s karmaproxy.com -t TOKEN -v

# Save to file
karmaecho-client -s karmaproxy.com -t TOKEN -o results.txt
```

---

## Troubleshooting

### Port 53 already in use
```bash
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
```

### Certificate not generating
- Ensure port 80 is accessible from internet
- Check Cloudflare proxy is OFF (DNS only)
- Wait a few minutes for propagation

### Client can't connect
- Verify token is correct
- Check firewall allows ports
- Ensure DNS resolves correctly

### No interactions received
- Verify DNS records in Cloudflare
- Check wildcard (*) A record exists
- Test with `dig @YOUR_IP test.karmaproxy.com`
