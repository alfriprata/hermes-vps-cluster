#!/bin/bash
# ============================================
# Check Workers Status (API Mode)
# Part of: Hermes VPS Cluster
# Uses API server directly (no MCP needed)
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: workers.json not found"
    echo "Run: ./scripts/setup-master.sh"
    exit 1
fi

echo "=== Hermes VPS Cluster Status ==="
echo ""

TOTAL=0
ONLINE=0

python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null | while IFS='|' read -r name ip port api_key; do
    TOTAL=$((TOTAL + 1))
    
    # Health check via API server
    HEALTH=$(curl -s -m 5 -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/v1/models" 2>/dev/null)
    
    if echo "$HEALTH" | grep -q '"data"'; then
        ONLINE=$((ONLINE + 1))
        
        # Get storage info via API
        STORAGE=$(curl -s -m 15 -H "Authorization: Bearer $api_key" \
            "http://$ip:$port/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d '{
                "model": "hermes-agent",
                "messages": [{"role": "user", "content": "Run: df -h / | tail -1. Return ONLY the raw output."}],
                "stream": false
            }' 2>/dev/null | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    content = data['choices'][0]['message']['content']
    parts = content.split()
    if len(parts) >= 5:
        print(f'Total: {parts[1]}, Used: {parts[2]}, Free: {parts[3]} ({parts[4]} used)')
    else:
        print('N/A')
except:
    print('N/A')
" 2>/dev/null)
        
        echo "[$name] ONLINE"
        echo "  IP: $ip:$port"
        echo "  Storage: $STORAGE"
    else
        echo "[$name] OFFLINE"
        echo "  IP: $ip:$port"
    fi
    echo ""
done
