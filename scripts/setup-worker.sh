#!/bin/bash
# ============================================
# Hermes VPS Cluster - Worker Setup Script
# Version: 2.1.0 (Safe Mode)
# Description: Configure a Hermes Agent VPS as a cluster worker
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       Hermes VPS Cluster - Worker Setup          ║"
echo "║                  v2.1.0 Safe Mode                ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# Prerequisite Checks
# ============================================
echo -e "${YELLOW}[1/6] Checking prerequisites...${NC}"

# Check Hermes
if ! command -v hermes &> /dev/null; then
    echo -e "${RED}ERROR: Hermes Agent not found${NC}"
    echo "Install first: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash"
    exit 1
fi
echo -e "${GREEN}  ✓ Hermes Agent found${NC}"

# Check config directory
if [ ! -d "$HOME/.hermes" ]; then
    echo -e "${RED}ERROR: Hermes not configured. Run 'hermes setup' first${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Hermes config found${NC}"

# Check if gateway is running BEFORE changes
echo ""
echo -e "${YELLOW}[2/6] Checking current gateway status...${NC}"

GATEWAY_WAS_RUNNING=false
if hermes gateway status 2>/dev/null | grep -qi "running"; then
    GATEWAY_WAS_RUNNING=true
    echo -e "${GREEN}  ✓ Gateway is running${NC}"
else
    echo -e "${YELLOW}  ⚠ Gateway is not running (will start after setup)${NC}"
fi

# ============================================
# Backup Current Config
# ============================================
echo ""
echo -e "${YELLOW}[3/6] Creating backups...${NC}"

BACKUP_DIR="$HOME/.hermes/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

# Backup .env
if [ -f "$HOME/.hermes/.env" ]; then
    cp "$HOME/.hermes/.env" "$BACKUP_DIR/.env.backup"
    echo -e "${GREEN}  ✓ .env backed up${NC}"
fi

# Backup config.yaml
if [ -f "$HOME/.hermes/config.yaml" ]; then
    cp "$HOME/.hermes/config.yaml" "$BACKUP_DIR/config.yaml.backup"
    echo -e "${GREEN}  ✓ config.yaml backed up${NC}"
fi

echo -e "${GREEN}  ✓ Backups saved to: $BACKUP_DIR${NC}"

# ============================================
# Generate API Key
# ============================================
echo ""
echo -e "${YELLOW}[4/6] Generating API key...${NC}"

API_KEY=$(openssl rand -hex 32)

# Save to file
echo "$API_KEY" > "$HOME/.hermes/.worker_api_key"
chmod 600 "$HOME/.hermes/.worker_api_key"

echo -e "${GREEN}  ✓ API key generated${NC}"

# ============================================
# Configure Environment (.env)
# ============================================
echo ""
echo -e "${YELLOW}[5/6] Configuring environment...${NC}"

ENV_FILE="$HOME/.hermes/.env"

# Remove old API_SERVER config if exists
if [ -f "$ENV_FILE" ]; then
    # Create temp file without old config
    grep -v "^API_SERVER_" "$ENV_FILE" > "${ENV_FILE}.tmp" 2>/dev/null || true
    mv "${ENV_FILE}.tmp" "$ENV_FILE"
fi

# Add new config
cat >> "$ENV_FILE" << EOF

# === Hermes VPS Cluster - Worker Config ===
API_SERVER_ENABLED=true
API_SERVER_PORT=8642
API_SERVER_HOST=0.0.0.0
API_SERVER_KEY=$API_KEY
EOF

echo -e "${GREEN}  ✓ Environment configured${NC}"

# ============================================
# Configure YAML (SAFE - only add if not exists)
# ============================================
CONFIG_FILE="$HOME/.hermes/config.yaml"

# Check if api_server already configured
if grep -q "api_server:" "$CONFIG_FILE" 2>/dev/null; then
    echo -e "${YELLOW}  ⚠ API server config already exists, skipping${NC}"
else
    # Add api_server config
    cat >> "$CONFIG_FILE" << EOF

# === Hermes VPS Cluster - API Server ===
api_server:
  enabled: true
  port: 8642
  host: "0.0.0.0"
EOF
    echo -e "${GREEN}  ✓ API server config added${NC}"
fi

# ============================================
# Configure Firewall
# ============================================
if command -v ufw &> /dev/null; then
    if ! sudo ufw status | grep -q "8642/tcp"; then
        sudo ufw allow 8642/tcp comment "Hermes VPS Cluster" 2>/dev/null || true
        echo -e "${GREEN}  ✓ Port 8642 opened${NC}"
    fi
