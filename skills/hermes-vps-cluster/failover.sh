#!/bin/bash
# ============================================
# Auto-Failover Script (Simple Mode)
# Part of: Hermes VPS Cluster
# Pick first available worker, no storage check
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

# Get enabled workers
get_workers() {
    python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null
}

# Check if worker is alive
check_worker() {
    local ip=$1
    local port=$2
    local api_key=$3
    
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/v1/models" 2>/dev/null)
    
    [ "$HTTP_CODE" = "200" ]
}

# Main failover logic - pick first available worker
execute_with_failover() {
    local task="$1"
    local preferred_worker="$2"
    
    log "Task received: ${task:0:50}..."
    
    # Get all workers
    WORKERS=$(get_workers)
    
    if [ -z "$WORKERS" ]; then
        log "ERROR: No workers configured"
        echo "ERROR: No workers configured"
        return 1
    fi
    
    # Try preferred worker first if specified
    if [ -n "$preferred_worker" ]; then
        PREFERRED_LINE=$(echo "$WORKERS" | grep "^$preferred_worker|")
        if [ -n "$PREFERRED_LINE" ]; then
            IFS='|' read -r name ip port api_key <<< "$PREFERRED_LINE"
            log "Trying preferred worker: $name"
            if check_worker "$ip" "$port" "$api_key"; then
                log "Preferred worker $name is available"
                execute_on_worker "$name" "$ip" "$port" "$api_key" "$task"
                return $?
            else
                log "Preferred worker $name is DOWN, trying next..."
            fi
        fi
    fi
    
    # Find first available worker
    while IFS='|' read -r name ip port api_key; do
        if check_worker "$ip" "$port" "$api_key"; then
            log "Selected worker: $name"
            execute_on_worker "$name" "$ip" "$port" "$api_key" "$task"
            return $?
        else
            log "  $name: OFFLINE"
        fi
    done <<< "$WORKERS"
    
    log "ERROR: All workers are DOWN"
    echo "ERROR: All workers are down. Please check your cluster."
    return 1
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
        # Execute with failover: failover.sh run "task" [worker]
        execute_with_failover "$2" "$3"
        ;;
    "check")
        # Check all workers: failover.sh check
        echo "=== Worker Health Status ==="
        echo ""
        while IFS='|' read -r name ip port api_key; do
            echo -n "$name ($ip:$port): "
            if check_worker "$ip" "$port" "$api_key"; then
                echo "ONLINE"
            else
                echo "OFFLINE"
            fi
        done < <(get_workers)
        ;;
    "status")
        # Show failover log: failover.sh status
        echo "=== Recent Failover Events ==="
        tail -20 "$FAILOVER_LOG" 2>/dev/null || echo "No failover events yet"
        ;;
    *)
        echo "Usage:"
        echo "  failover.sh run 'task' [preferred_worker]"
        echo "  failover.sh check"
        echo "  failover.sh status"
        exit 1
        ;;
esac
