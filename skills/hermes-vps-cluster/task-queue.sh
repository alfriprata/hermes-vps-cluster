#!/bin/bash
# ============================================
# Task Queue Script
# Part of: Hermes VPS Cluster
# Queue tasks when all workers are busy
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"
QUEUE_FILE="$HOME/.hermes/task-queue.json"
QUEUE_LOG="$HOME/.hermes/logs/task-queue.log"
MAX_RETRIES=3
RETRY_DELAY=30  # seconds

# Ensure directories exist
mkdir -p "$(dirname "$QUEUE_FILE")"
mkdir -p "$(dirname "$QUEUE_LOG")"

# Initialize queue if not exists
if [ ! -f "$QUEUE_FILE" ]; then
    echo '{"tasks":[],"completed":[],"failed":[]}' > "$QUEUE_FILE"
fi

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$QUEUE_LOG"
}

# Add task to queue
add_task() {
    local task="$1"
    local priority="${2:-normal}"  # low, normal, high
    local specialization="${3:-general}"
    
    TASK_ID="task_$(date +%s)_$RANDOM"
    
    python3 -c "
import json, sys
from datetime import datetime

task = sys.stdin.read().strip()

with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)

queue['tasks'].append({
    'id': '$TASK_ID',
    'task': task,
    'priority': '$priority',
    'specialization': '$specialization',
    'status': 'pending',
    'created': datetime.utcnow().isoformat() + 'Z',
    'retries': 0,
    'assigned_to': None
})

# Sort by priority (high > normal > low)
priority_order = {'high': 0, 'normal': 1, 'low': 2}
queue['tasks'].sort(key=lambda x: priority_order.get(x['priority'], 1))

with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
" <<< "$task"
    
    log "Task added: $TASK_ID (priority: $priority, specialization: $specialization)"
    echo "Task queued: $TASK_ID"
}

# Process queue
process_queue() {
    log "Processing queue..."
    
    # Get available worker
    AVAILABLE_WORKER=$(python3 -c "
import json, subprocess, sys

with open('$CONFIG_FILE') as f:
    config = json.load(f)

with open('$QUEUE_FILE') as f:
    queue = json.load(f)

if not queue['tasks']:
    print('EMPTY')
    sys.exit(0)

# Find first pending task
task = queue['tasks'][0]
specialization = task.get('specialization', 'general')

# Find available worker with matching specialization
for worker in config['workers']:
    if not worker.get('enabled', True):
        continue
    
    worker_spec = worker.get('specialization', 'general')
    
    # Check if worker matches specialization
    if specialization != 'general' and worker_spec != specialization:
        continue
    
    # Check if worker is alive
    try:
        import urllib.request
        req = urllib.request.Request(
            f\"http://{worker['ip']}:{worker['port']}/health\",
            headers={'Authorization': f\"Bearer {worker['api_key']}\"}
        )
        urllib.request.urlopen(req, timeout=5)
        print(f\"{worker['name']}|{worker['ip']}|{worker['port']}|{worker['api_key']}\")
        break
    except:
        continue
else:
    print('BUSY')
" 2>/dev/null)
    
    if [ "$AVAILABLE_WORKER" = "EMPTY" ]; then
        log "Queue is empty"
        echo "Queue is empty"
        return 0
    fi
    
    if [ "$AVAILABLE_WORKER" = "BUSY" ]; then
        log "All workers busy, tasks will retry later"
        echo "All workers busy"
        return 1
    fi
    
    # Get first pending task
    TASK_DATA=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    queue = json.load(f)
if queue['tasks']:
    task = queue['tasks'][0]
    print(f\"{task['id']}|{task['task']}|{task['retries']}\")
" 2>/dev/null)
    
    IFS='|' read -r task_id task retries <<< "$TASK_DATA"
    IFS='|' read -r worker_name worker_ip worker_port worker_key <<< "$AVAILABLE_WORKER"
    
    log "Processing $task_id on $worker_name..."
    
    # Execute task
    RESULT=$(curl -s -m 120 -H "Authorization: Bearer $worker_key" \
        "http://$worker_ip:$worker_port/v1/chat/completions" \
        -H "Content-Type: application/json" \
        -d "{
            \"model\": \"hermes-agent\",
            \"messages\": [{\"role\": \"user\", \"content\": $(echo "$task" | python3 -c 'import json,sys; print(json.dumps(sys.stdin.read().strip()))')}],
            \"stream\": false
        }" 2>/dev/null)
    
    if [ $? -eq 0 ] && echo "$RESULT" | grep -q "choices"; then
        # Success - move to completed
        python3 -c "
import json
from datetime import datetime

with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)

task = queue['tasks'].pop(0)
task['status'] = 'completed'
task['completed'] = datetime.utcnow().isoformat() + 'Z'
task['assigned_to'] = '$worker_name'
task['result'] = 'success'

queue['completed'].append(task)

with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"
        
        log "Task $task_id completed on $worker_name"
        
        # Return result
        echo "$RESULT" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data['choices'][0]['message']['content'])
except:
    print('Task completed but could not extract result')
"
        return 0
    else
        # Failed - increment retry count
        RETRIES=$((retries + 1))
        
        if [ "$RETRIES" -ge "$MAX_RETRIES" ]; then
            # Max retries reached - move to failed
            python3 -c "
import json
from datetime import datetime

with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)

task = queue['tasks'].pop(0)
task['status'] = 'failed'
task['failed'] = datetime.utcnow().isoformat() + 'Z'
task['retries'] = $RETRIES

queue['failed'].append(task)

with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"
            log "Task $task_id failed after $MAX_RETRIES retries"
        else
            # Update retry count
            python3 -c "
import json

with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)

queue['tasks'][0]['retries'] = $RETRIES

with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"
            log "Task $task_id failed, retry $RETRIES/$MAX_RETRIES"
        fi
        
        return 1
    fi
}