fi

# ============================================
# Test Config Before Restart
# ============================================
echo ""
echo -e "${YELLOW}[6/6] Validating config...${NC}"

# Test YAML syntax
if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Config YAML valid${NC}"
else
    echo -e "${RED}  ✗ Config YAML invalid!${NC}"
    echo -e "${YELLOW}  Restoring backup...${NC}"
    
    if [ -f "$BACKUP_DIR/config.yaml.backup" ]; then
        cp "$BACKUP_DIR/config.yaml.backup" "$CONFIG_FILE"
        echo -e "${GREEN}  ✓ Config restored from backup${NC}"
    fi
    
    echo -e "${RED}  Setup failed. Please check your config manually.${NC}"
    exit 1
fi

# ============================================
# Restart Gateway (with rollback on failure)
# ============================================
echo ""
echo -e "${YELLOW}Restarting gateway...${NC}"

# Stop gateway
hermes gateway stop 2>/dev/null || true
sleep 2

# Start gateway
if hermes gateway start 2>&1; then
    sleep 3
    
    # Check if gateway started successfully
    if hermes gateway status 2>/dev/null | grep -qi "running"; then
        echo -e "${GREEN}  ✓ Gateway started successfully${NC}"
    else
        echo -e "${RED}  ✗ Gateway failed to start!${NC}"
        echo -e "${YELLOW}  Rolling back changes...${NC}"
        
        # Rollback
        if [ -f "$BACKUP_DIR/.env.backup" ]; then
            cp "$BACKUP_DIR/.env.backup" "$HOME/.hermes/.env"
        fi
        if [ -f "$BACKUP_DIR/config.yaml.backup" ]; then
            cp "$BACKUP_DIR/config.yaml.backup" "$CONFIG_FILE"
        fi
        
        # Try to start with old config
        hermes gateway start 2>/dev/null || true
        
        echo -e "${RED}  Setup failed. Changes rolled back.${NC}"
        echo -e "${YELLOW}  Backup saved at: $BACKUP_DIR${NC}"
        exit 1
    fi
else
    echo -e "${RED}  ✗ Gateway start command failed!${NC}"
    echo -e "${YELLOW}  Rolling back changes...${NC}"
    
    # Rollback
    if [ -f "$BACKUP_DIR/.env.backup" ]; then
        cp "$BACKUP_DIR/.env.backup" "$HOME/.hermes/.env"
    fi
    if [ -f "$BACKUP_DIR/config.yaml.backup" ]; then
        cp "$BACKUP_DIR/config.yaml.backup" "$CONFIG_FILE"
    fi
    
    hermes gateway start 2>/dev/null || true
    
    echo -e "${RED}  Setup failed. Changes rolled back.${NC}"
    exit 1
fi

# ============================================
# Verify API Server
# ============================================
echo ""
echo -e "${YELLOW}Verifying API server...${NC}"

sleep 2

if curl -s -m 5 http://localhost:8642/health | grep -q "ok"; then
    echo -e "${GREEN}  ✓ API server is running${NC}"
else
    echo -e "${YELLOW}  ⚠ API server not responding (may need more time)${NC}"
fi

# ============================================
# Success!
# ============================================
IP=$(hostname -I | awk '{print $1}')

echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}✓ Worker setup complete!${NC}"
echo ""
echo -e "  Send this to your ${BLUE}Master Bot${NC} admin:"
echo ""
echo -e "  ${YELLOW}┌─────────────────────────────────────────────┐${NC}"
echo -e "  ${YELLOW}│${NC}  Hostname  : $(hostname)"
echo -e "  ${YELLOW}│${NC}  IP Address: ${GREEN}$IP${NC}"
echo -e "  ${YELLOW}│${NC}  Port      : 8642"
echo -e "  ${YELLOW}│${NC}  API Key   : ${GREEN}$API_KEY${NC}"
echo -e "  ${YELLOW}└─────────────────────────────────────────────┘${NC}"
echo ""
echo -e "  ${YELLOW}Backup location:${NC} $BACKUP_DIR"
echo ""
echo -e "  ${YELLOW}If something went wrong, restore backup:${NC}"
echo "    cp $BACKUP_DIR/.env.backup ~/.hermes/.env"
echo "    cp $BACKUP_DIR/config.yaml.backup ~/.hermes/config.yaml"
echo "    hermes gateway stop && hermes gateway start"
echo ""
