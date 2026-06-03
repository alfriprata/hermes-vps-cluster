#!/bin/bash
# ============================================
# Route Task to Best Available Worker
# Part of: Hermes VPS Cluster
# Usage: route_task.sh "task description"
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

# Find best worker (most available storage)
BEST_WORKER=""
BEST_AVAIL=0
BEST_IP=""
BEST_PORT=""
BEST_KEY=""

python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null | while IFS='|' read -r name ip port api_key; do
    # Get available storage
    AVAIL=$(curl -s -m 10 -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d '{
            "model": "hermes-agent",
            "messages": [{"role": "user", "content": "Run: df -BG / | tail -1 | awk \"{print \\$4}\". Return ONLY the number."}],
            "stream": false
        }' 2>/dev/null | python3 -c "
import json, sys, re
try:
    data = json.load(sys.stdin)
    content = data['choices'][0]['message']['content']
    match = re.search(r'(\d+)', content)
    if match:
        print(int(match.group(1)))
    else:
        print(0)
except:
    print(0)
" 2>/dev/null)
    
    echo "  $name: ${AVAIL}GB available"
    
    # Track best worker
    if [ "$AVAIL" -gt "$BEST_AVAIL" ] 2>/dev/null; then
        BEST_WORKER=$name
        BEST_AVAIL=$AVAIL
        BEST_IP=$ip
        BEST_PORT=$port
        BEST_KEY=$api_key
    fi
done

# Send task to best worker
if [ -z "$BEST_WORKER" ]; then
    echo "ERROR: No workers available"
    exit 1
fi

echo ""
echo "=== Selected: $BEST_WORKER (${BEST_AVAIL}GB free) ==="
echo ""

# Execute task
RESULT=$(curl -s -m 120 -H "Authorization: Bearer $BEST_KEY" \
    "http://$BEST_IP:$BEST_PORT/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"hermes-agent\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$TASK\"}],
        \"stream\": false
    }" 2>/dev/null)

echo "=== Result from $BEST_WORKER ==="
echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'Error: {e}')
"
