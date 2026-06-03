#!/bin/bash
# ============================================
# Route Task to Available Worker (Simple Mode)
# Part of: Hermes VPS Cluster
# Just pick any online worker, no storage check
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"
TASK="$1"

if [ -z "$TASK" ]; then
    echo "Usage: route_task.sh 'task description'"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: workers.json not found"
    exit 1
fi

echo "=== Routing Task ==="
echo "Task: $TASK"
echo ""

# Find first available worker
SELECTED_WORKER=""

while IFS='|' read -r name ip port api_key; do
    echo -n "  Checking $name... "
    
    # Simple health check
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/v1/models" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        echo -e "ONLINE"
        SELECTED_WORKER="$name|$ip|$port|$api_key"
        break  # Pick first available worker
    else
        echo -e "OFFLINE"
    fi
done < <(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null)

if [ -z "$SELECTED_WORKER" ]; then
    echo ""
    echo "ERROR: No workers available"
    exit 1
fi

IFS='|' read -r name ip port api_key <<< "$SELECTED_WORKER"

echo ""
echo "=== Selected: $name ==="
echo ""

# Send task
RESULT=$(curl -s -m 120 -H "Authorization: Bearer $api_key" \
    "http://$ip:$port/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"hermes-agent\",
        \"messages\": [{\"role\": \"user\", \"content\": $(echo "$TASK" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}],
        \"stream\": false
    }" 2>/dev/null)

echo "=== Result from $name ==="
echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'Error: {e}')
"
