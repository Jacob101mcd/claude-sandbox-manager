# Feature Landscape

**Domain:** Docker-based AI coding sandbox management
**Researched:** 2026-03-13
**Competitive context:** Docker Sandboxes (official), DevPod, GitHub Codespaces, Coder, Dev Containers spec

## Table Stakes

Features users expect from any Docker-based dev sandbox manager in 2026. Missing = product feels incomplete or amateurish.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Multi-instance management (create, start, stop, remove) | Every competitor has this. Already implemented. | Low | Already exists in current .bat scripts |
| Cross-platform CLI (Linux, macOS, Windows) | Docker Sandboxes, DevPod, Coder all work cross-platform. Windows-only is a dealbreaker for most users. | Med | PROJECT.md lists Linux-first as priority. Shell scripts (.sh) + PowerShell (.ps1) dual approach. |
| SSH access to containers | Standard access pattern for remote dev environments. Already implemented. | Low | Already exists |
| Workspace persistence across container restarts | Codespaces, DevPod, Coder all persist workspace data. Losing work on restart is unacceptable. | Low | Already exists via volume mounts to `workspaces/{name}/` |
| Container backup and restore | Docker Sandboxes lack this; it's a basic data safety expectation for any tool managing long-lived dev environments. | Med | Already exists via `docker export`. Consider also `docker commit` for faster snapshots. |
| Credential/API key injection | Docker Sandboxes auto-inject ANTHROPIC_API_KEY. DevPod forwards SSH agent. Users expect to not manually configure auth inside containers. | Med | GitHub token injection listed in PROJECT.md. Must also handle ANTHROPIC_API_KEY for Claude Code. |
| Pre-installed development toolchain | Docker Sandboxes ship Node.js, Python, Go, Git, gh CLI, ripgrep, jq. Users expect a ready-to-code environment. | Low | Current Dockerfile has Node.js + Claude Code + GSD. Needs expansion. |
| GitHub CLI pre-installed and authenticated | Codespaces has this natively. DevPod supports it. AI coding agents need git push/PR capabilities. | Low | Listed in PROJECT.md as active requirement |
| Interactive instance selector | When multiple instances exist, every action should offer selection. Users shouldn't need to remember instance names. | Low | Already exists in current manager |
| Sensible defaults with zero config | DevPod and Docker Sandboxes both emphasize "just works" out of the box. Target audience is non-Docker-experts. | Low | Critical for target audience per PROJECT.md |
| Container status visibility | Users need to see which instances are running, stopped, what ports they use. Every competitor shows this. | Low | Already exists in manager menu |

## Differentiators

Features that set this project apart from Docker Sandboxes (the primary competitor) and general-purpose tools like DevPod/Coder. Not expected, but create real value.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| Multiple container variants (Minimal CLI, GUI with desktop) | Docker Sandboxes offers one container type. Offering a lightweight headless variant AND a GUI variant with browser/desktop testing covers more use cases than any single competitor. | High | Listed in PROJECT.md. GUI variant needs X11/VNC/noVNC or similar. This is the biggest differentiator. |
| Docker Desktop MCP Toolkit integration | No other sandbox manager auto-shares host MCP servers with containers. This gives Claude Code inside containers access to 200+ MCP tools without per-container setup. | Med | Listed in PROJECT.md. Requires Docker Desktop 4.50+. Unique competitive advantage. |
| Settings manager with config file + CLI menu | Docker Sandboxes has no user-facing config UI. DevPod has a GUI app but it's heavy. A lightweight CLI settings menu is the sweet spot for power users who don't want to edit JSON. | Med | Listed in PROJECT.md. Config file as source of truth, CLI menu for convenience. |
| Selectable pre-installed packages/frameworks | No competitor lets you pick "I want Python + Rust + PostgreSQL client" at instance creation time. Docker Sandboxes uses a fixed template. | Med | Listed in PROJECT.md. Could use a curated list of "feature packs" inspired by Dev Container Features. |
| Auto-backup on startup | No competitor does automatic backup before starting work. Protects against container corruption or accidental destruction. | Low | Listed in PROJECT.md as optional/togglable. Simple `docker export` before start. |
| Claude Code remote control integration | Docker Sandboxes requires SSH or terminal. Auto-configuring remote control (code.claude.com) on startup means users can manage Claude from browser. | Med | Listed in PROJECT.md. Unique to Claude Code ecosystem. |
| Instance templates/profiles | Save a configuration (container type, packages, settings) as a named template. Create new instances from templates. No competitor in the "lightweight sandbox manager" space does this. | Med | Not in PROJECT.md but natural extension of settings + container variants. |
| Claude Code native installer (not NPM) | More reliable installation, auto-updates, better integration. Docker Sandboxes still uses the npm-based approach in some templates. | Low | Listed in PROJECT.md. Native installer is newer and preferred by Anthropic. |

## Anti-Features

