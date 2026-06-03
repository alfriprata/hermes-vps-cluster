#!/bin/bash
# ============================================
# Hermes VPS Cluster - Master Setup Script
# Version: 1.0.0
# Description: Configure a Hermes Agent VPS as the cluster master
# ============================================

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       Hermes VPS Cluster - Master Setup          ║"
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
# Collect Worker Information
# ============================================
echo -e "${YELLOW}Step 1: Configure Worker Bots${NC}"
echo ""
echo "Enter the connection details for each worker bot."
echo "Press Enter with empty IP to skip a worker."
echo ""

WORKERS_JSON='{"workers":['
FIRST=true
WORKER_COUNT=0

for i in 2 3 4 5 6 7 8 9; do
    echo -e "${CYAN}--- Worker Bot $i ---${NC}"
    read -p "  IP Address (skip if done): " IP
    
    if [ -z "$IP" ]; then
        if [ $WORKER_COUNT -eq 0 ] && [ $i -eq 2 ]; then
            echo -e "${RED}  ERROR: At least one worker is required${NC}"
            exit 1
        fi
        break
    fi
    
    read -p "  API Key: " API_KEY
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}  ERROR: API key cannot be empty${NC}"
        exit 1
    fi
    
    read -p "  Worker Name [bot$i]: " NAME
    NAME=${NAME:-bot$i}
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        WORKERS_JSON+=","
    fi
    
    WORKERS_JSON+="{\"name\":\"$NAME\",\"ip\":\"$IP\",\"port\":8642,\"api_key\":\"$API_KEY\",\"enabled\":true}"
    WORKER_COUNT=$((WORKER_COUNT + 1))
    
    echo -e "${GREEN}  ✓ Worker $NAME added${NC}"
    echo ""
done

WORKERS_JSON+=']}'

if [ $WORKER_COUNT -eq 0 ]; then
    echo -e "${RED}ERROR: No workers configured${NC}"
    exit 1
fi

# ============================================
# Save Worker Configuration
# ============================================
echo ""
echo -e "${YELLOW}Step 2: Saving worker configuration...${NC}"

WORKERS_FILE="$HOME/.hermes/workers.json"

# Backup existing
if [ -f "$WORKERS_FILE" ]; then
    cp "$WORKERS_FILE" "${WORKERS_FILE}.backup.$(date +%Y%m%d%H%M%S)"
fi

echo "$WORKERS_JSON" > "$WORKERS_FILE"
chmod 600 "$WORKERS_FILE"

echo -e "${GREEN}✓ Workers config saved to $WORKERS_FILE${NC}"

# ============================================
# Update Hermes Config
# ============================================
echo ""
echo -e "${YELLOW}Step 3: Updating Hermes config...${NC}"

CONFIG_FILE="$HOME/.hermes/config.yaml"

# Backup existing config
if [ -f "$CONFIG_FILE" ]; then
    cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    echo -e "${GREEN}  ✓ Config backed up${NC}"
fi

# Remove old MCP server config if exists
if grep -q "# === Hermes VPS Cluster ===" "$CONFIG_FILE" 2>/dev/null; then
    # Create temp file without old config
    sed '/# === Hermes VPS Cluster ===/,/# === End Hermes VPS Cluster ===/d' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "${GREEN}  ✓ Old cluster config removed${NC}"
fi

# Generate MCP config from workers.json
MCP_CONFIG="# === Hermes VPS Cluster ===\nmcp_servers:\n"

while IFS= read -r line; do
    NAME=$(echo "$line" | cut -d'|' -f1)
    IP=$(echo "$line" | cut -d'|' -f2)
    API_KEY=$(echo "$line" | cut -d'|' -f3)
    
    MCP_CONFIG+="  ${NAME}:\n"
    MCP_CONFIG+="    url: \"http://${IP}:8642/mcp\"\n"
    MCP_CONFIG+="    headers:\n"
    MCP_CONFIG+="      Authorization: \"Bearer ${API_KEY}\"\n"
    MCP_CONFIG+="    timeout: 30\n"
    MCP_CONFIG+="    enabled: true\n"
done < <(echo "$WORKERS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data['workers']:
    print(f\"{w['name']}|{w['ip']}|{w['api_key']}\")
" 2>/dev/null)

MCP_CONFIG+="# === End Hermes VPS Cluster ==="

echo -e "$MCP_CONFIG" >> "$CONFIG_FILE"

echo -e "${GREEN}✓ MCP servers configured${NC}"

# ============================================
# Install Skill
# ============================================
echo ""
echo -e "${YELLOW}Step 4: Installing cluster skill...${NC}"

SKILL_DIR="$HOME/.hermes/skills/hermes-vps-cluster"
mkdir -p "$SKILL_DIR"

# Copy skill files (assuming script is run from repo root)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/../skills/hermes-vps-cluster"

if [ -d "$SKILL_SOURCE" ]; then
    cp -r "$SKILL_SOURCE/"* "$SKILL_DIR/"
    chmod +x "$SKILL_DIR"/*.sh 2>/dev/null || true
    echo -e "${GREEN}✓ Skill installed${NC}"
else
    echo -e "${YELLOW}  WARNING: Skill files not found. Install manually later.${NC}"
fi

# ============================================
# Test Connections
# ============================================
echo ""
echo -e "${YELLOW}Step 5: Testing worker connections...${NC}"

echo "$WORKERS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data['workers']:
    print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null | while IFS='|' read -r name ip port api_key; do
    echo -n "  Testing $name ($ip:$port)... "
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/health" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED (HTTP $HTTP_CODE)${NC}"
    fi
done

# ============================================
# Restart Gateway
# ============================================
echo ""
echo -e "${YELLOW}Step 6: Restarting Hermes gateway...${NC}"

hermes gateway stop 2>/dev/null || true
sleep 2
hermes gateway install 2>/dev/null || true
hermes gateway start

echo -e "${GREEN}✓ Gateway restarted${NC}"

# ============================================
# Display Results
# ============================================
echo ""
echo -e "${BLUE}╔══════════════════════════════════════════════════╗"
echo -e "║            Master Setup Complete!                 ║"
echo -e "╚══════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "Connected workers: ${GREEN}$WORKER_COUNT${NC}"
echo ""

echo "$WORKERS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data['workers']:
    print(f\"  - {w['name']}: {w['ip']}:{w['port']}\")
" 2>/dev/null

echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Open Telegram and chat with your Master bot"
echo "  2. Run: /reload-mcp"
echo "  3. Run: /check_workers"
echo ""
echo -e "${GREEN}Setup complete! Your VPS cluster is ready.${NC}"
