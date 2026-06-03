#!/bin/bash
# ============================================
# Health Monitor Script (Cron)
# Part of: Hermes VPS Cluster
# Run periodically to check worker health
# ============================================

CONFIG_FILE="$HOME/.hermes/workers.json"
HEALTH_LOG="$HOME/.hermes/logs/health-monitor.log"
STATUS_FILE="$HOME/.hermes/cluster-status.json"
TELEGRAM_NOTIFY="${TELEGRAM_NOTIFY:-false}"
TELEGRAM_BOT_TOKEN="${TELEGRAM_BOT_TOKEN:-}"
TELEGRAM_CHAT_ID="${TELEGRAM_CHAT_ID:-}"

# Ensure log directory exists
mkdir -p "$(dirname "$HEALTH_LOG")"
mkdir -p "$(dirname "$STATUS_FILE")"

# Log function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" >> "$HEALTH_LOG"
}

# Send Telegram notification
send_telegram() {
    local message="$1"
    
    if [ "$TELEGRAM_NOTIFY" = "true" ] && [ -n "$TELEGRAM_BOT_TOKEN" ] && [ -n "$TELEGRAM_CHAT_ID" ]; then
        curl -s -X POST "https://api.telegram.org/bot$TELEGRAM_BOT_TOKEN/sendMessage" \
            -d chat_id="$TELEGRAM_CHAT_ID" \
            -d text="$message" \
            -d parse_mode="Markdown" > /dev/null 2>&1
        log "Telegram notification sent"
    fi
}

