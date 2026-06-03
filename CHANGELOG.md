# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [4.0.0] - 2026-06-03

### Added

- **Smart Specialization-Based Routing**
  - Manager analyzes tasks using keyword matching
  - Routes to Worker with matching specialization
  - Fallback to "general" Worker if no match
  - Fallback to any Worker if no "general" Worker

- **Worker Specialization Management**
  - Set specialization for each Worker: `worker-spec.sh set <name> <spec>`
  - Show all specializations: `worker-spec.sh show`
  - Find Worker by specialization: `worker-spec.sh find <spec>`
  - Custom specializations (not limited to predefined ones)

- **Auto-Detection Keywords**
  - research: research, find, search, analyze, study
  - code: code, program, debug, develop, build, deploy
  - data: data, process, calculate, statistics, analytics
  - creative: write, create, design, content, article
  - support: help, support, assist, question, answer
  - trading: trade, buy, sell, price, market, crypto
  - monitoring: monitor, check, status, health, uptime
  - devops: deploy, server, infrastructure, docker
  - frontend: ui, ux, frontend, react, vue, angular
  - backend: backend, api, database, server, node

### Changed

- `route_task.sh` now analyzes tasks and routes based on specialization
- `worker-spec.sh` now supports custom specializations
- `skill.yaml` updated to v4.0.0

### Why

Different VPS can be specialized for different tasks. Users define what each Worker is for, and the Manager intelligently routes tasks to the right Worker.

---

## [3.1.0] - 2026-06-03

### Changed

- **Simplified routing logic** - no more storage-based routing
  - `route_task.sh` now picks first available worker
  - `failover.sh` now picks first available worker
  - `worker-spec.sh` now picks first available worker
  - Storage info still shown in `check_workers.sh` for monitoring

### Removed

- Storage-based routing logic from all scripts
- "Storage-based routing" from README and documentation

### Why

User doesn't need storage-based routing. Simpler logic = fewer dependencies, faster execution, easier to understand.

---

## [3.0.1] - 2026-06-03

### Fixed

- Removed all MCP references from scripts
- Updated `quickstart.sh` to not add MCP config
- Updated `config-templates/master.config.yaml` to reference workers.json
- Updated `test-cluster.sh` to not check MCP config

---

## [3.0.0] - 2026-06-03

### Fixed

- **BREAKING:** Changed from MCP to API server mode
  - Workers now use API server (`/v1/chat/completions`) instead of MCP (`/mcp`)
  - No MCP configuration needed in `config.yaml`
  - Simpler setup, fewer moving parts

### Changed

- Skills (`check_workers.sh`, `route_task.sh`, `send_to_worker.sh`) now use API server directly
- Master setup no longer adds MCP config to `config.yaml`
- Worker connection test uses `/v1/models` endpoint instead of `/mcp`

### Why

The MCP endpoint requires separate configuration and setup. Using the API server directly is simpler and works out of the box with the standard Hermes Agent installation.

---

## [2.1.0] - 2026-06-03

### Added

- **Safe Mode** for setup scripts
  - Auto-backup before config changes
  - YAML validation before restart
  - Auto-rollback if gateway fails to start

---

## [2.0.0] - 2026-06-03

### Added

- **Auto-Failover** (`failover.sh`)
  - Automatically routes to backup worker if primary is down
  - Logs failover events for debugging
  - CLI: `failover.sh run 'task' [worker] [specialization]`

- **Health Monitor** (`health-monitor.sh`)
  - Periodic health checks for all workers
  - Telegram notifications when workers go down or storage is critical
  - Status tracking with JSON history
  - Cron job installation: `health-monitor.sh install [interval]`

- **Task Queue** (`task-queue.sh`)
  - Queue tasks when all workers are busy
  - Priority levels: low, normal, high
  - Automatic retry with configurable max retries
  - CLI: `task-queue.sh add 'task' [priority] [specialization]`

- **Worker Specialization** (`worker-spec.sh`)
  - Assign roles to workers: general, research, code, data, creative, support
  - Route tasks to specialized workers
  - CLI: `worker-spec.sh set <worker> <specialization>`

- **Quickstart Script** (`quickstart.sh`)
  - One-command setup for both master and worker
  - Flags: `--worker`, `--master`
  - Interactive mode when no flag provided

### Changed

- Updated skill definition to v2.0.0
- Enhanced README with advanced features documentation
- Updated project structure with new files

---

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

### [2.1.0] - Planned

- [ ] Auto-discovery of workers via DNS
- [ ] Health check dashboard (web UI)
- [ ] Load balancing algorithms (round-robin, CPU-based)
- [ ] Worker-to-worker communication

### [2.2.0] - Planned

- [ ] Shared memory/context across cluster
- [ ] Webhook notifications for failures
- [ ] Cost tracking per worker
- [ ] Parallel task execution

### [3.0.0] - Planned

- [ ] Docker support
- [ ] Kubernetes Helm chart
- [ ] Terraform modules for cloud deployment
- [ ] Multi-region support
