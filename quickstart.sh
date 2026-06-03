#!/bin/bash
# ============================================
# Hermes VPS Cluster - Quickstart Script
# Version: 1.0.0
# Description: One-command setup for the entire cluster
# ============================================
#
# USAGE:
#   On Master VPS:  curl -fsSL https://raw.githubusercontent.com/.../quickstart.sh | bash
#   On Worker VPS:  curl -fsSL https://raw.githubusercontent.com/.../quickstart.sh | bash -s -- --worker
#
# Or download and run:
#   chmod +x quickstart.sh
#   ./quickstart.sh          # For master
#   ./quickstart.sh --worker # For worker
# ============================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Version
VERSION="1.0.0"

# ============================================
# Banner
# ============================================
show_banner() {
    echo -e "${BLUE}"
    echo "╔══════════════════════════════════════════════════════╗"
    echo "║                                                      ║"
    echo "║       Hermes VPS Cluster - Quickstart v${VERSION}       ║"
    echo "║                                                      ║"
    echo "║   Distribute Hermes Agent across multiple VPS        ║"
    echo "║   with automatic storage-based load balancing        ║"
    echo "║                                                      ║"
    echo "╚══════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

# ============================================
# Check Prerequisites
# ============================================
check_prerequisites() {
    echo -e "${YELLOW}Checking prerequisites...${NC}"
    
    local errors=0
    
    # Check Hermes
    if command -v hermes &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Hermes Agent installed"
    else
        echo -e "  ${RED}✗${NC} Hermes Agent not found"
        echo -e "    ${YELLOW}Install: curl -fsSL https://hermes-agent.nousresearch.com/install.sh | bash${NC}"
        errors=$((errors + 1))
    fi
    
    # Check Python3
    if command -v python3 &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} Python3 installed"
    else
        echo -e "  ${RED}✗${NC} Python3 not found"
        echo -e "    ${YELLOW}Install: sudo apt install python3${NC}"
        errors=$((errors + 1))
    fi
    
    # Check curl
    if command -v curl &> /dev/null; then
        echo -e "  ${GREEN}✓${NC} curl installed"
    else
        echo -e "  ${RED}✗${NC} curl not found"
        echo -e "    ${YELLOW}Install: sudo apt install curl${NC}"
        errors=$((errors + 1))
    fi
    
    # Check Hermes config
    if [ -d "$HOME/.hermes" ]; then
        echo -e "  ${GREEN}✓${NC} Hermes configured"
    else
        echo -e "  ${RED}✗${NC} Hermes not configured"
        echo -e "    ${YELLOW}Run: hermes setup${NC}"
        errors=$((errors + 1))
    fi
    
    if [ $errors -gt 0 ]; then
        echo ""
        echo -e "${RED}Please fix $errors error(s) above and try again.${NC}"
        exit 1
    fi
    
    echo ""
}

