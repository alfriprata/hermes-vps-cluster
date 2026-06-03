#!/bin/bash
# ============================================
# Auto-Failover Script
# Part of: Hermes VPS Cluster
# Automatically routes to backup worker if primary is down
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"
FAILOVER_LOG="$HOME/.hermes/logs/failover.log"

# Ensure log directory exists
mkdir -p "$(dirname "$FAILOVER_LOG")"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$FAILOVER_LOG"
    echo "$1"
}

# Get available workers sorted by storage
get_available_workers() {
    python3 -c "
import json, sys
with open('$CONFIG_FILE') as f:
    data = json.load(f)
workers = []
for w in data['workers']:
    if w.get('enabled', True):
        workers.append(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}|{w.get('specialization', 'general')}\")
# Print all enabled workers
for w in workers:
    print(w)
" 2>/dev/null
}

# Check if worker is alive
check_worker() {
    local ip=$1
    local port=$2
    local api_key=$3
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/health" 2>/dev/null)
    
    [ "$HTTP_CODE" = "200" ]
}

# Get worker storage availability
get_storage() {
    local ip=$1
    local port=$2
    local api_key=$3
    
    curl -s -m 10 -H "Authorization: Bearer $api_key" \
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
" 2>/dev/null
}

# Main failover logic
execute_with_failover() {
    local task="$1"
    local preferred_worker="$2"  # Optional: preferred worker name
    local specialization="$3"    # Optional: required specialization
    
    log "Task received: ${task:0:50}..."
    
    # Get all available workers
    AVAILABLE_WORKERS=$(get_available_workers)
    
    if [ -z "$AVAILABLE_WORKERS" ]; then
        log "ERROR: No workers configured"
        echo "ERROR: No workers configured"
        return 1
    fi
    
    # Filter by specialization if specified
    if [ -n "$specialization" ]; then
        FILTERED=$(echo "$AVAILABLE_WORKERS" | grep "|$specialization$")
        if [ -n "$FILTERED" ]; then
            AVAILABLE_WORKERS="$FILTERED"
            log "Filtered by specialization: $specialization"
        else
            log "WARNING: No worker with specialization '$specialization', using general workers"
            AVAILABLE_WORKERS=$(echo "$AVAILABLE_WORKERS" | grep "|general$")
            if [ -z "$AVAILABLE_WORKERS" ]; then
                AVAILABLE_WORKERS=$(get_available_workers)
            fi
        fi
    fi
    
    # Try preferred worker first if specified
    if [ -n "$preferred_worker" ]; then
        PREFERRED_LINE=$(echo "$AVAILABLE_WORKERS" | grep "^$preferred_worker|")
        if [ -n "$PREFERRED_LINE" ]; then
            IFS='|' read -r name ip port api_key spec <<< "$PREFERRED_LINE"
            log "Trying preferred worker: $name"
            if check_worker "$ip" "$port" "$api_key"; then
                log "Preferred worker $name is available"
                execute_on_worker "$name" "$ip" "$port" "$api_key" "$task"
                return $?
            else
                log "Preferred worker $name is DOWN, trying failover..."
            fi
        fi
    fi
    
    # Find best available worker (most storage)
    BEST_WORKER=""
    BEST_AVAIL=0
    BEST_IP=""
    BEST_PORT=""
    BEST_KEY=""
    
    while IFS='|' read -r name ip port api_key spec; do
        if check_worker "$ip" "$port" "$api_key"; then
            AVAIL=$(get_storage "$ip" "$port" "$api_key")
            log "  $name: ${AVAIL}GB available (online)"
            
            if [ "$AVAIL" -gt "$BEST_AVAIL" ] 2>/dev/null; then
                BEST_WORKER=$name
                BEST_AVAIL=$AVAIL
                BEST_IP=$ip
                BEST_PORT=$port
                BEST_KEY=$api_key
            fi
        else
            log "  $name: OFFLINE"
        fi
    done <<< "$AVAILABLE_WORKERS"
    
    if [ -z "$BEST_WORKER" ]; then
        log "ERROR: All workers are DOWN"
        echo "ERROR: All workers are down. Please check your cluster."
        return 1
    fi
    
    log "Selected worker: $BEST_WORKER (${BEST_AVAIL}GB free)"
    execute_on_worker "$BEST_WORKER" "$BEST_IP" "$BEST_PORT" "$BEST_KEY" "$task"
}

# Execute task on specific worker
execute_on_worker() {
    local name=$1
    local ip=$2
    local port=$3
    local api_key=$4
    local task=$5
    
    log "Executing on $name..."
    
    RESULT=$(curl -s -m 120 -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"hermes-agent\",
            \"messages\": [{\"role\": \"user\", \"content\": $(echo "$task" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}],
            \"stream\": false
        }" 2>/dev/null)
    
    if [ $? -ne 0 ]; then
        log "ERROR: Failed to execute on $name"
        return 1
    fi
    
    # Extract and return result
    echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except Exception as e:
    print(f'Error: {e}')
"
    
    log "Task completed on $name"
    return 0
}

# ============================================
# CLI Interface
# ============================================

case "${1:-}" in
    "run")
        # Execute with failover: failover.sh run "task" [worker] [specialization]
        execute_with_failover "$2" "$3" "$4"
        ;;
    "check")
        # Check all workers: failover.sh check
        echo "=== Worker Health Status ==="
        echo ""
        while IFS='|' read -r name ip port api_key spec; do
            echo -n "$name ($ip:$port) [$spec]: "
            if check_worker "$ip" "$port" "$api_key"; then
                AVAIL=$(get_storage "$ip" "$port" "$api_key")
                echo "ONLINE (${AVAIL}GB free)"
            else
                echo "OFFLINE"
            fi
        done < <(get_available_workers)
        ;;
    "status")
        # Show failover log: failover.sh status
        echo "=== Recent Failover Events ==="
        tail -20 "$FAILOVER_LOG" 2>/dev/null || echo "No failover events yet"
        ;;
    *)
        echo "Usage:"
        echo "  failover.sh run 'task' [preferred_worker] [specialization]"
        echo "  failover.sh check"
        echo "  failover.sh status"
        exit 1
        ;;
esac
