# Hermes VPS Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-blue.svg)](https://github.com/NousResearch/hermes-agent)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange.svg)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**Connect multiple Hermes Agent VPS into a cluster. One Manager bot controls all Worker bots.**

> You have multiple Hermes Agent bots on separate VPS.  
> Instead of chatting to each bot one by one, you chat to ONE Manager bot.  
> The Manager routes your tasks to the best available Worker.

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

AFTER (With Manager):
                         You
                          │
                          ▼
                    ┌──────────┐
                    │ Manager  │  ← You only chat here
                    │  (VPS 1) │
                    └────┬─────┘
           ┌─────────────┼─────────────┐
           │             │             │
           ▼             ▼             ▼
      ┌─────────┐  ┌─────────┐  ┌─────────┐
      │ Worker  │  │ Worker  │  │ Worker  │  ... (unlimited)
      │ (VPS 2) │  │ (VPS 3) │  │ (VPS 4) │
      └─────────┘  └─────────┘  └─────────┘
```

---

## Features

| Feature | Description |
|---------|-------------|
| **1 Manager, N Workers** | Support any number of VPS (3, 5, 10, 20, etc.) |
| **Storage-Based Routing** | Tasks sent to worker with most free storage |
| **Auto-Failover** | If worker is down, task goes to next available |
| **Health Monitoring** | Check all workers with one command |
| **Task Queue** | If all workers busy, task waits in queue |
| **Safe Setup** | Auto-backup, validation, rollback on failure |

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

### Step 3: Verify

In Telegram, chat with your Manager bot:

```
/check_workers
```

---

## Example: 10 VPS Setup

```
VPS 1  = Manager (you chat here)
VPS 2  = Worker (research)
VPS 3  = Worker (code)
VPS 4  = Worker (data)
VPS 5  = Worker (general)
VPS 6  = Worker (general)
VPS 7  = Worker (general)
VPS 8  = Worker (general)
VPS 9  = Worker (general)
VPS 10 = Worker (general)
```

Setup:
1. Run `setup-worker.sh` on VPS 2-10
2. Run `setup-master.sh` on VPS 1
3. Enter all 9 workers' IP + API Key
4. Done!

---

## Commands

| Command | Description |
|---------|-------------|
| `/check_workers` | Show status of all workers |
| `/route_task <task>` | Send task to best available worker |
| `/send_to_worker <name> <task>` | Send to specific worker |
| `/failover run <task>` | Execute with auto-failover |
| `/health_monitor run` | Check health now |
| `/task_queue add <task>` | Add task to queue |

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
│       ├── route_task.sh
│       ├── send_to_worker.sh
│       ├── failover.sh
│       ├── health-monitor.sh
│       ├── task-queue.sh
│       └── worker-spec.sh
└── docs/
    ├── INSTALL.md
    ├── TROUBLESHOOTING.md
    └── SECURITY.md
```

---

## How Routing Works

When you send a task to the Manager:

1. Manager checks which Workers are online
2. Manager checks storage on each online Worker
3. Manager picks the Worker with the most free storage
4. Manager sends the task to that Worker
5. Worker executes the task
6. Manager returns the result to you

If a Worker is down → Manager automatically tries the next Worker.

---

## Use Cases

- **Crypto agents** monitoring different exchanges
- **Bots accumulating data** that fills storage
- **Any multi-VPS setup** where you want centralized control

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