# ============================================
# Setup Worker
# ============================================
setup_worker() {
    echo -e "${BLUE}=== Worker Setup ===${NC}"
    echo ""
    
    # Generate API key
    echo -e "${YELLOW}Generating API key...${NC}"
    API_KEY=$(openssl rand -hex 32)
    
    # Save key
    echo "$API_KEY" > "$HOME/.hermes/.worker_api_key"
    chmod 600 "$HOME/.hermes/.worker_api_key"
    echo -e "${GREEN}✓ API key generated${NC}"
    
    # Update .env
    echo -e "${YELLOW}Configuring environment...${NC}"
    ENV_FILE="$HOME/.hermes/.env"
    
    # Remove old config if exists
    if [ -f "$ENV_FILE" ]; then
        sed -i '/API_SERVER_ENABLED/d' "$ENV_FILE" 2>/dev/null || true
        sed -i '/API_SERVER_PORT/d' "$ENV_FILE" 2>/dev/null || true
        sed -i '/API_SERVER_HOST/d' "$ENV_FILE" 2>/dev/null || true
        sed -i '/API_SERVER_KEY/d' "$ENV_FILE" 2>/dev/null || true
    fi
    
    cat >> "$ENV_FILE" << EOF

# === Hermes VPS Cluster ===
API_SERVER_ENABLED=true
API_SERVER_PORT=8642
API_SERVER_HOST=0.0.0.0
API_SERVER_KEY=$API_KEY
EOF
    echo -e "${GREEN}✓ Environment configured${NC}"
    
    # Update config.yaml
    echo -e "${YELLOW}Updating Hermes config...${NC}"
    CONFIG_FILE="$HOME/.hermes/config.yaml"
    
    # Backup
    if [ -f "$CONFIG_FILE" ]; then
        cp "$CONFIG_FILE" "${CONFIG_FILE}.backup.$(date +%Y%m%d%H%M%S)"
    fi
    
    # Add api_server if not exists
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
        echo -e "${YELLOW}  API server config already exists${NC}"
    fi
    
    # Configure firewall
    echo -e "${YELLOW}Configuring firewall...${NC}"
    if command -v ufw &> /dev/null; then
        if ! sudo ufw status | grep -q "8642/tcp"; then
            sudo ufw allow 8642/tcp comment "Hermes VPS Cluster" 2>/dev/null || true
            echo -e "${GREEN}✓ Port 8642 opened${NC}"
        else
            echo -e "${YELLOW}  Port 8642 already allowed${NC}"
        fi
    else
        echo -e "${YELLOW}  UFW not found, ensure port 8642 is accessible${NC}"
    fi
    
    # Restart gateway
    echo -e "${YELLOW}Restarting Hermes gateway...${NC}"
    hermes gateway stop 2>/dev/null || true
    sleep 2
    hermes gateway install 2>/dev/null || true
    hermes gateway start
    echo -e "${GREEN}✓ Gateway restarted${NC}"
    
    # Get IP
    IP=$(hostname -I | awk '{print $1}')
    
    # Show result
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}Worker setup complete!${NC}"
    echo ""
    echo -e "  Send this to your ${CYAN}Master Bot${NC} admin:"
    echo ""
    echo -e "  ${YELLOW}┌─────────────────────────────────────────────┐${NC}"
    echo -e "  ${YELLOW}│${NC}  Hostname  : $(hostname)"
    echo -e "  ${YELLOW}│${NC}  IP Address: ${GREEN}$IP${NC}"
    echo -e "  ${YELLOW}│${NC}  Port      : 8642"
    echo -e "  ${YELLOW}│${NC}  API Key   : ${GREEN}$API_KEY${NC}"
    echo -e "  ${YELLOW}└─────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "  ${YELLOW}Verification:${NC}"
    echo "    curl -s http://localhost:8642/health"
    echo "    curl -s -H 'Authorization: Bearer $API_KEY' http://localhost:8642/v1/models"
    echo ""
}

