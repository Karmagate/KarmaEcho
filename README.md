<h1 align="center">
  <br>
  <a href="https://karmagate.com">
    <picture>
      <source media="(prefers-color-scheme: dark)" srcset="https://raw.githubusercontent.com/Karmagate/App/main/logo-dark.svg">
      <source media="(prefers-color-scheme: light)" srcset="https://raw.githubusercontent.com/Karmagate/App/main/logo-light.svg">
      <img src="https://raw.githubusercontent.com/Karmagate/App/main/logo-dark.svg" width="200px" alt="KarmaGate">
    </picture>
  </a>
  <br>
  <br>
  KarmaEcho
  <br>
</h1>

<h4 align="center">High-performance OOB interaction gathering server for <a href="https://karmagate.com">KarmaGate</a> — multi-protocol vulnerability detection for security teams.</h4>

<p align="center">
  <a href="https://github.com/Karmagate/KarmaEcho/releases/latest">
    <img src="https://img.shields.io/github/v/release/Karmagate/KarmaEcho?style=flat-square&color=00d4aa" alt="Latest Release"/>
  </a>
  <a href="https://github.com/Karmagate/KarmaEcho/releases">
    <img src="https://img.shields.io/github/downloads/Karmagate/KarmaEcho/total?style=flat-square&color=7c3aed" alt="Total Downloads"/>
  </a>
  <a href="https://golang.org">
    <img src="https://img.shields.io/badge/made%20with-Go-00ADD8?style=flat-square" alt="Made with Go"/>
  </a>
  <a href="https://karmagate.com">
    <img src="https://img.shields.io/badge/website-karmagate.com-blue?style=flat-square" alt="Website"/>
  </a>
</p>

<p align="center">
  <a href="#what-is-this">What is this</a> •
  <a href="#features">Features</a> •
  <a href="#quick-start">Quick Start</a> •
  <a href="#supported-protocols">Protocols</a> •
  <a href="#websocket-oob-detection">WebSocket</a> •
  <a href="#deployment">Deployment</a> •
  <a href="#project-structure">Structure</a> •
  <a href="#license">License</a>
</p>

<br>

---

<br>

## What is this

KarmaEcho is an Out-of-Band (OOB) interaction gathering server and client library for security testing. Built with Go for high performance, it detects vulnerabilities that cause external interactions — essential for penetration testing and bug bounty hunting.

Deploy your own OOB server, generate unique correlation payloads, and catch blind interactions across **9 protocols** — DNS, HTTP(S), SMTP(S), LDAP, WebSocket, FTP, and SMB.

| What KarmaEcho does | Why it matters |
|---------------------|---------------|
| Catches blind DNS, HTTP, SMTP callbacks | Detects SSRF, XXE, RCE, log4shell, blind XSS |
| WebSocket OOB detection | Unique — not available in other OOB tools |
| AES-encrypted zero-logging | Your testing data stays private |
| Auto wildcard TLS via Let's Encrypt | HTTPS/WSS payloads work out of the box |
| Cloud metadata DNS entries | Built-in SSRF testing shortcuts |

<br>

---

<br>

## Features

- **Multi-Protocol** — DNS, HTTP(S), SMTP(S), LDAP, FTP, SMB, WebSocket in one server
- **WebSocket OOB** — Unique WS/WSS interaction detection not found in other tools
- **AES Encryption** — Zero logging with end-to-end encryption between client and server
- **Auto TLS** — Automatic ACME-based wildcard certificates via Let's Encrypt
- **Cloud Metadata DNS** — Built-in DNS entries for SSRF testing (169.254.169.254, etc.)
- **Dynamic Responses** — Customize HTTP responses on-the-fly
- **Self-Hosted** — Full control over your OOB infrastructure
- **Metrics** — Built-in Prometheus metrics endpoint

<br>

---

<br>

## Quick Start

### One-line install (Ubuntu 22.04 + Cloudflare)

```bash
curl -sSL https://raw.githubusercontent.com/Karmagate/KarmaEcho/main/scripts/install-karmaecho.sh -o install.sh
chmod +x install.sh && sudo ./install.sh
```

### Install via Go

```bash
go install -v github.com/Karmagate/KarmaEcho/cmd/karmaecho-server@latest
go install -v github.com/Karmagate/KarmaEcho/cmd/karmaecho-client@latest
```

### Build from source

```bash
git clone https://github.com/Karmagate/KarmaEcho.git
cd KarmaEcho
go build -o karmaecho-server ./cmd/karmaecho-server/
go build -o karmaecho-client ./cmd/karmaecho-client/
```

### Run

**Server:**

```bash
karmaecho-server -domain example.com
```

**Client:**

```bash
karmaecho-client -s example.com -t YOUR_TOKEN
```

