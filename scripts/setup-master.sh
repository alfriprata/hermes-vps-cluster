#!/bin/bash
# ============================================
# Hermes VPS Cluster - Master Setup Script
# Version: 2.1.0 (Safe Mode)
# Description: Configure a Hermes Agent VPS as the cluster master
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       Hermes VPS Cluster - Master Setup          ║"
echo "║                  v2.1.0 Safe Mode                ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# ============================================
# Prerequisite Checks
# ============================================
echo -e "${YELLOW}[1/7] Checking prerequisites...${NC}"

if ! command -v hermes &> /dev/null; then
    echo -e "${RED}ERROR: Hermes Agent not found${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Hermes Agent found${NC}"

if [ ! -d "$HOME/.hermes" ]; then
    echo -e "${RED}ERROR: Hermes not configured${NC}"
    exit 1
fi
echo -e "${GREEN}  ✓ Hermes config found${NC}"

# ============================================
# Backup Current Config
# ============================================
echo ""
echo -e "${YELLOW}[2/7] Creating backups...${NC}"

BACKUP_DIR="$HOME/.hermes/backups/$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"

if [ -f "$HOME/.hermes/.env" ]; then
    cp "$HOME/.hermes/.env" "$BACKUP_DIR/.env.backup"
    echo -e "${GREEN}  ✓ .env backed up${NC}"
fi

if [ -f "$HOME/.hermes/config.yaml" ]; then
    cp "$HOME/.hermes/config.yaml" "$BACKUP_DIR/config.yaml.backup"
    echo -e "${GREEN}  ✓ config.yaml backed up${NC}"
fi

if [ -f "$HOME/.hermes/workers.json" ]; then
    cp "$HOME/.hermes/workers.json" "$BACKUP_DIR/workers.json.backup"
    echo -e "${GREEN}  ✓ workers.json backed up${NC}"
fi

echo -e "${GREEN}  ✓ Backups saved to: $BACKUP_DIR${NC}"

# ============================================
# Collect Worker Information
# ============================================
echo ""
echo -e "${YELLOW}[3/7] Configure Worker Bots${NC}"
echo ""
echo "Enter worker bot details."
echo -e "${CYAN}Press Enter with empty IP to finish.${NC}"
echo ""

WORKERS_JSON='{"workers":['
FIRST=true
WORKER_COUNT=0

for i in 2 3 4 5 6 7 8 9; do
    echo -e "${CYAN}Worker Bot $i:${NC}"
    read -p "  IP Address (skip if done): " IP
    
    if [ -z "$IP" ]; then
        if [ $WORKER_COUNT -eq 0 ] && [ $i -eq 2 ]; then
            echo -e "${RED}  At least one worker is required!${NC}"
            continue
        fi
        break
    fi
    
    read -p "  API Key: " API_KEY
    
    if [ -z "$API_KEY" ]; then
        echo -e "${RED}  API key cannot be empty${NC}"
        continue
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
echo -e "${YELLOW}[4/7] Saving worker configuration...${NC}"

WORKERS_FILE="$HOME/.hermes/workers.json"
echo "$WORKERS_JSON" > "$WORKERS_FILE"
chmod 600 "$WORKERS_FILE"

echo -e "${GREEN}  ✓ Workers config saved${NC}"

# ============================================
# Test Worker Connections
# ============================================
echo ""
echo -e "${YELLOW}[5/7] Testing worker connections...${NC}"

FAILED_CONNECTIONS=0

while IFS='|' read -r name ip port api_key; do
    echo -n "  Testing $name ($ip:$port)... "
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/health" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}OK${NC}"
    else
        echo -e "${RED}FAILED (HTTP $HTTP_CODE)${NC}"
        FAILED_CONNECTIONS=$((FAILED_CONNECTIONS + 1))
    fi
done < <(echo "$WORKERS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data['workers']:
    print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null)

if [ $FAILED_CONNECTIONS -gt 0 ]; then
    echo ""
    echo -e "${YELLOW}  ⚠ $FAILED_CONNECTIONS worker(s) not reachable${NC}"
    echo -e "${YELLOW}  You can continue setup, but those workers won't work until they're online.${NC}"
    echo ""
    read -p "  Continue anyway? (y/n): " CONTINUE
    if [ "$CONTINUE" != "y" ] && [ "$CONTINUE" != "Y" ]; then
        echo "Setup cancelled."
        exit 0
    fi
fi

# ============================================
# Update Hermes Config
# ============================================
echo ""
echo -e "${YELLOW}[6/7] Updating Hermes config...${NC}"

CONFIG_FILE="$HOME/.hermes/config.yaml"

# Remove old cluster config if exists
if grep -q "# === Hermes VPS Cluster ===" "$CONFIG_FILE" 2>/dev/null; then
    sed '/# === Hermes VPS Cluster ===/,/# === End Hermes VPS Cluster ===/d' "$CONFIG_FILE" > "${CONFIG_FILE}.tmp"
    mv "${CONFIG_FILE}.tmp" "$CONFIG_FILE"
    echo -e "${GREEN}  ✓ Old cluster config removed${NC}"
