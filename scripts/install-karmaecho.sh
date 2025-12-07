#!/bin/bash

###################################################################################
#                                                                                 #
#   ██╗  ██╗ █████╗ ██████╗ ███╗   ███╗ █████╗ ███████╗ ██████╗██╗  ██╗ ██████╗   #
#   ██║ ██╔╝██╔══██╗██╔══██╗████╗ ████║██╔══██╗██╔════╝██╔════╝██║  ██║██╔═══██╗  #
#   █████╔╝ ███████║██████╔╝██╔████╔██║███████║█████╗  ██║     ███████║██║   ██║  #
#   ██╔═██╗ ██╔══██║██╔══██╗██║╚██╔╝██║██╔══██║██╔══╝  ██║     ██╔══██║██║   ██║  #
#   ██║  ██╗██║  ██║██║  ██║██║ ╚═╝ ██║██║  ██║███████╗╚██████╗██║  ██║╚██████╔╝  #
#   ╚═╝  ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚══════╝ ╚═════╝╚═╝  ╚═╝ ╚═════╝   #
#                                                                                 #
#   KarmaEcho Server - Automated Installation Script                              #
#   https://github.com/karmagate/karmaecho                                        #
#                                                                                 #
###################################################################################

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Configuration
GO_VERSION="1.21.5"
KARMAECHO_REPO="https://github.com/karmagate/karmaecho.git"

#############################################################################
# Functions
#############################################################################

print_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                                                                   ║"
    echo "║      KarmaEcho Server - Installation Script                       ║"
    echo "║                                                                   ║"
    echo "║   OOB Interaction Server with WebSocket Support                   ║"
    echo "║   Protocols: DNS, HTTP/S, WebSocket, SMTP, LDAP, FTP, SMB         ║"
    echo "║                                                                   ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_step() {
    echo -e "\n${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}➤ $1${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

check_root() {
    if [ "$EUID" -ne 0 ]; then
        print_error "This script must be run as root!"
        echo -e "Please run: ${YELLOW}sudo $0${NC}"
        exit 1
    fi
}

detect_ip() {
    # Try multiple methods to detect public IP
    PUBLIC_IP=$(curl -s -4 ifconfig.me 2>/dev/null || \
                curl -s -4 icanhazip.com 2>/dev/null || \
                curl -s -4 ipinfo.io/ip 2>/dev/null || \
                hostname -I | awk '{print $1}')
    echo "$PUBLIC_IP"
}

print_cloudflare_instructions() {
    local domain=$1
    local ip=$2
    
    echo -e "\n${MAGENTA}╔═══════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${MAGENTA}║           ☁️  CLOUDFLARE DNS CONFIGURATION REQUIRED               ║${NC}"
    echo -e "${MAGENTA}╚═══════════════════════════════════════════════════════════════════╝${NC}"
    
    echo -e "\n${BOLD}Before running this script, configure DNS in Cloudflare:${NC}\n"
    
    echo -e "${YELLOW}1. Go to: ${CYAN}https://dash.cloudflare.com${NC}"
    echo -e "${YELLOW}2. Select domain: ${CYAN}${domain}${NC}"
    echo -e "${YELLOW}3. Go to: ${CYAN}DNS → Records${NC}"
    echo -e "${YELLOW}4. Add these records:${NC}\n"
    
    echo -e "   ${BOLD}┌──────────┬──────────────────┬──────────────────┬─────────────┐${NC}"
    echo -e "   ${BOLD}│   Type   │       Name       │      Content     │    Proxy    │${NC}"
    echo -e "   ${BOLD}├──────────┼──────────────────┼──────────────────┼─────────────┤${NC}"
    echo -e "   │    A     │       ns1        │  ${CYAN}${ip}${NC}  │  ${RED}DNS only${NC}  │"
    echo -e "   │    A     │       ns2        │  ${CYAN}${ip}${NC}  │  ${RED}DNS only${NC}  │"
    echo -e "   │    A     │        @         │  ${CYAN}${ip}${NC}  │  ${RED}DNS only${NC}  │"
    echo -e "   │    A     │        *         │  ${CYAN}${ip}${NC}  │  ${RED}DNS only${NC}  │"
    echo -e "   ${BOLD}└──────────┴──────────────────┴──────────────────┴─────────────┘${NC}"
    
    echo -e "\n${RED}⚠️  IMPORTANT: Proxy must be OFF (grey cloud, not orange!)${NC}"
    
    echo -e "\n${YELLOW}5. Create API Token for SSL certificates:${NC}"
    echo -e "   • Go to: ${CYAN}https://dash.cloudflare.com/profile/api-tokens${NC}"
    echo -e "   • Click: ${CYAN}Create Token${NC}"
    echo -e "   • Use template: ${CYAN}Edit zone DNS${NC}"
    echo -e "   • Zone Resources: ${CYAN}Include → Specific zone → ${domain}${NC}"
    echo -e "   • Click: ${CYAN}Continue → Create Token${NC}"
    echo -e "   • ${RED}Copy the token (shown only once!)${NC}"
    
    echo -e "\n${MAGENTA}═══════════════════════════════════════════════════════════════════${NC}\n"
}