```
  _  __                         ______     _
 | |/ /__ _ _ __ _ __ ___   __ _|  ____|___| |__   ___
 | ' // _' | '__| '_ ' _ \ / _' | |__  / __| '_ \ / _ \
 | . \ (_| | |  | | | | | | (_| |  __|| (__| | | | (_) |
 |_|\_\__,_|_|  |_| |_| |_|\__,_|_____|\___| | |_|\___/

		karmagate.com

[INF] Listing 1 payload for OOB Testing
[INF] c23b2la0kl1krjcrdj10cndmnioyyyyyn.example.com
```

<br>

---

<br>

## Supported Protocols

| Protocol | Port | Description |
|----------|------|-------------|
| DNS | 53 | DNS queries (A, AAAA, MX, TXT, etc.) |
| HTTP | 80 | HTTP requests |
| HTTPS | 443 | HTTPS requests with auto TLS |
| WebSocket | 80/443 | WS/WSS connections |
| SMTP | 25 | Email interactions |
| SMTPS | 587 | Secure email |
| LDAP | 389 | LDAP queries |
| FTP | 21 | FTP connections (self-hosted) |
| SMB | 445 | SMB connections (self-hosted) |

### Payload Formats

| Protocol | Format |
|----------|--------|
| DNS | `[correlation-id].yourdomain.com` |
| HTTP | `http://[correlation-id].yourdomain.com` |
| HTTPS | `https://[correlation-id].yourdomain.com` |
| WebSocket | `wss://[correlation-id].yourdomain.com/ws` |
| SMTP | `test@[correlation-id].yourdomain.com` |
| LDAP | `ldap://[correlation-id].yourdomain.com` |

<br>

---

<br>

## WebSocket OOB Detection

KarmaEcho introduces **WebSocket OOB detection** — a unique feature not available in other OOB tools.

| Endpoint | Description |
|----------|-------------|
| `/ws` | WebSocket upgrade — correlation ID from subdomain |
| `/ws/{id}` | WebSocket upgrade — correlation ID in path |

**Payloads:**

```
wss://c59e3crp82ke7bcnedq0.example.com/ws
wss://example.com/ws/c59e3crp82ke7bcnedq0
```

**Captured Events:**

| Event | Description |
|-------|-------------|
| `websocket` | Connection established |
| `websocket-message` | Text message received |
| `websocket-binary` | Binary message (base64) |
| `websocket-close` | Connection closed |

<br>

---

<br>

## Deployment

### Requirements

- **OS**: Linux (Ubuntu 22+, Debian 12+)
- **Go** 1.21+ (to build from source)
- **Domain**: Managed by Cloudflare (recommended)
- **Hardware**: 1 vCPU, 1 GB RAM, 20 GB SSD
- **Open ports**: 53, 80, 443, 25, 587, 389 (+ 21, 445 optional)

### Step 1: Prepare the server

```bash
# Update system
apt update && apt upgrade -y
apt install -y git curl wget build-essential

# Disable systemd-resolved (required for DNS port 53)
sudo systemctl stop systemd-resolved
sudo systemctl disable systemd-resolved
echo "nameserver 8.8.8.8" | sudo tee /etc/resolv.conf

# Firewall
sudo ufw allow 22/tcp
sudo ufw allow 53
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw allow 25/tcp
sudo ufw allow 587/tcp
sudo ufw allow 389/tcp
sudo ufw enable
```

### Step 2: Configure DNS (Cloudflare)

> Proxy MUST be OFF (grey cloud) for all records.

| Type | Name | Content | Proxy |
|------|------|---------|-------|
| A | ns1 | YOUR_SERVER_IP | DNS only |
| A | ns2 | YOUR_SERVER_IP | DNS only |
| A | @ | YOUR_SERVER_IP | DNS only |
| A | * | YOUR_SERVER_IP | DNS only |

<details>
<summary><b>Cloudflare API Token (for auto HTTPS)</b></summary>

<br>

If you want automatic wildcard TLS certificates:

1. Go to: https://dash.cloudflare.com/profile/api-tokens
2. Click **Create Token**
3. Select template: **Edit zone DNS**
4. Configure:
   - Permissions: Zone → DNS → Edit
   - Zone Resources: Include → Specific zone → Your Domain
5. Click **Continue to summary** → **Create Token**
6. **Copy the token** (shown only once!)

</details>

### Step 3: Build and install

```bash
git clone https://github.com/Karmagate/KarmaEcho.git
cd KarmaEcho
go build -o karmaecho-server ./cmd/karmaecho-server/
go build -o karmaecho-client ./cmd/karmaecho-client/
sudo mv karmaecho-server karmaecho-client /usr/local/bin/
```

### Step 4: Create systemd service

```bash
sudo nano /etc/systemd/system/karmaecho.service
```

