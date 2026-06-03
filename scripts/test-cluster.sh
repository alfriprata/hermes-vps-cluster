#!/bin/bash
# ============================================
# Hermes VPS Cluster - Test Script
# Version: 1.0.0
# Description: Verify cluster setup
# ============================================

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PASS=0
FAIL=0
WARN=0

# Banner
echo -e "${BLUE}"
echo "╔══════════════════════════════════════════════════╗"
echo "║       Hermes VPS Cluster - Verification          ║"
echo "╚══════════════════════════════════════════════════╝"
echo -e "${NC}"

# Test function
pass() {
    echo -e "  ${GREEN}✓${NC} $1"
    PASS=$((PASS + 1))
}

fail() {
    echo -e "  ${RED}✗${NC} $1"
    FAIL=$((FAIL + 1))
}

warn() {
    echo -e "  ${YELLOW}⚠${NC} $1"
    WARN=$((WARN + 1))
}

# ============================================
# Section 1: Prerequisites
# ============================================
echo -e "${YELLOW}1. Checking Prerequisites${NC}"

if command -v hermes &> /dev/null; then
    pass "Hermes Agent installed"
else
    fail "Hermes Agent not found"
fi

if command -v python3 &> /dev/null; then
    pass "Python3 installed"
else
    fail "Python3 not found (required for JSON parsing)"
fi

if command -v curl &> /dev/null; then
    pass "curl installed"
else
    fail "curl not found"
fi

# ============================================
# Section 2: Master Configuration
# ============================================
echo ""
echo -e "${YELLOW}2. Checking Master Configuration${NC}"

WORKERS_FILE="$HOME/.hermes/workers.json"

if [ -f "$WORKERS_FILE" ]; then
    pass "workers.json exists"
    
    # Validate JSON
    if python3 -c "import json; json.load(open('$WORKERS_FILE'))" 2>/dev/null; then
        pass "workers.json is valid JSON"
        
        # Count workers
        WORKER_COUNT=$(python3 -c "
import json
with open('$WORKERS_FILE') as f:
    data = json.load(f)
print(len([w for w in data['workers'] if w.get('enabled', True)]))
" 2>/dev/null)
        
        if [ "$WORKER_COUNT" -gt 0 ]; then
            pass "$WORKER_COUNT worker(s) configured"
        else
            fail "No enabled workers found"
        fi
    else
        fail "workers.json is invalid JSON"
    fi
else
    fail "workers.json not found (run setup-master.sh first)"
fi

# Check API server config (no MCP needed)
CONFIG_FILE="$HOME/.hermes/config.yaml"
if [ -f "$CONFIG_FILE" ]; then
    pass "config.yaml exists"
else
    warn "config.yaml not found (may not be needed)"
fi

# ============================================
# Section 3: Worker Connections
# ============================================
echo ""
echo -e "${YELLOW}3. Testing Worker Connections${NC}"

if [ -f "$WORKERS_FILE" ] && python3 -c "import json; json.load(open('$WORKERS_FILE'))" 2>/dev/null; then
    python3 -c "
import json
with open('$WORKERS_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null | while IFS='|' read -r name ip port api_key; do
        echo -n "  $name ($ip:$port)... "
        
        # Health check
        HEALTH=$(curl -s -m 5 "http://$ip:$port/health" 2>/dev/null)
        if echo "$HEALTH" | grep -q '"ok"'; then
            echo -e "${GREEN}ONLINE${NC}"
            
            # Auth check
            AUTH=$(curl -s -m 5 -H "Authorization: Bearer $api_key" "http://$ip:$port/v1/models" 2>/dev/null)
            if echo "$AUTH" | grep -q '"data"'; then
                echo -e "       ${GREEN}✓ Auth working${NC}"
            else
                echo -e "       ${RED}✗ Auth failed${NC}"
            fi
        else
            echo -e "${RED}OFFLINE${NC}"
        fi
    done
else
    echo -e "  ${YELLOW}Skipped - no valid workers.json${NC}"
fi

# ============================================
# Section 4: Gateway Status
# ============================================
echo ""
echo -e "${YELLOW}4. Checking Gateway Status${NC}"

if hermes gateway status 2>/dev/null | grep -qi "running"; then
    pass "Gateway is running"
else
    warn "Gateway may not be running"
    echo "    Run: hermes gateway start"
fi

# ============================================
# Section 5: Skills
# ============================================
echo ""
echo -e "${YELLOW}5. Checking Skills${NC}"

SKILL_DIR="$HOME/.hermes/skills/hermes-vps-cluster"

if [ -d "$SKILL_DIR" ]; then
    pass "Skill directory exists"
    
    for file in skill.yaml check_workers.sh route_task.sh send_to_worker.sh; do
        if [ -f "$SKILL_DIR/$file" ]; then
            pass "$file present"
        else
            warn "$file missing"
        fi
    done
else
    warn "Skill not installed (optional)"
fi

# ============================================
# Summary
# ============================================
echo ""
echo -e "${BLUE}══════════════════════════════════════════════════${NC}"
echo ""
echo -e "  ${GREEN}Passed : $PASS${NC}"
echo -e "  ${RED}Failed : $FAIL${NC}"
echo -e "  ${YELLOW}Warning: $WARN${NC}"
echo ""

if [ $FAIL -eq 0 ]; then
    echo -e "  ${GREEN}All critical checks passed!${NC}"
    echo ""
    echo "  Next steps:"
    echo "    1. Chat with your Master bot on Telegram"
    echo "    2. Run: /reload-mcp"
    echo "    3. Run: /check_workers"
else
    echo -e "  ${RED}$FAIL check(s) failed. Please fix the issues above.${NC}"
fi

echo ""
