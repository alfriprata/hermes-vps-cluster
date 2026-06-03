# Installation Guide

Detailed step-by-step installation guide for Hermes VPS Cluster.

## Prerequisites

### On All VPS

1. **Ubuntu 22.04+** (other Linux distros should work but are untested)
2. **Hermes Agent** installed and configured
3. **Telegram bot** connected to each Hermes instance
4. **Python 3.8+** (usually pre-installed on Ubuntu)
5. **curl** (usually pre-installed)

### Verify Prerequisites

```bash
# Check Ubuntu version
lsb_release -a

# Check Hermes installation
hermes --version

# Check Python
python3 --version

# Check curl
curl --version
```

### Network Requirements

- Each VPS must be reachable from the Master VPS on port 8642
- Ensure no firewall blocks inter-VPS communication
- If using cloud VPS (AWS, GCP, Azure), check security groups

---

## Installation Steps

### Step 1: Clone Repository

On all VPS:

```bash
git clone https://github.com/YOUR_USERNAME/hermes-vps-cluster.git
cd hermes-vps-cluster
```

### Step 2: Setup Worker Bots (VPS 2, 3, 4, 5, ...)

On each worker VPS:

```bash
chmod +x scripts/setup-worker.sh
./scripts/setup-worker.sh
```

The script will:
1. Generate a secure API key
2. Enable the Hermes API server
3. Configure firewall rules
4. Restart the Hermes gateway

**Save the output** - you need the IP and API key for the Master setup.

Example output:
```
┌─────────────────────────────────────────┐
│  Worker Name : vps2
│  IP Address  : 203.0.113.10
│  Port        : 8642
│  API Key     : a1b2c3d4e5f6...
└─────────────────────────────────────────┘
```

### Step 3: Setup Master Bot (VPS 1)

On the Master VPS:

```bash
chmod +x scripts/setup-master.sh
./scripts/setup-master.sh
```

When prompted, enter:
- Worker IP addresses
- Worker API keys

The script will:
1. Save worker configuration
2. Update Hermes MCP config
3. Install the cluster skill
4. Test connections
5. Restart the gateway

### Step 4: Verify Installation

```bash
chmod +x scripts/test-cluster.sh
./scripts/test-cluster.sh
```

Or test from Telegram:

```
/reload-mcp
/check_workers
```

---

## Manual Installation

If you prefer to install manually:

### Worker Setup (Manual)

1. Generate API key:
```bash
API_KEY=$(openssl rand -hex 32)
echo "$API_KEY" > ~/.hermes/.worker_api_key
chmod 600 ~/.hermes/.worker_api_key
```

2. Add to `~/.hermes/.env`:
```bash
cat >> ~/.hermes/.env << EOF
API_SERVER_ENABLED=true
API_SERVER_PORT=8642
API_SERVER_HOST=0.0.0.0
API_SERVER_KEY=$API_KEY
EOF
```

3. Add to `~/.hermes/config.yaml`:
```yaml
api_server:
  enabled: true
  port: 8642
  host: "0.0.0.0"
```

4. Open firewall:
```bash
sudo ufw allow 8642/tcp
```

5. Restart gateway:
```bash
hermes gateway stop && hermes gateway start
```

### Master Setup (Manual)

1. Create `~/.hermes/workers.json`:
```json
{
  "workers": [
    {
      "name": "bot2",
      "ip": "WORKER_IP",
      "port": 8642,
      "api_key": "WORKER_API_KEY",
      "enabled": true
    }
  ]
}
```

2. Add to `~/.hermes/config.yaml`:
```yaml
mcp_servers:
  bot2:
    url: "http://WORKER_IP:8642/mcp"
    headers:
      Authorization: "Bearer WORKER_API_KEY"
    timeout: 30
    enabled: true
```

3. Install skill:
```bash
cp -r skills/hermes-vps-cluster ~/.hermes/skills/
```

4. Restart gateway:
```bash
hermes gateway stop && hermes gateway start
```

5. In Telegram:
```
/reload-mcp
/check_workers
```

---

## Adding a New Worker

To add a new VPS to an existing cluster:

1. Run `setup-worker.sh` on the new VPS
2. On the Master, update `~/.hermes/workers.json`
3. Add MCP config to `~/.hermes/config.yaml`
4. Run `/reload-mcp` in Telegram

---

## Uninstallation

### Remove from Worker

```bash
# Remove API server config from .env
sed -i '/API_SERVER_ENABLED/d' ~/.hermes/.env
sed -i '/API_SERVER_PORT/d' ~/.hermes/.env
sed -i '/API_SERVER_HOST/d' ~/.hermes/.env
sed -i '/API_SERVER_KEY/d' ~/.hermes/.env

# Remove from config.yaml
# (manually remove the api_server section)

# Restart gateway
hermes gateway stop && hermes gateway start
```

### Remove from Master

```bash
# Remove workers config
rm ~/.hermes/workers.json

# Remove MCP config from config.yaml
# (manually remove the mcp_servers entries)

# Remove skill
rm -rf ~/.hermes/skills/hermes-vps-cluster

# Restart gateway
hermes gateway stop && hermes gateway start
```
