# Hermes VPS Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-blue.svg)](https://github.com/NousResearch/hermes-agent)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange.svg)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**Centralize control of your Hermes Agent bots across multiple VPS with automatic storage-based routing.**

> Problem: You have multiple Hermes Agent bots on separate VPS. You have to chat to each one manually, and storage fills up on individual servers.  
> Solution: This toolkit adds a **Master Bot** that routes your tasks to the worker with the most available storage — you chat to one bot, it picks the best worker.

---

## What This Does

**Before:**
```
You → Chat VPS 1 (busy, storage full)
You → Chat VPS 2 (ok, but you don't know)
You → Chat VPS 3 (ok, but you don't know)
You → Chat VPS 4 (busy)
You → Chat VPS 5 (ok)
```

**After:**
```
You → Chat Master Bot
Master → Checks all workers
Master → Picks worker with most free storage
Master → Routes task to that worker
Master → Returns result to you
```

---

## Architecture

```
                    You (Telegram)
                         │
                         ▼
              ┌─────────────────────┐
              │     Master Bot      │
              │   (VPS 1 - Bot 1)   │
              │                     │
              │  • Routes tasks     │  ← You only chat here
              │  • Monitors health  │
              │  • Auto-failover    │
              └──────────┬──────────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
  ┌─────────────┐ ┌─────────────┐ ┌─────────────┐
  │  Worker 1   │ │  Worker 2   │ │  Worker N   │
  │  (VPS 2)    │ │  (VPS 3)    │ │  (VPS N)    │
  │             │ │             │ │             │
  │  Storage:   │ │  Storage:   │ │  Storage:   │
  │  ████░░ 60% │ │  ██░░░░ 30% │ │  █████░ 80% │
  └─────────────┘ └─────────────┘ └─────────────┘
  
  Task → Routes to Worker 2 (most free storage)
```

---

## Features

### Core Features

| Feature | Description |
|---------|-------------|
| **Storage-Based Routing** | Tasks sent to worker with most free storage |
| **Auto-Failover** | If worker is down, task goes to next available worker |
| **Health Monitoring** | Check all workers with one command |
| **Task Queue** | If all workers busy, task waits in queue |
| **Worker Specialization** | Assign roles: research, code, data, etc. |
| **Telegram Integration** | Manage everything from Telegram |
| **Safe Setup** | Auto-backup, validation, rollback on failure |

### Telegram Commands

| Command | Description |
|---------|-------------|
| `/check_workers` | Show status and storage of all workers |
| `/route_task <task>` | Send task to worker with most free storage |
| `/send_to_worker <name> <task>` | Send task to a specific worker |
| `/failover run <task>` | Execute with auto-failover |
| `/health_monitor run` | Run health check now |
| `/task_queue add <task>` | Add task to queue |

---

## Quick Start

### Prerequisites

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) installed on all VPS
- Ubuntu 22.04+ on all servers
- Telegram bots already configured on each VPS

### Step 1: Setup Worker Bots (VPS 2, 3, 4, 5, ...)

Run on **each** worker VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/alfriprata/hermes-vps-cluster/main/scripts/setup-worker.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/alfriprata/hermes-vps-cluster.git
cd hermes-vps-cluster
chmod +x scripts/setup-worker.sh
./scripts/setup-worker.sh
```

**Save the output** — you'll need the IP and API key for the Master setup.

### Step 2: Setup Master Bot (VPS 1)

Run on the Master VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/alfriprata/hermes-vps-cluster/main/scripts/setup-master.sh | bash
```

Or clone and run:

```bash
git clone https://github.com/alfriprata/hermes-vps-cluster.git
cd hermes-vps-cluster
chmod +x scripts/setup-master.sh
./scripts/setup-master.sh
```

When prompted, enter the IP and API key for each worker.

### Step 3: Verify

In Telegram, chat with your Master bot:

```
/reload-mcp
/check_workers
```

---

## How It Works