fi

# Generate MCP config
MCP_CONFIG="# === Hermes VPS Cluster ===\nmcp_servers:\n"

while IFS='|' read -r name ip api_key; do
    MCP_CONFIG+="  ${name}:\n"
    MCP_CONFIG+="    url: \"http://${ip}:8642/mcp\"\n"
    MCP_CONFIG+="    headers:\n"
    MCP_CONFIG+="      Authorization: \"Bearer ${api_key}\"\n"
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

echo -e "${GREEN}  ✓ MCP servers configured${NC}"

# ============================================
# Install Skill
# ============================================
echo ""
echo -e "${YELLOW}Installing cluster skill...${NC}"

SKILL_DIR="$HOME/.hermes/skills/hermes-vps-cluster"
mkdir -p "$SKILL_DIR"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILL_SOURCE="$SCRIPT_DIR/../skills/hermes-vps-cluster"

if [ -d "$SKILL_SOURCE" ]; then
    cp -r "$SKILL_SOURCE/"* "$SKILL_DIR/"
    chmod +x "$SKILL_DIR"/*.sh 2>/dev/null || true
    echo -e "${GREEN}  ✓ Skill installed${NC}"
else
    echo -e "${YELLOW}  ⚠ Skill files not found (install manually later)${NC}"
fi

# ============================================
# Validate Config Before Restart
# ============================================
echo ""
echo -e "${YELLOW}[7/7] Validating config...${NC}"

if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
    echo -e "${GREEN}  ✓ Config YAML valid${NC}"
else
    echo -e "${RED}  ✗ Config YAML invalid!${NC}"
    echo -e "${YELLOW}  Restoring backup...${NC}"
    
    if [ -f "$BACKUP_DIR/config.yaml.backup" ]; then
        cp "$BACKUP_DIR/config.yaml.backup" "$CONFIG_FILE"
    fi
    
    echo -e "${RED}  Setup failed. Config restored.${NC}"
    exit 1
fi

# ============================================
# Restart Gateway (with rollback)
# ============================================
echo ""
echo -e "${YELLOW}Restarting gateway...${NC}"

hermes gateway stop 2>/dev/null || true
sleep 2

if hermes gateway start 2>&1; then
    sleep 3
    
    if hermes gateway status 2>/dev/null | grep -qi "running"; then
        echo -e "${GREEN}  ✓ Gateway started successfully${NC}"
    else
        echo -e "${RED}  ✗ Gateway failed to start!${NC}"
        echo -e "${YELLOW}  Rolling back...${NC}"
        
        [ -f "$BACKUP_DIR/.env.backup" ] && cp "$BACKUP_DIR/.env.backup" "$HOME/.hermes/.env"
        [ -f "$BACKUP_DIR/config.yaml.backup" ] && cp "$BACKUP_DIR/config.yaml.backup" "$CONFIG_FILE"
        
        hermes gateway start 2>/dev/null || true
        
        echo -e "${RED}  Setup failed. Changes rolled back.${NC}"
        echo -e "${YELLOW}  Backup at: $BACKUP_DIR${NC}"
        exit 1
    fi
else
    echo -e "${RED}  ✗ Gateway start failed!${NC}"
    
    [ -f "$BACKUP_DIR/.env.backup" ] && cp "$BACKUP_DIR/.env.backup" "$HOME/.hermes/.env"
    [ -f "$BACKUP_DIR/config.yaml.backup" ] && cp "$BACKUP_DIR/config.yaml.backup" "$CONFIG_FILE"
    
    hermes gateway start 2>/dev/null || true
    
    echo -e "${RED}  Setup failed. Changes rolled back.${NC}"
    exit 1
fi

# ============================================
# Success
# ============================================
echo ""
echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}✓ Master setup complete!${NC}"
echo ""
echo -e "  Connected workers: ${CYAN}$WORKER_COUNT${NC}"
echo ""

echo "$WORKERS_JSON" | python3 -c "
import json, sys
data = json.load(sys.stdin)
for w in data['workers']:
    print(f\"  • {w['name']}: {w['ip']}\")
" 2>/dev/null

echo ""
echo -e "  ${YELLOW}Next steps:${NC}"
echo "    1. Open Telegram → chat with Master bot"
echo "    2. Send: /reload-mcp"
echo "    3. Send: /check_workers"
echo ""
echo -e "  ${YELLOW}Backup location:${NC} $BACKUP_DIR"
echo ""
echo -e "  ${YELLOW}If something went wrong:${NC}"
echo "    cp $BACKUP_DIR/config.yaml.backup ~/.hermes/config.yaml"
echo "    cp $BACKUP_DIR/workers.json.backup ~/.hermes/workers.json"
echo "    hermes gateway stop && hermes gateway start"
echo ""
