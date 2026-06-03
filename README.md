# Hermes VPS Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-blue.svg)](https://github.com/NousResearch/hermes-agent)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange.svg)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**Connect multiple Hermes Agent VPS into a cluster. One Manager bot controls all Worker bots.**

> You have multiple Hermes Agent bots on separate VPS.  
> Instead of chatting to each bot one by one, you chat to ONE Manager bot.  
> The Manager routes your tasks to an available Worker.

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
| **Auto-Routing** | Tasks sent to first available Worker |
| **Auto-Failover** | If Worker is down, task goes to next available |
| **Health Monitoring** | Check all Workers with one command |
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
VPS 2  = Worker
VPS 3  = Worker
VPS 4  = Worker
VPS 5  = Worker
VPS 6  = Worker
VPS 7  = Worker
VPS 8  = Worker
VPS 9  = Worker
VPS 10 = Worker
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
| `/route_task <task>` | Send task to available worker |
| `/send_to_worker <name> <task>` | Send to specific worker |
| `/failover run <task>` | Execute with auto-failover |
| `/health_monitor run` | Check health now |

---

## How Routing Works

When you send a task to the Manager:

1. Manager checks which Workers are online
2. Manager picks the first available Worker
3. Manager sends the task to that Worker
4. Worker executes the task
5. Manager returns the result to you

If a Worker is down → Manager automatically tries the next Worker.

---

## Use Cases

- **Crypto agents** monitoring different exchanges
- **Bots running tasks** across multiple VPS
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
