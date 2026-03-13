# Claude Sandbox Manager

## What This Is

A tool that lets anyone cleanly spin up and manage sandboxed Claude Code environments using Docker containers. It provides safe, hands-free AI coding productivity with a low risk profile — supporting multiple container types (minimal CLI and full GUI with browser), cross-platform operation, and accessible UX for users who may not have deep Docker knowledge.

## Core Value

Safe, hands-free Claude Code sandboxes that anyone can spin up without Docker expertise — maximizing AI coding productivity while maintaining isolation and low risk.

## Requirements

### Validated

(None yet — ship to validate)

### Active

- [ ] Cross-platform support (Linux first, then macOS — currently Windows-only .bat scripts)
- [ ] Container manager upgrade (replace rebuild-claude.bat with full container manager supporting multiple container types)
- [ ] Minimal CLI container variant (lightweight, headless coding tasks)
- [ ] GUI container variant (lightweight desktop + browser for web and desktop app testing)
- [ ] Claude Code installed via native installer instead of NPM on container creation
- [ ] Instance manager supports choosing different container types when starting new instances
- [ ] Claude Code remote control integration on container startup (optional)
- [ ] Auto-backup of instance upon startup via docker export (optional, togglable)
- [ ] GitHub CLI pre-installed and auto-authenticated with user-provided token on container build
- [ ] Selectable pre-installed packages/frameworks per container with popular defaults
- [ ] Docker Desktop MCP Toolkit integration — all sandbox instances share host MCP server automatically
- [ ] Settings manager: config file in root + CLI menu to modify it (controls backups, packages, defaults)
- [ ] Full code cleanup and restructuring for readability and best practices (coding, Docker, Claude Code)
- [ ] Security audit with risk analysis, mitigation plan, implementation, and README disclaimers
- [ ] README additions: "Why I built this" and "Who is this for" sections
- [ ] Bug fix: container instances pile up in Docker on rebuild, not detected by manager

### Out of Scope

- Windows 11 Docker containers/sandboxes — future milestone
- macOS Docker containers/sandboxes — future milestone
- Per-container MCP server setup — using Docker Desktop MCP Toolkit instead
- VS Code Dev Container integration — using Claude Code remote control instead

## Context

- Project currently uses .bat scripts (Windows-only) with Docker for container management
- Uses `docker build`/`docker run` (not docker compose) for instance isolation
- SSH keys are copied to a space-free path to work with Windows OpenSSH
- Current architecture: one Dockerfile rebuilt each time, instances managed via SSH
- Target audience is "anyone curious" — UX must be accessible, not just for Docker power users
- Claude Code has a remote control feature (code.claude.com/docs/en/remote-control) for remote access
- Docker Desktop MCP Toolkit is a new feature that provides shared MCP server access to all containers
- Backups should use `docker export` for full container state snapshots to local directory

## Constraints

- **Platform**: Must work on Linux first (enables Claude to self-test in current environment), then macOS, existing Windows support maintained
- **Container runtime**: Docker (Docker Desktop on macOS/Windows, Docker Engine on Linux)
- **Installation**: Claude Code via native installer, not NPM
- **Audience**: UX must be accessible to non-Docker-experts — clear prompts, sensible defaults, good error messages

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Linux support first | Claude can self-test in its Linux environment | — Pending |
| Docker export for backups | Captures full container state, simplest approach | — Pending |
| Config file + CLI menu for settings | Config file as source of truth, CLI for convenience | — Pending |
| Docker Desktop MCP Toolkit | Shared MCP across all instances without per-container setup | — Pending |
| Native installer for Claude Code | More reliable than NPM installation | — Pending |
| Two container variants (Minimal CLI, GUI) | Covers headless coding and visual testing needs | — Pending |

---
*Last updated: 2026-03-13 after initialization*