# Check single worker
check_worker() {
    local name=$1
    local ip=$2
    local port=$3
    local api_key=$4
    
    # Health check
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" -m 5 \
        -H "Authorization: Bearer $api_key" \
        "http://$ip:$port/health" 2>/dev/null)
    
    if [ "$HTTP_CODE" = "200" ]; then
        # Get storage info
        STORAGE_INFO=$(curl -s -m 10 -H "Authorization: Bearer $api_key" \
            "http://$ip:$port/v1/chat/completions" \
            -H "Content-Type: application/json" \
            -d '{
                "model": "hermes-agent",
                "messages": [{"role": "user", "content": "Run: df -h / | tail -1. Return ONLY the raw df output."}],
                "stream": false
            }' 2>/dev/null)
        
        STORAGE=$(echo "$STORAGE_INFO" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    content = data['choices'][0]['message']['content']
    parts = content.split()
    if len(parts) >= 5:
        print(json.dumps({
            'total': parts[1],
            'used': parts[2],
            'available': parts[3],
            'percent': parts[4]
        }))
    else:
        print('{}')
except:
    print('{}')
" 2>/dev/null)
        
        echo "online|$STORAGE"
    else
        echo "offline|{}"
    fi
}

# Main monitoring function
run_health_check() {
    log "Starting health check..."
    
    # Previous status for comparison
    PREV_STATUS=""
    if [ -f "$STATUS_FILE" ]; then
        PREV_STATUS=$(cat "$STATUS_FILE")
    fi
    
    # Current status
    CURRENT_STATUS='{"timestamp":"'$(date -u +"%Y-%m-%dT%H:%M:%SZ")'","workers":{}}'
    ALERTS=""
    
    # Check each worker
    while IFS='|' read -r name ip port api_key; do
        RESULT=$(check_worker "$name" "$ip" "$port" "$api_key")
        IFS='|' read -r status storage <<< "$RESULT"
        
        # Update current status
        CURRENT_STATUS=$(echo "$CURRENT_STATUS" | python3 -c "
import json, sys
data = json.load(sys.stdin)
data['workers']['$name'] = {
    'ip': '$ip',
    'port': $port,
    'status': '$status',
    'storage': json.loads('$storage') if '$storage' != '{}' else None
}
json.dump(data, sys.stdout)
" 2>/dev/null)
        
        # Check for status change (was online, now offline)
        if [ "$status" = "offline" ]; then
            PREV_ONLINE=$(echo "$PREV_STATUS" | python3 -c "
import json, sys
try:
    data = json.load(sys.stdin)
    print(data.get('workers', {}).get('$name', {}).get('status', 'unknown'))
except:
    print('unknown')
" 2>/dev/null)
            
            if [ "$PREV_ONLINE" = "online" ]; then
                ALERTS="${ALERTS}🔴 *Worker $name is DOWN!*\nIP: $ip:$port\n\n"
                log "ALERT: $name is DOWN (was online)"
            fi
        fi
        
        # Check for storage warning (>90%)
        if [ "$status" = "online" ]; then
            USAGE=$(echo "$storage" | python3 -c "
import json, sys
try:
    data = json.loads(sys.stdin.read())
    percent = data.get('percent', '0%')
    print(int(percent.replace('%', '')))
except:
    print(0)
" 2>/dev/null)
            
            if [ "$USAGE" -gt 90 ]; then
                ALERTS="${ALERTS}⚠️ *Worker $name storage critical!*\nUsage: ${USAGE}%\n\n"
                log "WARNING: $name storage at ${USAGE}%"
            elif [ "$USAGE" -gt 80 ]; then
                ALERTS="${ALERTS}⚡ *Worker $name storage warning*\nUsage: ${USAGE}%\n\n"
                log "WARNING: $name storage at ${USAGE}%"
            fi
        fi
        
        log "  $name: $status"
    done < <(python3 -c "
import json
with open('$CONFIG_FILE') as f:
    data = json.load(f)
for w in data['workers']:
    if w.get('enabled', True):
        print(f\"{w['name']}|{w['ip']}|{w['port']}|{w['api_key']}\")
" 2>/dev/null)
    
    # Save current status
    echo "$CURRENT_STATUS" > "$STATUS_FILE"
    
    # Send alerts if any
    if [ -n "$ALERTS" ]; then
        ALERT_MSG="🚨 *Hermes VPS Cluster Alert*\n\n${ALERTS}Run \`/check_workers\` for details."
        send_telegram "$ALERT_MSG"
        log "Alerts sent"
    fi
    
    log "Health check complete"
}

# ============================================
# CLI Interface
# ============================================

case "${1:-}" in
    "run")
        # Run health check: health-monitor.sh run
        run_health_check
        ;;
    "status")
        # Show current status: health-monitor.sh status
        if [ -f "$STATUS_FILE" ]; then
            echo "=== Cluster Status ==="
            python3 -c "
import json
from datetime import datetime

with open('$STATUS_FILE') as f:
    data = json.load(f)

print(f\"Last check: {data['timestamp']}\")
print()

for name, info in data['workers'].items():
    status = info['status'].upper()
    storage = info.get('storage', {})
    
    if status == 'ONLINE':
        avail = storage.get('available', 'N/A')
        percent = storage.get('percent', 'N/A')
        print(f\"  ✓ {name}: ONLINE ({avail} free, {percent} used)\")
    else:
        print(f\"  ✗ {name}: OFFLINE\")
"
        else
            echo "No status data yet. Run: health-monitor.sh run"
        fi
        ;;
    "log")
        # Show log: health-monitor.sh log [lines]
        LINES=${2:-50}
        tail -$LINES "$HEALTH_LOG" 2>/dev/null || echo "No log data yet"
        ;;
    "install")
        # Install as cron job: health-monitor.sh install [interval_minutes]
        INTERVAL=${2:-60}
        
        # Create cron entry
        CRON_ENTRY="*/$INTERVAL * * * * $(readlink -f "$0") run >> $HEALTH_LOG 2>&1"
        
        # Check if already exists
        if crontab -l 2>/dev/null | grep -q "health-monitor.sh"; then
            echo "Cron job already exists. Removing old entry..."
            crontab -l 2>/dev/null | grep -v "health-monitor.sh" | crontab -
        fi
        
        # Add new entry
        (crontab -l 2>/dev/null; echo "$CRON_ENTRY") | crontab -
        
        echo "✓ Health monitor installed as cron job"
        echo "  Interval: every $INTERVAL minutes"
        echo "  Log: $HEALTH_LOG"
        echo ""
        echo "To configure Telegram notifications, add to ~/.hermes/.env:"
        echo "  TELEGRAM_NOTIFY=true"
        echo "  TELEGRAM_BOT_TOKEN=your-bot-token"
        echo "  TELEGRAM_CHAT_ID=your-chat-id"
        ;;
    "uninstall")
        # Remove cron job: health-monitor.sh uninstall
        crontab -l 2>/dev/null | grep -v "health-monitor.sh" | crontab -
        echo "✓ Health monitor cron job removed"
        ;;
    *)
        echo "Usage:"
        echo "  health-monitor.sh run                    # Run health check now"
        echo "  health-monitor.sh status                 # Show current status"
        echo "  health-monitor.sh log [lines]            # Show log"
        echo "  health-monitor.sh install [interval]     # Install as cron job"
        echo "  health-monitor.sh uninstall              # Remove cron job"
        exit 1
        ;;
esac
