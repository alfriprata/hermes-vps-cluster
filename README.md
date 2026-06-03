# Hermes VPS Cluster

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Hermes Agent](https://img.shields.io/badge/Hermes-Agent-blue.svg)](https://github.com/NousResearch/hermes-agent)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-22.04+-orange.svg)](https://ubuntu.com/)
[![Shell Script](https://img.shields.io/badge/Shell-Bash-green.svg)](https://www.gnu.org/software/bash/)

**Distribute your Hermes Agent bots across multiple VPS with automatic load balancing based on storage availability.**

> Problem: You have multiple Hermes Agent bots on separate VPS, but storage fills up on individual servers.  
> Solution: This toolkit connects them into a cluster with a Master bot that routes tasks to the worker with the most available storage.

---

## Architecture

```
                         User (Telegram)
                               │
                               ▼
                    ┌─────────────────────┐
                    │     Master Bot      │
                    │   (VPS 1 - Bot 1)   │
                    │                     │
                    │  • Routes tasks     │
                    │  • Monitors health  │
                    │  • Load balancing   │
                    └──────────┬──────────┘
                               │
           ┌───────────────────┼───────────────────┐
           │                   │                   │
           ▼                   ▼                   ▼
    ┌─────────────┐     ┌─────────────┐     ┌─────────────┐
    │  Worker 1   │     │  Worker 2   │     │  Worker N   │
    │  (VPS 2)    │     │  (VPS 3)    │     │  (VPS N)    │
    │             │     │             │     │             │
    │  Storage:   │     │  Storage:   │     │  Storage:   │
    │  ████░░ 60% │     │  ██░░░░ 30% │     │  █████░ 80% │
    └─────────────┘     └─────────────┘     └─────────────┘
    
    Task → Routes to Worker 2 (lowest storage usage)
```

---

## Features

- **Automatic Storage-Based Routing** — Tasks are sent to the worker with the most available storage
- **Health Monitoring** — Check status of all workers with a single command
- **Simple Setup** — One script install, works with existing Hermes Agent installations
- **Scalable** — Add new workers anytime by running the setup script on a new VPS
- **Telegram Integration** — Manage everything from your Telegram bot
- **No External Dependencies** — Uses Hermes Agent's built-in API server

---

## Quick Start

### Prerequisites

- [Hermes Agent](https://github.com/NousResearch/hermes-agent) installed on all VPS
- Ubuntu 22.04+ on all servers
- Telegram bots already configured on each VPS

### One-Command Setup (Recommended)

**On Worker VPS (Bot 2, 3, 4, 5, ...):**

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/hermes-vps-cluster/main/quickstart.sh | bash -s -- --worker
```

**On Master VPS (Bot 1):**

```bash
curl -fsSL https://raw.githubusercontent.com/YOUR_USERNAME/hermes-vps-cluster/main/quickstart.sh | bash -s -- --master
```

Or download and run interactively:

```bash
git clone https://github.com/YOUR_USERNAME/hermes-vps-cluster.git
cd hermes-vps-cluster
chmod +x quickstart.sh
./quickstart.sh
```

### Manual Setup (Alternative)

<details>
<summary>Click to expand manual setup steps</summary>

#### Step 1: Clone this repository

```bash
git clone https://github.com/YOUR_USERNAME/hermes-vps-cluster.git
cd hermes-vps-cluster
```

#### Step 2: Setup Worker Bots (VPS 2, 3, 4, 5, ...)

Run on **each** worker VPS:

```bash
chmod +x scripts/setup-worker.sh
./scripts/setup-worker.sh
```

The script will:
1. Generate an API key
2. Enable the Hermes API server
3. Configure firewall rules
4. Display connection information

**Save the output** — you'll need the IP and API key for the Master setup.

#### Step 3: Setup Master Bot (VPS 1)

Run on the Master VPS:

```bash
chmod +x scripts/setup-master.sh
./scripts/setup-master.sh
```

When prompted, enter the IP and API key for each worker.

#### Step 4: Verify Setup

```bash
chmod +x scripts/test-cluster.sh
./scripts/test-cluster.sh
```

Or test from Telegram:

```
/check_workers
```

</details>

---

## Usage

### Telegram Commands

| Command | Description |
|---------|-------------|
| `/check_workers` | Show status and storage of all workers |
| `/route_task <task>` | Send task to worker with most available storage |
| `/send_to_worker <name> <task>` | Send task to a specific worker |

### Natural Language

You can also chat naturally with the Master bot:

```
You: "Check storage on all servers"
Master: [Runs /check_workers and returns results]

You: "Run a backup on bot3"
Master: [Sends backup task to bot3]

You: "Which server has the most space?"
Master: [Checks all workers and recommends one]
```

---

## How It Works

1. **Worker Setup** enables Hermes Agent's built-in API server on each worker VPS
2. **Master Setup** configures the Master bot to connect to all workers via MCP (Model Context Protocol)
3. When a task arrives, the Master:
   - Checks available storage on each worker
   - Selects the worker with the most free space
   - Sends the task via the worker's API
   - Returns the result to the user

---

## Project Structure

```
hermes-vps-cluster/
├── README.md                    # This file
├── LICENSE                      # MIT License
├── .gitignore                   # Git ignore rules
├── scripts/
│   ├── setup-worker.sh          # Worker VPS setup script
│   ├── setup-master.sh          # Master VPS setup script
│   └── test-cluster.sh          # Cluster verification script
├── config-templates/
│   ├── worker.env.example       # Worker environment template
│   └── master.config.yaml       # Master config template
├── skills/
│   └── hermes-vps-cluster/
│       ├── skill.yaml           # Skill definition
│       ├── check_workers.sh     # Health check command
│       ├── route_task.sh        # Auto-routing command
│       └── send_to_worker.sh    # Direct worker command
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
  worker1:
    url: "http://WORKER_IP:8642/mcp"
    headers:
      Authorization: "Bearer WORKER_API_KEY"
    timeout: 30
    enabled: true
```

---

## Adding a New Worker

To add a new VPS to the cluster:

1. Install Hermes Agent on the new VPS
2. Run `./scripts/setup-worker.sh`
3. On the Master, add the new worker to `~/.hermes/workers.json`
4. Add the MCP config to `~/.hermes/config.yaml`
5. Run `/reload-mcp` in Telegram

---

## Troubleshooting

See [docs/TROUBLESHOOTING.md](docs/TROUBLESHOOTING.md) for common issues.

Quick checks:

```bash
# Test worker connectivity
curl -s http://WORKER_IP:8642/health

# Test authentication
curl -s -H "Authorization: Bearer API_KEY" http://WORKER_IP:8642/v1/models

# Check firewall
sudo ufw status

# View logs
tail -f ~/.hermes/logs/gateway.log
```

---

## Security

See [docs/SECURITY.md](docs/SECURITY.md) for security best practices.

Key points:
- API keys are stored with `600` permissions
- Use unique API keys per worker
- Restrict firewall to Master IP only (optional)
- Consider HTTPS via reverse proxy for production

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

## Support

- Open an [issue](https://github.com/YOUR_USERNAME/hermes-vps-cluster/issues) for bugs
- Start a [discussion](https://github.com/YOUR_USERNAME/hermes-vps-cluster/discussions) for questions

---

**Made for the Hermes Agent community**