1. **Worker Setup** enables Hermes Agent's built-in API server on each worker VPS
2. **Master Setup** saves worker connection details (IP + API key)
3. When you send a task to Master:
   - Master checks available storage on each worker via API (`/v1/models`)
   - Master selects the worker with the most free space
   - Master sends the task via worker's API (`/v1/chat/completions`)
   - Master returns the result to you

**Note:** This uses Hermes Agent's built-in API server (OpenAI-compatible), NOT MCP. No MCP configuration needed.

---

## Use Cases

This is designed for scenarios where:
- You have **multiple identical Hermes Agent bots** on separate VPS
- Each VPS has **limited storage** that fills up over time
- You want to **chat to one bot** instead of managing multiple bots
- You want **automatic failover** if a worker goes down

**Examples:**
- Crypto agents monitoring different exchanges
- Bots running tasks that accumulate logs/data
- Any setup where you need distributed storage

---

## Project Structure

```
hermes-vps-cluster/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── CHANGELOG.md                 # Version history
├── .gitignore                   # Git ignore rules
├── scripts/
│   ├── setup-worker.sh          # Worker VPS setup (safe mode)
│   ├── setup-master.sh          # Master VPS setup (safe mode)
│   └── test-cluster.sh          # Cluster verification
├── config-templates/
│   ├── worker.env.example       # Worker environment template
│   └── master.config.yaml       # Master config template
├── skills/
│   └── hermes-vps-cluster/
│       ├── skill.yaml           # Skill definition
│       ├── check_workers.sh     # Health check command
│       ├── route_task.sh        # Storage-based routing
│       ├── send_to_worker.sh    # Direct worker command
│       ├── failover.sh          # Auto-failover logic
│       ├── health-monitor.sh    # Health monitoring (cron)
│       ├── task-queue.sh        # Task queue management
│       └── worker-spec.sh       # Worker specialization
└── docs/
    ├── INSTALL.md               # Detailed installation guide
    ├── TROUBLESHOOTING.md       # Common issues and fixes
    └── SECURITY.md              # Security best practices
```

---

## Configuration

### Worker Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `API_SERVER_ENABLED` | `false` | Enable the API server |
| `API_SERVER_PORT` | `8642` | API server port |
| `API_SERVER_HOST` | `0.0.0.0` | Bind address |
| `API_SERVER_KEY` | *(required)* | Bearer token for authentication |

### Master Config

The Master's `~/.hermes/config.yaml` will be updated with MCP server entries for each worker:

```yaml
mcp_servers:
  bot2:
    url: "http://WORKER_IP:8642/mcp"
    headers:
      Authorization: "Bearer WORKER_API_KEY"
    timeout: 30
    enabled: true
```

---

## Safety Features

### Auto-Backup
Before making any changes, the script creates backups:
```
~/.hermes/backups/20260603_123456/
├── .env.backup
├── config.yaml.backup
└── workers.json.backup
```

### Config Validation
The script validates YAML syntax before restarting the gateway.

### Auto-Rollback
If the gateway fails to start after changes, the script automatically restores the backup.

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

Quick checks:

```bash
# Test worker connectivity
curl -s http://WORKER_IP:8642/health

# Check gateway status
hermes gateway status

# View logs
tail -f ~/.hermes/logs/gateway.log

# Restore backup
cp ~/.hermes/backups/YYYYMMDD_HHMMSS/.env.backup ~/.hermes/.env
cp ~/.hermes/backups/YYYYMMDD_HHMMSS/config.yaml.backup ~/.hermes/config.yaml
hermes gateway stop && hermes gateway start
```

---

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for security best practices.

Key points:
- API keys are stored with `600` permissions
- Use unique API keys per worker
- Restrict firewall to Master IP only (optional)

---

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---

## Acknowledgments

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research
- [MCP (Model Context Protocol)](https://modelcontextprotocol.io/)

---

**Made for the Hermes Agent community**
