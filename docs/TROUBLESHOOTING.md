# Troubleshooting Guide

Common issues and solutions for Hermes VPS Cluster.

---

## Worker Connection Issues

### Worker shows OFFLINE

**Symptoms:**
- `/check_workers` shows worker as OFFLINE
- Connection test fails

**Possible Causes:**

1. **API server not running**
   ```bash
   # Check on worker VPS
   hermes gateway status
   
   # If not running
   hermes gateway start
   ```

2. **Firewall blocking port 8642**
   ```bash
   # Check firewall status
   sudo ufw status
   
   # Allow port
   sudo ufw allow 8642/tcp
   
   # Restart firewall
   sudo ufw reload
   ```

3. **API server not enabled**
   ```bash
   # Check .env file
   cat ~/.hermes/.env | grep API_SERVER
   
   # Should show:
   # API_SERVER_ENABLED=true
   # API_SERVER_PORT=8642
   # API_SERVER_KEY=your-key
   ```

4. **Wrong IP address**
   ```bash
   # Get actual IP
   hostname -I | awk '{print $1}'
   
   # Test connectivity from master
   curl -s http://WORKER_IP:8642/health
   ```

5. **Cloud provider security group**
   - AWS: Check Security Group inbound rules
   - GCP: Check Firewall rules
   - Azure: Check Network Security Group

### Authentication Failed

**Symptoms:**
- Health check passes but auth fails
- HTTP 401 error

**Solution:**
```bash
# On worker, get the API key
cat ~/.hermes/.worker_api_key

# On master, verify it matches in workers.json
cat ~/.hermes/workers.json | python3 -m json.tool

# Test auth manually
curl -s -H "Authorization: Bearer YOUR_KEY" http://WORKER_IP:8642/v1/models
```

---

## MCP Connection Issues

### MCP tools not available

**Symptoms:**
- `/check_workers` command not found
- MCP tools not listed

**Solution:**
```bash
# Reload MCP in Telegram
/reload-mcp

# Check config
cat ~/.hermes/config.yaml | grep -A 5 "mcp_servers"

# Restart gateway
hermes gateway stop && hermes gateway start
```

### MCP connection timeout

**Symptoms:**
- Tools exist but calls timeout

**Solution:**
```yaml
# Increase timeout in config.yaml
mcp_servers:
  bot2:
    url: "http://IP:8642/mcp"
    timeout: 60  # Increase from 30
    connect_timeout: 10
```

---

## Storage Monitoring Issues

### Storage shows N/A

**Symptoms:**
- `/check_workers` shows N/A for storage

**Possible Causes:**

1. **Worker busy**
   - Wait and retry
   - Worker may be processing another task

2. **Timeout**
   ```bash
   # Test manually
   curl -s -m 30 -H "Authorization: Bearer KEY" \
     "http://IP:8642/v1/chat/completions" \
     -H "Content-Type: application/json" \
     -d '{"model":"hermes-agent","messages":[{"role":"user","content":"Run df -h /"}]}'
   ```

3. **Worker error**
   ```bash
   # Check worker logs
   tail -f ~/.hermes/logs/gateway.log
   ```

---

## Gateway Issues

### Gateway won't start

**Symptoms:**
- `hermes gateway start` fails

**Solution:**
```bash
# Check for errors
hermes gateway start 2>&1

# Check logs
tail -50 ~/.hermes/logs/gateway.log

# Check port conflict
sudo lsof -i :8642

# Reset gateway
hermes gateway stop
hermes gateway install
hermes gateway start
```

### Gateway crashes after config change

**Symptoms:**
- Gateway stops after editing config.yaml

**Solution:**
```bash
# Restore backup
cp ~/.hermes/config.yaml.backup ~/.hermes/config.yaml

# Or fix the config
nano ~/.hermes/config.yaml

# Check YAML syntax
python3 -c "import yaml; yaml.safe_load(open('$HOME/.hermes/config.yaml'))"
```

---

## Skill Issues

### Skill not found

**Symptoms:**
- `/check_workers` not available as command

**Solution:**
```bash
# Check skill directory
ls ~/.hermes/skills/hermes-vps-cluster/

# Should contain:
# skill.yaml
# check_workers.sh
# route_task.sh
# send_to_worker.sh

# If missing, reinstall
cp -r skills/hermes-vps-cluster ~/.hermes/skills/

# Restart gateway
hermes gateway stop && hermes gateway start
```

### Skill script permission denied

**Solution:**
```bash
chmod +x ~/.hermes/skills/hermes-vps-cluster/*.sh
```

---

## Network Issues

### Can't reach worker from master

**Diagnostic steps:**
```bash
# From master, test basic connectivity
ping WORKER_IP

# Test port
nc -zv WORKER_IP 8642

# Test HTTP
curl -v http://WORKER_IP:8642/health
```

**Common fixes:**

1. **AWS EC2:**
   - Add inbound rule for TCP 8642 from Master IP

2. **GCP:**
   ```bash
   gcloud compute firewall-rules create hermes-cluster \
     --allow tcp:8642 \
     --source-ranges=MASTER_IP/32 \
     --description="Hermes VPS Cluster"
   ```

3. **Azure:**
   - Add inbound security rule in Network Security Group

---

## Performance Issues

### Slow task routing

**Symptoms:**
- `/route_task` takes long time

**Possible Causes:**

1. **Storage check timeout**
   - Increase timeout in skill script
   - Check worker responsiveness

2. **Network latency**
   ```bash
   # Test latency
   ping -c 5 WORKER_IP
   ```

3. **Worker overloaded**
   - Check worker CPU/memory usage
   - Consider adding more workers

---

## Getting Help

If your issue isn't covered here:

1. Check [GitHub Issues](https://github.com/YOUR_USERNAME/hermes-vps-cluster/issues)
2. Search [Hermes Agent Docs](https://hermes-agent.nousresearch.com/docs/)
3. Join [Hermes Discord](https://discord.gg/NousResearch)
4. Open a new issue with:
   - Error message
   - Steps to reproduce
   - Output of `./scripts/test-cluster.sh`
   - Relevant logs
