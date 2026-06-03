#!/bin/bash
# ============================================
# Hermes VPS Cluster - Worker Setup Script
# Version: 1.0.0
# Description: Configure a Hermes Agent VPS as a cluster worker
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       Hermes VPS Cluster - Worker Setup          ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Check if Hermes is installed
if ! command -v hermes &> /dev/null; then
    echo -e "${RED}ERROR: Hermes Agent is not installed${NC}"
    echo "Install it first: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    exit 1
fi

echo -e "${GREEN}✓ Hermes Agent found${NC}"

# Check if gateway is configured
if [ ! -d "$HOME/.hermes" ]; then
    echo -e "${RED}ERROR: Hermes not configured. Run 'hermes setup' first${NC}"
    exit 1
fi

echo -e "${GREEN}✓ Hermes configuration found${NC}"
echo ""

# ============================================
# Generate API Key
# ============================================
echo -e "${YELLOW}Step 1: Generating API Key...${NC}"

API_KEY=$(openssl rand -hex 32)

# Save to file
echo "$API_KEY" > "$HOME/.hermes/.worker_api_key"
chmod 600 "$HOME/.hermes/.worker_api_key"

echo -e "${GREEN}✓ API key generated${NC}"

# ============================================
# Configure Environment
# ============================================
echo ""
echo -e "${YELLOW}Step 2: Configuring environment...${NC}"

ENV_FILE="$HOME/.hermes/.env"

# Check if API_SERVER already configured
if grep -q "API_SERVER_ENABLED" "$ENV_FILE" 2>/dev/null; then
    echo -e "${YELLOW}  API server already configured, updating...${NC}"
    # Remove old config
    sed -i '/API_SERVER_ENABLED/d' "$ENV_FILE"
    sed -i '/API_SERVER_PORT/d' "$ENV_FILE"
    sed -i '/API_SERVER_HOST/d' "$ENV_FILE"
    sed -i '/API_SERVER_KEY/d' "$ENV_FILE"
fi

# Add new config
cat >> "$ENV_FILE" << EOF

# === Hermes VPS Cluster - Worker Config ===
API_SERVER_ENABLED=true
API_SERVER_PORT=8642
API_SERVER_HOST=0.0.0.0
API_SERVER_KEY=$API_KEY
EOF

echo -e "${GREEN}✓ Environment configured${NC}"

# ============================================
# Configure YAML
# ============================================
echo ""
echo -e "${YELLOW}Step 3: Updating Hermes config...${NC}"

CONFIG_FILE="$HOME/.hermes/config.yaml"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}  ✓ Config backed up${NC}"
fi

# Check if api_server section exists
if ! grep -q "api_server:" "$CONFIG_FILE" 2>/dev/null; then
    cat >> "$CONFIG_FILE" << EOF

# === Hermes VPS Cluster - API Server ===
api_server:
  enabled: true
  port: 8642
  host: "0.0.0.0"
EOF
    echo -e "${GREEN}✓ API server config added${NC}"
else
    echo -e "${YELLOW}  API server config already exists, skipping${NC}"
fi

# ============================================
# Configure Firewall
# ============================================
echo ""
echo -e "${YELLOW}Step 4: Configuring firewall...${NC}"

if command -v ufw &> /dev/null; then
    # Check if port is already allowed
    if sudo ufw status | grep -q "8642/tcp"; then
        echo -e "${YELLOW}  Port 8642 already allowed${NC}"
    else
        sudo ufw allow 8642/tcp comment "Hermes VPS Cluster - API Server"
        echo -e "${GREEN}✓ Port 8642 opened${NC}"
    fi
elif command -v firewall-cmd &> /dev/null; then
    sudo firewall-cmd --permanent --add-port=8642/tcp
    sudo firewall-cmd --reload
    echo -e "${GREEN}✓ Port 8642 opened (firewalld)${NC}"
else
    echo -e "${YELLOW}  WARNING: No firewall detected. Ensure port 8642 is accessible.${NC}"
fi

# ============================================
# Restart Gateway
# ============================================
echo ""
echo -e "${YELLOW}Step 5: Restarting Hermes gateway...${NC}"

hermes gateway stop 2>/dev/null || true
sleep 2
hermes gateway install 2>/dev/null || true
hermes gateway start

echo -e "${GREEN}✓ Gateway restarted${NC}"

# ============================================
# Verify
# ============================================
echo ""
echo -e "${YELLOW}Step 6: Verifying setup...${NC}"

sleep 3

# Test health endpoint
if curl -s -m 5 http://localhost:8642/health | grep -q "ok"; then
    echo -e "${GREEN}✓ API server is running${NC}"
else
    echo -e "${RED}✗ API server not responding${NC}"
    echo "  Try: hermes gateway status"
    echo "  Check: tail -f ~/.hermes/logs/gateway.log"
fi

# Get IP address
IP=$(hostname -I | awk '{print $1}')

# ============================================
# Display Results
# ============================================
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
echo -e "║            Worker Setup Complete!                 ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Send this information to the ${GREEN}Master Bot${NC} setup:"
echo ""
echo -e "  ${YELLOW}┌─────────────────────────────────────────┐${NC}"
echo -e "  ${YELLOW}│${NC}  Worker Name : $(hostname)"
echo -e "  ${YELLOW}│${NC}  IP Address  : ${GREEN}$IP${NC}"
echo -e "  ${YELLOW}│${NC}  Port        : 8642"
echo -e "  ${YELLOW}│${NC}  API Key     : ${GREEN}$API_KEY${NC}"
echo -e "  ${YELLOW}└─────────────────────────────────────────┘${NC}"
echo ""
echo -e "  API Key saved to: ${BLUE}~/.hermes/.worker_api_key${NC}"
echo ""

# Verification commands
echo -e "${YELLOW}Verification commands:${NC}"
echo "  curl -s http://localhost:8642/health"
echo "  curl -s -H 'Authorization: Bearer $API_KEY' http://localhost:8642/v1/models"
echo ""
echo -e "${GREEN}Setup complete! This VPS is now a cluster worker.${NC}"
