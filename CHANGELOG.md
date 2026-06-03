# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-06-03

### Added

- Initial release
- Worker setup script (`scripts/setup-worker.sh`)
- Master setup script (`scripts/setup-master.sh`)
- Cluster test script (`scripts/test-cluster.sh`)
- Skill for Telegram commands:
  - `/check_workers` - Health check all workers
  - `/route_task` - Auto-route to worker with most storage
  - `/send_to_worker` - Send task to specific worker
- Configuration templates
- Documentation:
  - Installation guide
  - Troubleshooting guide
  - Security best practices

### Features

- Automatic storage-based load balancing
- Health monitoring for all workers
- Simple setup with one-command scripts
- Scalable architecture (add workers anytime)
- Secure API key authentication

---

## Planned

### [1.1.0] - Planned

- [ ] Auto-discovery of workers via DNS
- [ ] Health check dashboard (web UI)
- [ ] Automatic failover
- [ ] Load balancing algorithms (round-robin, CPU-based)

### [1.2.0] - Planned

- [ ] Worker-to-worker communication
- [ ] Shared memory/context across cluster
- [ ] Task queue with retry logic
- [ ] Webhook notifications for failures

### [2.0.0] - Planned

- [ ] Docker support
- [ ] Kubernetes Helm chart
- [ ] Terraform modules for cloud deployment
- [ ] Multi-region support