# Show queue status
show_status() {
    python3 -c "
import json

with open('$QUEUE_FILE') as f:
    queue = json.load(f)

print('=== Task Queue Status ===')
print()
print(f'Pending:   {len(queue[\"tasks\"])}')
print(f'Completed: {len(queue[\"completed\"])}')
print(f'Failed:    {len(queue[\"failed\"])}')
print()

if queue['tasks']:
    print('--- Pending Tasks ---')
    for i, task in enumerate(queue['tasks'][:10], 1):
        priority = task.get('priority', 'normal').upper()
        spec = task.get('specialization', 'general')
        print(f\"  {i}. [{priority}] {task['id']} ({spec})\")
    if len(queue['tasks']) > 10:
        print(f'  ... and {len(queue[\"tasks\"]) - 10} more')
    print()

if queue['failed']:
    print('--- Recent Failed ---')
    for task in queue['failed'][-5:]:
        print(f\"  - {task['id']}: {task.get('error', 'unknown')}\")
"
}

# Process all pending tasks
process_all() {
    log "Processing all pending tasks..."
    
    TOTAL=$(python3 -c "
import json
with open('$QUEUE_FILE') as f:
    queue = json.load(f)
print(len(queue['tasks']))
" 2>/dev/null)
    
    if [ "$TOTAL" -eq 0 ]; then
        echo "No pending tasks"
        return 0
    fi
    
    echo "Processing $TOTAL tasks..."
    
    PROCESSED=0
    FAILED=0
    
    for i in $(seq 1 "$TOTAL"); do
        if process_queue; then
            PROCESSED=$((PROCESSED + 1))
        else
            FAILED=$((FAILED + 1))
        fi
    done
    
    echo "Done: $PROCESSED completed, $FAILED failed"
}

# Clear completed/failed tasks
clear_history() {
    python3 -c "
import json

with open('$QUEUE_FILE', 'r') as f:
    queue = json.load(f)

queue['completed'] = []
queue['failed'] = []

with open('$QUEUE_FILE', 'w') as f:
    json.dump(queue, f, indent=2)
"
    echo "Queue history cleared"
}

# ============================================
# CLI Interface
# ============================================

case "${1:-}" in
    "add")
        # Add task: task-queue.sh add "task" [priority] [specialization]
        if [ -z "$2" ]; then
            echo "Usage: task-queue.sh add 'task' [priority] [specialization]"
            echo "  Priority: low, normal, high"
            echo "  Specialization: general, research, code, data"
            exit 1
        fi
        add_task "$2" "$3" "$4"
        ;;
    "process")
        # Process next task: task-queue.sh process
        process_queue
        ;;
    "process-all")
        # Process all tasks: task-queue.sh process-all
        process_all
        ;;
    "status")
        # Show status: task-queue.sh status
        show_status
        ;;
    "clear")
        # Clear history: task-queue.sh clear
        clear_history
        ;;
    "install")
        # Install as cron: task-queue.sh install [interval]
        INTERVAL=${2:-5}
        
        CRON_ENTRY="*/$INTERVAL * * * * $(readlink -f "$0") process-all >> $QUEUE_LOG 2>&1"
        
        if crontab -l 2>/dev/null | grep -q "task-queue.sh"; then
            echo "Cron job already exists. Updating..."
            crontab -l 2>/dev/null | grep -v "task-queue.sh" | crontab -
        fi
        
        (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
        
        echo "✓ Task queue processor installed"
        echo "  Interval: every $INTERVAL minutes"
        ;;
    "uninstall")
        crontab -l 2>/dev/null | grep -v "task-queue.sh" | crontab -
        echo "✓ Task queue cron removed"
        ;;
    *)
        echo "Usage:"
        echo "  task-queue.sh add 'task' [priority] [specialization]"
        echo "  task-queue.sh process              # Process next task"
        echo "  task-queue.sh process-all          # Process all pending"
        echo "  task-queue.sh status               # Show queue status"
        echo "  task-queue.sh clear                # Clear history"
        echo "  task-queue.sh install [interval]   # Install as cron"
        echo "  task-queue.sh uninstall            # Remove cron"
        exit 1
        ;;
esac
