# Hermes VPS Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-blue.svg)](https://github.com/NousResearch/hermes-agent)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange.svg)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**Connect multiple Hermes Agent VPS into a cluster. One Manager bot controls all Worker bots with smart specialization-based routing.**

> You have multiple Hermes Agent bots on separate VPS.  
> Instead of chatting to each bot one by one, you chat to ONE Manager bot.  
> The Manager routes your tasks to the Worker with matching specialization.

---

## How It Works

```
BEFORE (Manual):
┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐  ┌─────────┐
│  VPS 1  │  │  VPS 2  │  │  VPS 3  │  │  VPS 4  │  │  VPS 5  │
│  Bot 1  │  │  Bot 2  │  │  Bot 3  │  │  Bot 4  │  │  Bot 5  │
└────▲────┘  └────▲────┘  └────▲────┘  └────▲────┘  └────▲────┘
     │            │            │            │            │
     └────────────┴────────────┴────────────┴────────────┘
                        You chat 1 by 1

AFTER (With Manager + Specialization):
                         You
                          │
                          ▼
                    ┌──────────┐
                    │ Manager  │  ← You only chat here
                    │  (VPS 1) │
                    └────┬─────┘
                         │
         ┌───────────────┼───────────────┐
         │               │               │
         ▼               ▼               ▼
    ┌─────────┐    ┌─────────┐    ┌─────────┐
    │ Worker  │    │ Worker  │    │ Worker  │
    │ "research"│   │ "code"  │    │ "data"  │
    └─────────┘    └─────────┘    └─────────┘
```

---

## Features

| Feature | Description |
|---------|-------------|
| **1 Manager, N Workers** | Support any number of VPS |
| **Smart Routing** | Tasks sent to Worker with matching specialization |
| **Auto-Detection** | Manager analyzes task to find best Worker |
| **Auto-Failover** | If Worker is down, task goes to next available |
| **Health Monitoring** | Check all Workers with one command |
| **Custom Specializations** | Define your own specializations |

---

## Quick Start

### Prerequisites

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) installed on ALL VPS
- Ubuntu 22.04+ on all servers
- Telegram bots already configured on each VPS

### Step 1: Setup Workers (VPS 2, 3, 4, ...)

Run on **each** Worker VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/alfriprata/hermes-vps-cluster/main/scripts/setup-worker.sh | bash
```

**Save the output** (IP + API Key) for each worker.

### Step 2: Setup Manager (VPS 1)

Run on the Manager VPS:

```bash
curl -fsSL https://raw.githubusercontent.com/alfriprata/hermes-vps-cluster/main/scripts/setup-master.sh | bash
```

Enter the IP and API Key for each worker when prompted.

### Step 3: Set Worker Specializations

On the Manager VPS, set specializations for each worker:

```bash
# Set specialization for each worker
./worker-spec.sh set bot1 research
./worker-spec.sh set bot2 code
./worker-spec.sh set bot3 data
./worker-spec.sh set bot4 support
```

**You can use ANY specialization:**
- `research`, `code`, `data`, `creative`, `support`
- `trading`, `monitoring`, `frontend`, `backend`, `devops`
- Or any custom name you define

### Step 4: Verify

In Telegram, chat with your Manager bot:

```
/check_workers
/route_task "research BTC price"
```

---

## Example Setups

### Crypto Trader
```
VPS 1 = Manager
VPS 2 = Worker (trading)
VPS 3 = Worker (research)
VPS 4 = Worker (monitoring)
```

### Developer
```
VPS 1 = Manager
VPS 2 = Worker (frontend)
VPS 3 = Worker (backend)
VPS 4 = Worker (devops)
```

### Content Creator
```
VPS 1 = Manager
VPS 2 = Worker (writing)
VPS 3 = Worker (design)
VPS 4 = Worker (seo)
```

### General Use
```
VPS 1 = Manager
VPS 2 = Worker (general)
VPS 3 = Worker (general)
VPS 4 = Worker (general)
```

---

## How Smart Routing Works

When you send a task to the Manager:

1. **Manager analyzes the task** using keyword matching
2. **Manager finds Worker** with matching specialization
3. **Manager sends task** to that Worker
4. **Worker executes** the task
5. **Manager returns** the result to you

**Fallback logic:**
- If no Worker has matching specialization → Use "general" Worker
- If no "general" Worker → Use any available Worker

---

## Commands

| Command | Description |
|---------|-------------|
| `/check_workers` | Show status of all workers |
| `/route_task <task>` | Route task based on specialization |
| `/route_task <task> <spec>` | Force specific specialization |
| `/send_to_worker <name> <task>` | Send to specific worker |
| `/failover run <task>` | Execute with auto-failover |
| `/health_monitor run` | Check health now |

### Set Specializations

```bash
# Set specialization
./worker-spec.sh set <worker_name> <specialization>

# Show all specializations
./worker-spec.sh show

# Find worker by specialization
./worker-spec.sh find <specialization>
```

---

## Project Structure

```
hermes-vps-cluster/
├── README.md
├── LICENSE
├── CHANGELOG.md
├── .gitignore
├── scripts/
│   ├── setup-worker.sh      # Setup Worker VPS
│   ├── setup-master.sh      # Setup Manager VPS
│   └── test-cluster.sh      # Verify setup
├── skills/
│   └── hermes-vps-cluster/
│       ├── check_workers.sh
│       ├── route_task.sh    # Smart routing
│       ├── send_to_worker.sh
│       ├── failover.sh
│       ├── health-monitor.sh
│       ├── task-queue.sh
│       └── worker-spec.sh   # Specialization management
└── docs/
    ├── INSTALL.md
    ├── TROUBLESHOOTING.md
    └── SECURITY.md
```

---

## Use Cases

- **Any multi-VPS setup** where you want centralized control
- **Bots running tasks** across multiple VPS
- **Distributed workloads** with specialized workers
- **Teams** where different workers handle different tasks

---

## Contributing

1. Fork the repository
2. Create your feature branch
3. Commit your changes
4. Push to the branch
5. Open a Pull Request

---

## License

MIT License - see [LICENSE](LICENSE)

---

## Acknowledgments

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) by Nous Research