# ============================================
# Setup Master
# ============================================
setup_master() {
    echo -e "${BLUE}=== Master Setup ===${NC}"
    echo ""
    
    # Check if workers.json already exists
    WORKERS_FILE="$HOME/.hermes/workers.json"
    if [ -f "$WORKERS_FILE" ]; then
        echo -e "${YELLOW}Existing workers.json found:${NC}"
        python3 -c "
import json
with open('$WORKERS_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    print(f\"  - {w['name']}: {w['ip']}\")
" 2>/dev/null
        echo ""
        read -p "Overwrite? (y/n): " OVERWRITE
        if [ "$OVERWRITE" != "y" ] && [ "$OVERWRITE" != "Y" ]; then
            echo "Keeping existing config."
            SKIP_WORKERS=true
        fi
    fi
    
    # Collect worker info
    if [ "$SKIP_WORKERS" != "true" ]; then
        echo -e "${YELLOW}Enter worker bot details:${NC}"
        echo -e "${CYAN}(Press Enter with empty IP to finish)${NC}"
        echo ""
        
        WORKERS_JSON='{"workers":['
        FIRST=true
        WORKER_COUNT=0
        
        for i in 2 3 4 5 6 7 8 9; do
            echo -e "${CYAN}Worker $i:${NC}"
            read -p "  IP (skip if done): " IP
            
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
            
            read -p "  Name [bot$i]: " NAME
            NAME=${NAME:-bot$i}
            
            if [ "$FIRST" = true ]; then
                FIRST=false
            else
                WORKERS_JSON+=","
            fi
            
            WORKERS_JSON+="{\"name\":\"$NAME\",\"ip\":\"$IP\",\"port\":8642,\"api_key\":\"$API_KEY\",\"enabled\":true}"
            WORKER_COUNT=$((WORKER_COUNT + 1))
            echo -e "${GREEN}  ✓ $NAME added${NC}"
            echo ""
        done
        
        WORKERS_JSON+=']}'
        
        if [ $WORKER_COUNT -eq 0 ]; then
            echo -e "${RED}ERROR: No workers configured${NC}"
            exit 1
        fi
        
        # Save workers.json
        echo "$WORKERS_JSON" > "$WORKERS_FILE"
        chmod 600 "$WORKERS_FILE"
        echo -e "${GREEN}✓ Workers config saved${NC}"
    fi
    
    # Install skill (no MCP config needed)
    echo ""
    echo -e "${YELLOW}Installing cluster skill...${NC}"
    SKILL_DIR="$HOME/.hermes/skills/hermes-vps-cluster"
    mkdir -p "$SKILL_DIR"
    
    # Get script directory
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    SKILL_SOURCE="$SCRIPT_DIR/../skills/hermes-vps-cluster"
    
    if [ -d "$SKILL_SOURCE" ]; then
        cp -r "$SKILL_SOURCE/"* "$SKILL_DIR/"
        chmod +x "$SKILL_DIR"/*.sh 2>/dev/null || true
        echo -e "${GREEN}✓ Skill installed${NC}"
    else
        echo -e "${YELLOW}  Skill files not found (install manually later)${NC}"
    fi
    
    # Test connections
    echo ""
    echo -e "${YELLOW}Testing worker connections...${NC}"
    
    python3 -c "
import json
with open('$WORKERS_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null | while IFS='|' read -r name ip port api_key; do
        echo -n "  $name ($ip)... "
        
        HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
            -H "Authorization: Bearer $api_key" \
            "http://$ip:$port/health" 2>/dev/null)
        
        if [ "$HTTP_CODE" = "200" ]; then
            echo -e "${GREEN}OK${NC}"
        else
            echo -e "${RED}FAILED ($HTTP_CODE)${NC}"
        fi
    done
    
    # Restart gateway
    echo ""
    echo -e "${YELLOW}Restarting Hermes gateway...${NC}"
    hermes gateway stop 2>/dev/null || true
    sleep 2
    hermes gateway install 2>/dev/null || true
    hermes gateway start
    echo -e "${GREEN}✓ Gateway restarted${NC}"
    
    # Count workers
    WORKER_COUNT=$(python3 -c "
import json
with open('$WORKERS_FILE') as f:
    data = json.load(f)
print(len([w for w in data['workers'] if w.get('enabled', True)]))
" 2>/dev/null)
    
    # Show result
    echo ""
    echo -e "${GREEN}══════════════════════════════════════════════════════${NC}"
    echo ""
    echo -e "  ${GREEN}Master setup complete!${NC}"
    echo ""
    echo -e "  Connected workers: ${CYAN}$WORKER_COUNT${NC}"
    echo ""
    
    python3 -c "
import json
with open('$WORKERS_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"  • {w['name']}: {w['ip']}\")
" 2>/dev/null
    
    echo ""
    echo -e "  ${YELLOW}Next steps:${NC}"
    echo "    1. Open Telegram → chat with Master bot"
    echo "    2. Send: /check_workers"
    echo ""
}

# ============================================
# Main
# ============================================
main() {
    show_banner
    
    # Parse arguments
    ROLE=""
    
    for arg in "$@"; do
        case $arg in
            --worker|-w)
                ROLE="worker"
                ;;
            --master|-m)
                ROLE="master"
                ;;
            --help|-h)
                echo "Usage:"
                echo "  ./quickstart.sh          # Interactive (asks for role)"
                echo "  ./quickstart.sh --worker # Setup as worker"
                echo "  ./quickstart.sh --master # Setup as master"
                echo ""
                exit 0
                ;;
        esac
    done
    
    # Check prerequisites
    check_prerequisites
    
    # If role not specified, ask
    if [ -z "$ROLE" ]; then
        echo "What role for this VPS?"
        echo ""
        echo "  1) Master  - Receives user messages, routes to workers"
        echo "  2) Worker  - Executes tasks, reports to master"
        echo ""
        read -p "Choice (1/2): " CHOICE
        
        case $CHOICE in
            1)
                ROLE="master"
                ;;
            2)
                ROLE="worker"
                ;;
            *)
                echo -e "${RED}Invalid choice${NC}"
                exit 1
                ;;
        esac
    fi
    
    echo ""
    
    # Run setup
    case $ROLE in
        worker)
            setup_worker
            ;;
        master)
            setup_master
            ;;
    esac
}

# Run main
main "$@"