#############################################################################
# Main Installation
#############################################################################

print_banner
check_root

# Get configuration from user
print_step "Configuration"

# Domain
echo -e "${CYAN}Enter your domain name (e.g., example.com):${NC}"
read -p "> " DOMAIN
if [ -z "$DOMAIN" ]; then
    print_error "Domain is required!"
    exit 1
fi

# Server IP
DETECTED_IP=$(detect_ip)
echo -e "\n${CYAN}Enter server public IP [detected: ${DETECTED_IP}]:${NC}"
read -p "> " SERVER_IP
SERVER_IP=${SERVER_IP:-$DETECTED_IP}
if [ -z "$SERVER_IP" ]; then
    print_error "Could not detect server IP. Please enter manually."
    exit 1
fi

# Show Cloudflare instructions
print_cloudflare_instructions "$DOMAIN" "$SERVER_IP"

echo -e "${YELLOW}Have you configured Cloudflare DNS as shown above? (yes/no)${NC}"
read -p "> " DNS_CONFIGURED
if [ "$DNS_CONFIGURED" != "yes" ]; then
    print_warning "Please configure Cloudflare DNS first, then run this script again."
    exit 0
fi

# Cloudflare API Token
echo -e "\n${CYAN}Enter your Cloudflare API Token (for SSL certificate):${NC}"
echo -e "${YELLOW}(Leave empty to skip HTTPS - only HTTP will work)${NC}"
read -p "> " CF_API_TOKEN

# Custom token or generate
echo -e "\n${CYAN}Enter custom authentication token (leave empty to auto-generate):${NC}"
read -p "> " CUSTOM_TOKEN
if [ -z "$CUSTOM_TOKEN" ]; then
    AUTH_TOKEN=$(openssl rand -hex 32)
else
    AUTH_TOKEN="$CUSTOM_TOKEN"
fi

# Email for Let's Encrypt
if [ -n "$CF_API_TOKEN" ]; then
    echo -e "\n${CYAN}Enter email for SSL certificate (e.g., admin@${DOMAIN}):${NC}"
    read -p "> " SSL_EMAIL
    SSL_EMAIL=${SSL_EMAIL:-"admin@${DOMAIN}"}
fi

echo -e "\n${GREEN}Configuration summary:${NC}"
echo -e "  Domain:    ${CYAN}${DOMAIN}${NC}"
echo -e "  Server IP: ${CYAN}${SERVER_IP}${NC}"
echo -e "  Token:     ${CYAN}${AUTH_TOKEN}${NC}"
echo -e "  HTTPS:     ${CYAN}$([ -n "$CF_API_TOKEN" ] && echo "Enabled" || echo "Disabled")${NC}"

echo -e "\n${YELLOW}Continue with installation? (yes/no)${NC}"
read -p "> " CONFIRM
if [ "$CONFIRM" != "yes" ]; then
    echo "Installation cancelled."
    exit 0
fi

#############################################################################
# Step 1: System Update
#############################################################################
print_step "Step 1/8: Updating system packages"

apt update && apt upgrade -y
apt install -y git curl wget build-essential net-tools

print_success "System updated"

#############################################################################
# Step 2: Install Go
#############################################################################
print_step "Step 2/8: Installing Go ${GO_VERSION}"

if [ ! -f "/usr/local/go/bin/go" ]; then
    wget -q --show-progress https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz
    rm -rf /usr/local/go
    tar -C /usr/local -xzf go${GO_VERSION}.linux-amd64.tar.gz
    rm go${GO_VERSION}.linux-amd64.tar.gz
fi

export PATH=$PATH:/usr/local/go/bin:/root/go/bin
echo 'export PATH=$PATH:/usr/local/go/bin:/root/go/bin' >> /etc/profile

print_success "Go installed: $(/usr/local/go/bin/go version)"

#############################################################################
# Step 3: Disable systemd-resolved
#############################################################################
print_step "Step 3/8: Configuring DNS (freeing port 53)"

if systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    systemctl stop systemd-resolved
    systemctl disable systemd-resolved
    print_success "systemd-resolved disabled"
fi

