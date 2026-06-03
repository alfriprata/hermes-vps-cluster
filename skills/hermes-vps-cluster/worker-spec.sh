#!/bin/bash
# ============================================
# Worker Specialization Script
# Part of: Hermes VPS Cluster
# Manage worker roles and specializations
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"

# Show current specializations
show_specializations() {
    echo "=== Worker Specializations ==="
    echo ""
    
    python3 -c "
import json

with open('$CONFIG_FILE') as f:
    data = json.load(f)

# Group by specialization
specs = {}
for w in data['workers']:
    if not w.get('enabled', True):
        continue
    spec = w.get('specialization', 'general')
    if spec not in specs:
        specs[spec] = []
    specs[spec].append(w['name'])

# Display
for spec, workers in sorted(specs.items()):
    print(f'  {spec.upper()}:')
    for w in workers:
        print(f'    - {w}')
    print()

print('Available specializations:')
print('  general    - Can handle any task (default)')
print('  research   - Web research, data gathering')
print('  code       - Code generation, debugging')
print('  data       - Data processing, analysis')
print('  creative   - Writing, content creation')
print('  support    - Customer support, FAQ')
"
}

# Set worker specialization
set_specialization() {
    local worker_name="$1"
    local specialization="$2"
    
    if [ -z "$worker_name" ] || [ -z "$specialization" ]; then
        echo "Usage: worker-spec.sh set <worker_name> <specialization>"
        echo ""
        echo "Available specializations:"
        echo "  general, research, code, data, creative, support"
        exit 1
    fi
    
    python3 -c "
import json

with open('$CONFIG_FILE', 'r') as f:
    data = json.load(f)

found = False
for w in data['workers']:
    if w['name'] == '$worker_name':
        w['specialization'] = '$specialization'
        found = True
        break

if found:
    with open('$CONFIG_FILE', 'w') as f:
        json.dump(data, f, indent=2)
    print('✓ $worker_name specialization set to $specialization')
else:
    print('ERROR: Worker $worker_name not found')
"
}

# Add specialization to workers.json schema
add_specialization_field() {
    python3 -c "
import json

with open('$CONFIG_FILE', 'r') as f:
    data = json.load(f)

# Add specialization field if not exists
for w in data['workers']:
    if 'specialization' not in w:
        w['specialization'] = 'general'

with open('$CONFIG_FILE', 'w') as f:
    json.dump(data, f, indent=2)

print('✓ Specialization field added to all workers')
"
}

# Route task based on specialization
route_by_specialization() {
    local task="$1"
    local specialization="$2"
    
    if [ -z "$task" ]; then
        echo "Usage: worker-spec.sh route 'task' <specialization>"
        exit 1
    fi
    
    # Find worker with matching specialization
    WORKER=$(python3 -c "
import json, urllib.request

with open('$CONFIG_FILE') as f:
    data = json.load(f)

# Find workers with matching specialization
matching = []
for w in data['workers']:
    if not w.get('enabled', True):
        continue
    if w.get('specialization', 'general') == '${specialization:-general}' or '${specialization:-general}' == 'general':
        matching.append(w)

if not matching:
    # Fallback to any enabled worker
    matching = [w for w in data['workers'] if w.get('enabled', True)]

if not matching:
    print('NONE')
else:
    # Check which is alive and pick first available
    best = None
    
    for w in matching:
        try:
            req = urllib.request.Request(
                f\"http://{w['ip']}:{w['port']}/health\",
                headers={'Authorization': f\"Bearer {w['api_key']}\"}
            )
            urllib.request.urlopen(req, timeout=5)
            print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
            break
        except:
            continue
    else:
        print('ALL_DOWN')
" 2>/dev/null)
    
    if [ "$WORKER" = "NONE" ]; then
        echo "ERROR: No workers available"
        return 1
    fi
    
    if [ "$WORKER" = "ALL_DOWN" ]; then
        echo "ERROR: All workers are down"
        return 1
    fi
    
    IFS='|' read -r name ip port api_key <<< "$WORKER"
    
    echo "Routing to $name (specialization: ${specialization:-general})..."
    
    RESULT=$(curl -s -m 120 -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"hermes-agent\",
            \"messages\": [{\"role\": \"user\", \"content\": $(echo "$task" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}],
            \"stream\": false
        }" 2>/dev/null)
    
    echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'Error: {e}')
"
}

# Initialize specializations
init() {
    add_specialization_field
}

# ============================================
# CLI Interface
# ============================================

case "${1:-}" in
    "show"|"list")
        show_specializations
        ;;
    "set")
        set_specialization "$2" "$3"
        ;;
    "route")
        route_by_specialization "$2" "$3"
        ;;
    "init")
        init
        ;;
    *)
        echo "Usage:"
        echo "  worker-spec.sh show                          # Show current specializations"
        echo "  worker-spec.sh set <worker> <specialization>  # Set worker specialization"
        echo "  worker-spec.sh route 'task' <specialization>  # Route by specialization"
        echo "  worker-spec.sh init                           # Initialize specializations"
        echo ""
        echo "Available specializations:"
        echo "  general    - Can handle any task (default)"
        echo "  research   - Web research, data gathering"
        echo "  code       - Code generation, debugging"
        echo "  data       - Data processing, analysis"
        echo "  creative   - Writing, content creation"
        echo "  support    - Customer support, FAQ"
        exit 1
        ;;
esac
