#!/bin/bash
# ============================================
# Route Task to Worker (Smart Routing)
# Part of: Hermes VPS Cluster
# Analyze task → Find matching specialization → Route
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"
TASK="$1"
FORCE_SPEC="$2"  # Optional: force specialization

if [ -z "$TASK" ]; then
    echo "Usage: route_task.sh 'task description' [specialization]"
    echo ""
    echo "Examples:"
    echo "  route_task.sh 'research BTC price'"
    echo "  route_task.sh 'deploy app' devops"
    echo "  route_task.sh 'write article' creative"
    exit 1
fi

if [ ! -f "$CONFIG_FILE" ]; then
    echo "ERROR: workers.json not found"
    exit 1
fi

echo "=== Routing Task ==="
echo "Task: $TASK"
echo ""

# Step 1: Determine specialization
if [ -n "$FORCE_SPEC" ]; then
    DETECTED_SPEC="$FORCE_SPEC"
    echo "Specialization: $DETECTED_SPEC (forced)"
else
    # Analyze task to determine specialization
    # This uses keyword matching - simple but effective
    DETECTED_SPEC=$(python3 -c "
import sys
task = sys.stdin.read().strip().lower()

# Define keyword → specialization mapping
keywords = {
    'research': ['research', 'find', 'search', 'look up', 'analyze', 'study', 'investigate', 'compare'],
    'code': ['code', 'program', 'debug', 'fix', 'develop', 'build', 'deploy', 'script', 'function', 'api'],
    'data': ['data', 'process', 'calculate', 'statistics', 'metrics', 'analytics', 'report', 'dashboard'],
    'creative': ['write', 'create', 'design', 'content', 'article', 'blog', 'copy', 'marketing'],
    'support': ['help', 'support', 'assist', 'question', 'answer', 'explain', 'tutorial'],
    'trading': ['trade', 'buy', 'sell', 'price', 'market', 'crypto', 'stock', 'forex', 'exchange'],
    'monitoring': ['monitor', 'check', 'status', 'health', 'uptime', 'alert', 'notification'],
    'devops': ['deploy', 'server', 'infrastructure', 'docker', 'kubernetes', 'ci/cd', 'pipeline'],
    'frontend': ['ui', 'ux', 'frontend', 'react', 'vue', 'angular', 'css', 'html', 'design'],
    'backend': ['backend', 'api', 'database', 'server', 'node', 'python', 'java', 'golang'],
}

# Find matching specialization
best_spec = 'general'
best_score = 0

for spec, words in keywords.items():
    score = sum(1 for word in words if word in task)
    if score > best_score:
        best_score = score
        best_spec = spec

print(best_spec)
" <<< "$TASK" 2>/dev/null)
    
    echo "Specialization: $DETECTED_SPEC (auto-detected)"
fi

echo ""

# Step 2: Find worker with matching specialization
echo "Looking for worker with specialization: $DETECTED_SPEC"
echo ""

SELECTED_WORKER=""

python3 -c "
import json, urllib.request

with open('$CONFIG_FILE') as f:
    data = json.load(f)

# Priority 1: Exact specialization match
matching = [w for w in data['workers'] 
            if w.get('enabled', True) 
            and w.get('specialization', 'general') == '$DETECTED_SPEC']

# Priority 2: General workers (if no exact match)
if not matching:
    matching = [w for w in data['workers'] 
                if w.get('enabled', True) 
                and w.get('specialization', 'general') == 'general']

# Priority 3: Any enabled worker (fallback)
if not matching:
    matching = [w for w in data['workers'] if w.get('enabled', True)]

# Return first available worker
for w in matching:
    try:
        req = urllib.request.Request(
            f\"http://{w['ip']}:{w['port']}/v1/models\",
            headers={'Authorization': f\"Bearer {w['api_key']}\"}
        )
        urllib.request.urlopen(req, timeout=5)
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}|{w.get('specialization', 'general')}\")
        break
    except:
        continue
else:
    print('NONE')
" 2>/dev/null | while IFS='|' read -r name ip port api_key spec; do
    if [ "$name" = "NONE" ]; then
        echo "ERROR: No workers available"
        exit 1
    fi
    
    echo "Selected: $name (specialization: $spec)"
    echo ""
    
    # Step 3: Send task
    echo "Executing task..."
    echo ""
    
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
done
