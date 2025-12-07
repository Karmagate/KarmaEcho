#!/bin/bash

#############################################################################
#   KarmaEcho Update Script
#############################################################################

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}"
echo "╔═══════════════════════════════════════════════════════════════════╗"
echo "║            KarmaEcho Server - Update Script                       ║"
echo "╚═══════════════════════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check root
if [ "$EUID" -ne 0 ]; then
    echo -e "${RED}Please run as root: sudo $0${NC}"
    exit 1
fi

# Check if installed
if [ ! -d "/opt/karmaecho" ]; then
    echo -e "${RED}KarmaEcho not found in /opt/karmaecho${NC}"
    echo -e "${YELLOW}Please install first using install-karmaecho.sh${NC}"
    exit 1
fi

echo -e "${YELLOW}[1/4] Pulling latest changes...${NC}"
cd /opt/karmaecho
git pull

echo -e "${YELLOW}[2/4] Building server...${NC}"
/usr/local/go/bin/go build -o /usr/local/bin/karmaecho-server ./cmd/karmaecho-server/

echo -e "${YELLOW}[3/4] Building client...${NC}"
/usr/local/go/bin/go build -o /usr/local/bin/karmaecho-client ./cmd/karmaecho-client/

echo -e "${YELLOW}[4/4] Restarting service...${NC}"
systemctl restart karmaecho
sleep 2

if systemctl is-active --quiet karmaecho; then
    echo -e "\n${GREEN}✅ KarmaEcho updated successfully!${NC}"
    echo -e "${CYAN}Version: $(karmaecho-server -version 2>&1 | head -1 || echo 'latest')${NC}"
else
    echo -e "\n${RED}❌ Service failed to start${NC}"
    echo -e "${YELLOW}Check logs: journalctl -u karmaecho -n 20${NC}"
    exit 1
fi
