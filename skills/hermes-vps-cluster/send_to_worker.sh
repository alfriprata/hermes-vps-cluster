#!/bin/bash
# ============================================
# Send Task to Specific Worker
# Part of: Hermes VPS Cluster
# Usage: send_to_worker.sh <worker_name> "task description"
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"
WORKER_NAME="$1"
TASK="$2"

if [ -z "$WORKER_NAME" ] || [ -z "$TASK" ]; then
    echo "Usage: send_to_worker.sh <worker_name> 'task description'"
    echo ""
    echo "Available workers:"
    if [ -f "$CONFIG_FILE" ]; then
        python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    status = 'enabled' if w.get('enabled', True) else 'disabled'
    print(f\"  - {w['name']} ({status})\")
" 2>/dev/null
    fi
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: workers.json not found"
    exit 1
fi

# Find worker
WORKER_INFO=$(python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w['name'] == '$WORKER_NAME':
        if w.get('enabled', True):
            print(f\"{w['ip']}|{w['port']}|{w['api_key']}\")
        else:
            print('DISABLED')
        break
else:
    print('NOT_FOUND')
" 2>/dev/null)

if [ "$WORKER_INFO" = "NOT_FOUND" ]; then
    echo "ERROR: Worker '$WORKER_NAME' not found"
    exit 1
fi

if [ "$WORKER_INFO" = "DISABLED" ]; then
    echo "ERROR: Worker '$WORKER_NAME' is disabled"
    exit 1
fi

IFS='|' read -r ip port api_key <<< "$WORKER_INFO"

echo "=== Sending to $WORKER_NAME ==="
echo "Target: $ip:$port"
echo "Task: $TASK"
echo ""

# Send task
RESULT=$(curl -s -m 120 -H "Authorization: Bearer $api_key" \
    "http://$ip:$port/v1/chat/completions" \
    -H "Content-Type: application/json" \
    -d "{
        \"model\": \"hermes-agent\",
        \"messages\": [{\"role\": \"user\", \"content\": \"$TASK\"}],
        \"stream\": false
    }" 2>/dev/null)

echo "=== Result from $WORKER_NAME ==="
echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'Error: {e}')
"