rm -f /etc/resolv.conf
cat > /etc/resolv.conf << EOF
nameserver 8.8.8.8
nameserver 1.1.1.1
EOF

print_success "DNS configured"

#############################################################################
# Step 4: Configure Firewall
#############################################################################
print_step "Step 4/8: Configuring firewall"

# Install UFW if not present
apt install -y ufw

ufw allow 22/tcp    # SSH
ufw allow 53/udp    # DNS
ufw allow 53/tcp    # DNS
ufw allow 80/tcp    # HTTP
ufw allow 443/tcp   # HTTPS
ufw allow 25/tcp    # SMTP
ufw allow 587/tcp   # SMTPS
ufw allow 465/tcp   # SMTP AutoTLS
ufw allow 389/tcp   # LDAP

ufw --force enable
ufw reload

print_success "Firewall configured"

#############################################################################
# Step 5: Build KarmaEcho
#############################################################################
print_step "Step 5/8: Building KarmaEcho"

mkdir -p /opt
cd /opt

if [ -d "karmaecho" ]; then
    cd karmaecho
    git pull || true
else
    git clone ${KARMAECHO_REPO} 2>/dev/null || {
        print_error "Could not clone repository. Please ensure it exists."
        print_info "You can manually place the source code in /opt/karmaecho"
        exit 1
    }
    cd karmaecho
fi

export PATH=$PATH:/usr/local/go/bin
/usr/local/go/bin/go build -o /usr/local/bin/karmaecho-server ./cmd/karmaecho-server/
/usr/local/go/bin/go build -o /usr/local/bin/karmaecho-client ./cmd/karmaecho-client/

chmod +x /usr/local/bin/karmaecho-server
chmod +x /usr/local/bin/karmaecho-client

print_success "KarmaEcho built successfully"

#############################################################################
# Step 6: SSL Certificate (if Cloudflare token provided)
#############################################################################
CERT_ARGS=""

if [ -n "$CF_API_TOKEN" ]; then
    print_step "Step 6/8: Obtaining SSL certificate"
    
    apt install -y certbot python3-certbot-dns-cloudflare
    
    mkdir -p /root/.secrets
    cat > /root/.secrets/cloudflare.ini << EOF
dns_cloudflare_api_token = ${CF_API_TOKEN}
EOF
    chmod 600 /root/.secrets/cloudflare.ini
    
    certbot certonly \
        --dns-cloudflare \
        --dns-cloudflare-credentials /root/.secrets/cloudflare.ini \
        -d "${DOMAIN}" \
        -d "*.${DOMAIN}" \
        --email "${SSL_EMAIL}" \
        --agree-tos \
        --non-interactive || {
            print_warning "SSL certificate failed. Continuing without HTTPS."
            CF_API_TOKEN=""
        }
    
    if [ -n "$CF_API_TOKEN" ]; then
        CERT_ARGS="-cert /etc/letsencrypt/live/${DOMAIN}/fullchain.pem -privkey /etc/letsencrypt/live/${DOMAIN}/privkey.pem"
        print_success "SSL certificate obtained"
    fi
else
    print_step "Step 6/8: Skipping SSL (no Cloudflare token)"
    CERT_ARGS="-skip-acme"
    print_info "HTTPS will be disabled"
fi

#############################################################################
# Step 7: Create systemd service
#############################################################################
print_step "Step 7/8: Creating systemd service"

mkdir -p /var/log/karmaecho
mkdir -p /etc/karmaecho

# Save token
echo "${AUTH_TOKEN}" > /etc/karmaecho/token
chmod 600 /etc/karmaecho/token

# Save configuration
cat > /etc/karmaecho/config << EOF
DOMAIN=${DOMAIN}
SERVER_IP=${SERVER_IP}
AUTH_TOKEN=${AUTH_TOKEN}
EOF
chmod 600 /etc/karmaecho/config

# Create service
cat > /etc/systemd/system/karmaecho.service << EOF
[Unit]
Description=KarmaEcho OOB Interaction Server
Documentation=https://github.com/karmagate/karmaecho
After=network.target

[Service]
Type=simple
User=root
Group=root
WorkingDirectory=/opt/karmaecho
ExecStart=/usr/local/bin/karmaecho-server \\
    -domain ${DOMAIN} \\
    -ip ${SERVER_IP} \\
    -token ${AUTH_TOKEN} \\
    ${CERT_ARGS} \\
    -ws-timeout 120 \\
    -ws-max-conn 100 \\
    -metrics
Restart=always
RestartSec=5
StandardOutput=append:/var/log/karmaecho/server.log
StandardError=append:/var/log/karmaecho/error.log

# Security
NoNewPrivileges=false
ProtectSystem=false

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable karmaecho

print_success "Systemd service created"