Features to explicitly NOT build. These either duplicate existing tools, add unnecessary complexity, or conflict with the project's "accessible to non-Docker-experts" philosophy.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Kubernetes/cluster orchestration | Massively over-scoped. Coder does this. This tool targets single-machine Docker users. | Stay with `docker build`/`docker run`. Simple is the value prop. |
| VS Code Dev Container integration | PROJECT.md explicitly marks this out of scope. Claude Code remote control is the access method. | Support Claude Code remote control instead |
| Web-based IDE (like Codespaces/Gitpod) | Enormous scope, duplicates existing products, not aligned with CLI-first philosophy | Provide SSH access + Claude Code remote control |
| Per-container MCP server setup | PROJECT.md explicitly out of scope. Docker Desktop MCP Toolkit handles this at the host level. | Rely on Docker Desktop MCP Toolkit for shared MCP |
| Cloud provider integration | DevPod's strength, not this tool's. This tool is for local Docker environments. | Stay local-only. Cloud deployment is a different product. |
| devcontainer.json compatibility | Would require implementing the full Dev Container spec (features, lifecycle hooks, etc.). Massive scope for marginal benefit when the tool already has its own config. | Use own config format. Users wanting devcontainer.json should use DevPod or Codespaces. |
| Docker Compose orchestration | PROJECT.md already moved away from compose to build/run for instance isolation. Compose adds complexity without benefit for isolated instances. | Continue with `docker build`/`docker run` per instance |
| Windows 11 / macOS Docker containers | Marked out of scope in PROJECT.md. Linux containers on Docker Desktop cover the use case. | Linux containers only (Ubuntu 24.04 base) |
| Automatic container scaling/load balancing | Enterprise feature. Not needed for personal/small-team sandbox management. | One container = one instance. Simple. |
| Built-in code editor or terminal emulator | Duplicates system terminal, VS Code, etc. The manager manages containers, not editing. | Users bring their own terminal/editor. Provide SSH config for easy connection. |

## Feature Dependencies

```
Cross-platform CLI (Linux/macOS/Windows)
  --> All other features depend on this being solid

Container variants (Minimal CLI, GUI)
  --> Selectable packages (packages differ per variant)
  --> Instance templates (templates reference a variant)

Settings manager (config file + CLI menu)
  --> Auto-backup toggle (setting stored in config)
  --> Default container variant (setting stored in config)
  --> Default packages (setting stored in config)
  --> Claude Code remote control toggle (setting stored in config)

Credential injection (API keys, GitHub token)
  --> GitHub CLI authentication (needs token)
  --> Claude Code operational (needs ANTHROPIC_API_KEY)

Docker Desktop MCP Toolkit integration
  --> Requires Docker Desktop 4.50+ (must detect and warn)

Claude Code native installer
  --> Claude Code remote control (remote control may require native install)
```

## MVP Recommendation

Prioritize for first milestone:

1. **Cross-platform CLI** - Linux + macOS support (table stakes, current Windows-only is the biggest gap)
2. **Credential injection** - ANTHROPIC_API_KEY + GitHub token forwarding (table stakes for a Claude Code sandbox)
3. **Settings manager** - Config file + CLI menu (enables all other configurable features)
4. **Minimal CLI container variant** - Lightweight headless container (differentiator, lower complexity than GUI)
5. **Pre-installed toolchain expansion** - Python, Go, ripgrep, jq added to Dockerfile (table stakes, low effort)
6. **Claude Code native installer** - Switch from NPM to native (low effort, more reliable)

Defer:
- **GUI container variant**: High complexity (X11/VNC stack). Ship CLI variant first, validate demand.
- **Instance templates**: Natural follow-up after settings manager + container variants exist.
- **Docker Desktop MCP Toolkit integration**: Requires Docker Desktop 4.50+, may limit audience. Ship as opt-in later.
- **Claude Code remote control**: Depends on native installer, secondary access method to SSH.

## Competitive Positioning

This tool occupies a unique niche: **lightweight, local, Claude-Code-focused sandbox manager for non-Docker-experts**. The competitive landscape:

| Tool | Positioning | This Project's Advantage |
|------|-------------|-------------------------|
| Docker Sandboxes (official) | Integrated into Docker Desktop, microVM-based, multi-agent | Simpler setup, multiple container variants, backup/restore, configurable packages, works without Docker Desktop daemon features |
| DevPod | Open-source, multi-cloud, devcontainer.json standard | Simpler (no provider config), Claude-Code-specific optimizations, built-in backup, GUI container variant |
| GitHub Codespaces | Cloud-hosted, GitHub-integrated, paid | Free, local, no GitHub dependency, full container control, no usage limits |
| Coder | Enterprise, Terraform-based, team-focused | Individual/small-team focus, zero infrastructure, instant setup |

The key differentiator is **opinionated simplicity for Claude Code users** -- not trying to be a general-purpose CDE platform.

## Sources

- [Docker Sandboxes Documentation](https://docs.docker.com/ai/sandboxes/)
- [Claude Code Sandboxing Documentation](https://code.claude.com/docs/en/sandboxing)
- [Gitpod vs Codespaces vs Coder vs DevPod Comparison](https://www.vcluster.com/blog/comparing-coder-vs-codespaces-vs-gitpod-vs-devpod)
- [DevPod vs GitPod Comparison](https://www.vcluster.com/blog/devpod-vs-gitpod)
- [Dev Container Features Reference](https://containers.dev/implementors/features/)
- [Coder Workspace Management Docs](https://coder.com/docs/user-guides/workspace-management)
- [Docker Checkpoint/Restore Documentation](https://docs.docker.com/reference/cli/docker/checkpoint/)
- [GitHub Codespaces Alternatives](https://devcontainer.community/20250221-gh-codespace-alternatives-pt1/)
- [Docker + E2B AI Integration](https://www.docker.com/blog/docker-e2b-building-the-future-of-trusted-ai/)
- [Gitpod Alternatives for Cloud Development 2026](https://zencoder.ai/blog/gitpod-alternatives)
