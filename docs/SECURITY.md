# Security Best Practices

Security guidelines for Hermes VPS Cluster deployments.

---

## API Key Security

### Generation

Always generate strong API keys:

```bash
# Generate 32-byte hex key
openssl rand -hex 32

# Or 64-byte for extra security
openssl rand -hex 64
```

### Storage

- Store API keys in `~/.hermes/.worker_api_key` with `600` permissions
- Never commit keys to version control
- Use different keys for each worker

```bash
# Set proper permissions
chmod 600 ~/.hermes/.worker_api_key
chmod 600 ~/.hermes/workers.json
chmod 600 ~/.hermes/.env
```

### Rotation

Rotate API keys periodically:

1. Generate new key on worker
2. Update worker's `.env`
3. Update master's `workers.json`
4. Update master's `config.yaml`
5. Restart both gateways
6. Run `/reload-mcp` in Telegram

---

## Network Security

### Firewall Configuration

#### UFW (Ubuntu)

```bash
# Enable firewall
sudo ufw enable

# Allow SSH
sudo ufw allow 22/tcp

# Allow Hermes API (only from master IP)
sudo ufw allow from MASTER_IP to any port 8642 proto tcp

# Deny all other traffic by default
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Check status
sudo ufw status verbose
```

#### iptables

```bash
# Allow established connections
sudo iptables -A INPUT -m state --state ESTABLISHED,RELATED -j ACCEPT

# Allow SSH
sudo iptables -A INPUT -p tcp --dport 22 -j ACCEPT

# Allow Hermes API from master only
sudo iptables -A INPUT -p tcp -s MASTER_IP --dport 8642 -j ACCEPT

# Drop everything else
sudo iptables -A INPUT -j DROP

# Save rules
sudo iptables-save > /etc/iptables/rules.v4
```

### Cloud Provider Security Groups

#### AWS EC2

```json
{
  "IpPermissions": [
    {
      "IpProtocol": "tcp",
      "FromPort": 22,
      "ToPort": 22,
      "IpRanges": [{"CidrIp": "YOUR_IP/32"}]
    },
    {
      "IpProtocol": "tcp",
      "FromPort": 8642,
      "ToPort": 8642,
      "IpRanges": [{"CidrIp": "MASTER_IP/32"}]
    }
  ]
}
```

#### GCP

```bash
gcloud compute firewall-rules create hermes-ssh \
  --allow tcp:22 \
  --source-ranges=YOUR_IP/32 \
  --description="SSH access"

gcloud compute firewall-rules create hermes-api \
  --allow tcp:8642 \
  --source-ranges=MASTER_IP/32 \
  --description="Hermes API from master"
```

---

## HTTPS (Optional but Recommended)

For production deployments, use HTTPS with a reverse proxy.

### Nginx Reverse Proxy

```nginx
server {
    listen 443 ssl;
    server_name hermes-worker.example.com;

    ssl_certificate /etc/letsencrypt/live/hermes-worker.example.com/fullchain.pem;
    ssl_certificate_key /etc/letsencrypt/live/hermes-worker.example.com/privkey.pem;

    location / {
        proxy_pass http://127.0.0.1:8642;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

### Get SSL Certificate

```bash
# Install certbot
sudo apt install certbot python3-certbot-nginx

# Get certificate
sudo certbot --nginx -d hermes-worker.example.com

# Auto-renew
sudo certbot renew --dry-run
```

### Update Master Config

```yaml
mcp_servers:
  bot2:
    url: "https://hermes-worker.example.com/mcp"
    headers:
      Authorization: "Bearer API_KEY"
```

---

## Access Control

### Restrict API Server Binding

Bind to localhost only if using reverse proxy:

```bash
# In .env
API_SERVER_HOST=127.0.0.1
```

### IP Whitelisting

Only allow specific IPs to connect:

```bash
# UFW
sudo ufw allow from 192.168.1.100 to any port 8642

# iptables
sudo iptables -A INPUT -p tcp -s 192.168.1.100 --dport 8642 -j ACCEPT
sudo iptables -A INPUT -p tcp --dport 8642 -j DROP
```

---

## Monitoring

### Log Monitoring

```bash
# Watch for failed auth attempts
tail -f ~/.hermes/logs/gateway.log | grep "401\|403\|unauthorized"

# Monitor API access
tail -f ~/.hermes/logs/gateway.log | grep "api_server"
```

### Health Checks

Set up monitoring to alert if workers go offline:

```bash
#!/bin/bash
# health-monitor.sh

WORKERS=("worker1:8642" "worker2:8642" "worker3:8642")

for worker in "${WORKERS[@]}"; do
    IFS=':' read -r host port <<< "$worker"
    
    if ! curl -s -m 5 "http://$host:$port/health" > /dev/null; then
        echo "ALERT: $host is DOWN"
        # Send notification (email, Telegram, etc.)
    fi
done
```

---

## Incident Response

### Compromised API Key

1. Immediately rotate the key on the affected worker
2. Update master configuration
3. Check logs for unauthorized access
4. Review any changes made during compromise

### Unauthorized Access

1. Check gateway logs for suspicious activity
2. Verify all configurations haven't been tampered with
3. Consider rotating all API keys
4. Review firewall rules

---

## Security Checklist

- [ ] Unique API keys per worker
- [ ] API keys have 600 permissions
- [ ] Firewall configured (only allow master IP)
- [ ] SSH key-based authentication (disable password)
- [ ] Regular security updates (`sudo apt update && sudo apt upgrade`)
- [ ] Log monitoring in place
- [ ] Backup of configurations
- [ ] HTTPS enabled (production)
- [ ] IP whitelisting configured
- [ ] Regular key rotation schedule
