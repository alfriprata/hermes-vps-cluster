#!/bin/bash
# ============================================
# Check Workers Status
# Part of: Hermes VPS Cluster
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
    
    # Health check
    HEALTH=$(curl -s -m 5 "http://$ip:$port/health" 2>/dev/null)
    
    if echo "$HEALTH" | grep -q '"ok"'; then
        ONLINE=$((ONLINE + 1))
        
        # Get storage info
        STORAGE=$(curl -s -m 10 -H "Authorization: Bearer $api_key" \
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
    # Parse df output
    parts = content.split()
    if len(parts) >= 5:
        total = parts[1]
        used = parts[2]
        avail = parts[3]
        pct = parts[4]
        print(f'Total: {total}, Used: {used}, Free: {avail} ({pct} used)')
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

echo "=== Summary ==="
echo "Run /check_workers in Telegram for real-time status"