```ini
[Unit]
Description=KarmaEcho OOB Interaction Server
After=network.target

[Service]
Type=simple
User=root
ExecStart=/usr/local/bin/karmaecho-server \
    -domain yourdomain.com \
    -ip YOUR_SERVER_IP \
    -auth \
    -ws-timeout 120 \
    -ws-max-conn 50 \
    -metrics
Restart=always
RestartSec=5
StandardOutput=append:/var/log/karmaecho/server.log
StandardError=append:/var/log/karmaecho/error.log

[Install]
WantedBy=multi-user.target
```

```bash
sudo mkdir -p /var/log/karmaecho
sudo systemctl daemon-reload
sudo systemctl enable karmaecho
sudo systemctl start karmaecho
```

### Step 5: Verify

```bash
# Check service
sudo systemctl status karmaecho

# View logs
sudo tail -f /var/log/karmaecho/server.log

# Get auth token
sudo grep "Client Token" /var/log/karmaecho/server.log

# Test DNS
dig @YOUR_SERVER_IP test.yourdomain.com

# Test HTTP
curl http://yourdomain.com

# Test HTTPS
curl https://yourdomain.com
```

### Updating

```bash
cd ~/KarmaEcho
git pull
go build -o karmaecho-server ./cmd/karmaecho-server/
sudo mv karmaecho-server /usr/local/bin/
sudo systemctl restart karmaecho
```

<br>

---

<br>

## Client Usage

```bash
# Basic usage
karmaecho-client -s yourdomain.com -t TOKEN

# Multiple payloads
karmaecho-client -s yourdomain.com -t TOKEN -n 5

# DNS only
karmaecho-client -s yourdomain.com -t TOKEN -dns-only

# WebSocket only
karmaecho-client -s yourdomain.com -t TOKEN -websocket-only

# Verbose output
karmaecho-client -s yourdomain.com -t TOKEN -v

# Save to file
karmaecho-client -s yourdomain.com -t TOKEN -o results.txt
```

<br>

---

<br>

## Project Structure

```
KarmaEcho/
├── cmd/
│   ├── karmaecho-client/         # CLI client
│   └── karmaecho-server/         # Server application + Dockerfile
├── pkg/
│   ├── client/                   # Client library
│   ├── server/                   # Server implementation
│   │   ├── dns_server.go         #   DNS protocol handler
│   │   ├── http_server.go        #   HTTP/HTTPS handler
│   │   ├── websocket_server.go   #   WebSocket handler
│   │   ├── smtp_server.go        #   SMTP handler
│   │   ├── ldap_server.go        #   LDAP handler
│   │   ├── ftp_server.go         #   FTP handler
│   │   ├── smb_server.go         #   SMB handler
│   │   └── metrics.go            #   Prometheus metrics
│   ├── storage/                  # Interaction storage (AES encrypted)
│   ├── options/                  # Configuration options
│   └── settings/                 # Default settings
├── scripts/
│   ├── install-karmaecho.sh      # Automated installer
│   └── update.sh                 # Update script
├── docs/
│   ├── QUICK-INSTALL.md          # Quick installation guide
│   └── DEPLOYMENT.md             # Detailed deployment docs
└── examples/                     # Usage examples
```

<br>

---

<br>

## Documentation

- [Quick Install Guide](docs/QUICK-INSTALL.md) — Step-by-step installation with Cloudflare
- [Deployment Guide](docs/DEPLOYMENT.md) — Detailed deployment and configuration

<br>

---

<br>

## Support

- **Email**: support@karmagate.com
- **Website**: [karmagate.com](https://karmagate.com)
- **Documentation**: [docs.karmagate.com](https://docs.karmagate.com)
- **Bug Reports**: [GitHub Issues](https://github.com/Karmagate/KarmaEcho/issues)

<br>

---

<br>

## License

KarmaEcho is distributed under the **[Apache License 2.0](LICENSE.md)**.

| Component | License | Copyright |
|-----------|---------|-----------|
| **KarmaEcho** (this fork) | Apache License 2.0 | 2025 KarmaGate |
| **Interactsh** (original) | MIT License | 2021 ProjectDiscovery, Inc. |

KarmaEcho is a fork of [Interactsh](https://github.com/projectdiscovery/interactsh) by [ProjectDiscovery](https://projectdiscovery.io). We gratefully acknowledge ProjectDiscovery for creating and open-sourcing the original project under the MIT License.

<br>

---

<br>

<div align="center">
  <sub>Built with love by the <a href="https://karmagate.com">KarmaGate</a> Team</sub>
  <br>
  <br>
  <a href="https://karmagate.com">Website</a> •
  <a href="https://t.me/karmagate">Telegram</a> •
  <a href="https://discord.gg/karmagate">Discord</a>
</div>