#############################################################################
# Step 8: Start service
#############################################################################
print_step "Step 8/8: Starting KarmaEcho"

# Clear logs
> /var/log/karmaecho/server.log
> /var/log/karmaecho/error.log

systemctl start karmaecho
sleep 3

if systemctl is-active --quiet karmaecho; then
    print_success "KarmaEcho is running!"
else
    print_error "Failed to start KarmaEcho"
    echo "Check logs: journalctl -u karmaecho -n 50"
    exit 1
fi

#############################################################################
# Final Output
#############################################################################

echo -e "\n${GREEN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║                                                                   ║"
echo "║   🎉 KarmaEcho Installation Complete!                             ║"
echo "║                                                                   ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

echo -e "${BOLD}Configuration:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${CYAN}Domain:${NC}     ${DOMAIN}"
echo -e "  ${CYAN}Server IP:${NC}  ${SERVER_IP}"
echo -e "  ${CYAN}Token:${NC}      ${AUTH_TOKEN}"
echo -e "  ${CYAN}HTTPS:${NC}      $([ -n "$CF_API_TOKEN" ] && echo "✅ Enabled" || echo "❌ Disabled")"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${BOLD}🔗 Test URLs:${NC}"
echo -e "  HTTP:       ${CYAN}http://${DOMAIN}${NC}"
if [ -n "$CF_API_TOKEN" ]; then
    echo -e "  HTTPS:      ${CYAN}https://${DOMAIN}${NC}"
    echo -e "  WebSocket:  ${CYAN}wss://[id].${DOMAIN}/ws${NC}"
else
    echo -e "  WebSocket:  ${CYAN}ws://[id].${DOMAIN}/ws${NC}"
fi

echo -e "\n${BOLD}🖥️  Client Usage:${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo -e "  ${GREEN}karmaecho-client -s ${DOMAIN} -t ${AUTH_TOKEN}${NC}"
echo -e "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

echo -e "\n${BOLD}📋 Payload Examples:${NC}"
echo -e "  DNS:        ${CYAN}test.${DOMAIN}${NC}"
echo -e "  HTTP:       ${CYAN}http://[correlation-id].${DOMAIN}${NC}"
if [ -n "$CF_API_TOKEN" ]; then
    echo -e "  HTTPS:      ${CYAN}https://[correlation-id].${DOMAIN}${NC}"
fi
echo -e "  SMTP:       ${CYAN}test@[correlation-id].${DOMAIN}${NC}"
echo -e "  LDAP:       ${CYAN}ldap://[correlation-id].${DOMAIN}${NC}"
echo -e "  WebSocket:  ${CYAN}ws(s)://[correlation-id].${DOMAIN}/ws${NC}"

echo -e "\n${BOLD}🔧 Service Commands:${NC}"
echo -e "  Status:     ${YELLOW}systemctl status karmaecho${NC}"
echo -e "  Start:      ${YELLOW}systemctl start karmaecho${NC}"
echo -e "  Stop:       ${YELLOW}systemctl stop karmaecho${NC}"
echo -e "  Restart:    ${YELLOW}systemctl restart karmaecho${NC}"
echo -e "  Logs:       ${YELLOW}tail -f /var/log/karmaecho/server.log${NC}"
echo -e "  Errors:     ${YELLOW}tail -f /var/log/karmaecho/error.log${NC}"

echo -e "\n${BOLD}📁 Important Files:${NC}"
echo -e "  Token:      ${YELLOW}/etc/karmaecho/token${NC}"
echo -e "  Config:     ${YELLOW}/etc/karmaecho/config${NC}"
echo -e "  Service:    ${YELLOW}/etc/systemd/system/karmaecho.service${NC}"
echo -e "  Logs:       ${YELLOW}/var/log/karmaecho/${NC}"
if [ -n "$CF_API_TOKEN" ]; then
    echo -e "  SSL Certs:  ${YELLOW}/etc/letsencrypt/live/${DOMAIN}/${NC}"
fi

echo -e "\n${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}      KarmaEcho is ready! Happy hunting!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}\n"

# Save installation info
cat > /etc/karmaecho/install-info.txt << EOF
KarmaEcho Installation Info
===========================
Installed: $(date)
Domain: ${DOMAIN}
Server IP: ${SERVER_IP}
Token: ${AUTH_TOKEN}
HTTPS: $([ -n "$CF_API_TOKEN" ] && echo "Enabled" || echo "Disabled")

Client command:
karmaecho-client -s ${DOMAIN} -t ${AUTH_TOKEN}
EOF

echo -e "${YELLOW}💾 Installation info saved to: /etc/karmaecho/install-info.txt${NC}\n"
