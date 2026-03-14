# Claude Sandbox Manager

## What This Is

A cross-platform CLI tool that lets anyone spin up and manage sandboxed Claude Code environments using Docker containers. Supports two container variants (minimal CLI and full GUI desktop with browser), automatic credential injection, MCP Toolkit integration, backup/restore, and an interactive settings menu — all without requiring Docker expertise.

## Core Value

Safe, hands-free Claude Code sandboxes that anyone can spin up without Docker expertise — maximizing AI coding productivity while maintaining isolation and low risk.

## Requirements

### Validated

- ✓ PLAT-01: Manager scripts run natively on Linux — v1.0
- ✓ PLAT-02: Manager scripts run natively on macOS — v1.0
- ✓ PLAT-03: Existing Windows support maintained — v1.0
- ✓ PLAT-04: Platform-specific differences detected automatically — v1.0
- ✓ CONT-01: Minimal CLI container build and run — v1.0
- ✓ CONT-02: GUI container with desktop environment and browser — v1.0
- ✓ CONT-03: Container type selection when creating instances — v1.0
- ✓ CONT-04: Xfce + noVNC for browser-based desktop access — v1.0
- ✓ CONT-05: GUI containers with adequate shared memory — v1.0
- ✓ INST-01: Claude Code via native installer (not NPM) — v1.0
- ✓ INST-02: Claude Code remote control optionally configured — v1.0
- ✓ CRED-01: ANTHROPIC_API_KEY automatically injected — v1.0
- ✓ CRED-02: GitHub CLI pre-installed in containers — v1.0
- ✓ CRED-03: GitHub CLI auto-authenticated with user token — v1.0
- ✓ CRED-04: Credentials never baked into Docker images — v1.0
- ✓ SETT-01: JSON config file stores user preferences — v1.0
- ✓ SETT-02: CLI menu for browsing/modifying settings — v1.0
- ✓ SETT-03: Settings include auto-backup, container type — v1.0
- ✓ SETT-04: Sensible defaults work out of the box — v1.0
- ✓ BACK-01: Manual backup via docker export — v1.0
- ✓ BACK-02: Optional auto-backup on startup — v1.0
- ✓ BACK-03: Backup captures container + workspace volume — v1.0
- ✓ BACK-04: Restore from backup — v1.0
- ✓ MCP-01: MCP Toolkit auto-connection on startup — v1.0
- ✓ MCP-02: README MCP setup instructions — v1.0
- ✓ MCP-03: MCP works without per-container config — v1.0
- ✓ QUAL-01: Clear separation of concerns — v1.0
- ✓ QUAL-02: Docker best practices — v1.0
- ✓ QUAL-03: Claude Code best practices — v1.0
- ✓ QUAL-04: Consistent coding style — v1.0
- ✓ SEC-01: No hardcoded passwords — v1.0
- ✓ SEC-02: SSH bound to localhost only — v1.0
- ✓ SEC-03: Docker capabilities dropped — v1.0
- ✓ SEC-04: Resource limits on containers — v1.0
- ✓ SEC-05: Security risk analysis documented — v1.0
- ✓ SEC-06: README disclaimers — v1.0
- ✓ DOC-01: README "Why I built this" — v1.0
- ✓ DOC-02: README "Who is this for" — v1.0
- ✓ DOC-03: README security disclaimers — v1.0
- ✓ BUG-01: No orphaned containers on rebuild — v1.0
- ✓ BUG-02: Orphaned instance detection — v1.0

### Active

(None yet — define for next milestone via `/gsd:new-milestone`)

### Out of Scope

- Windows 11 Docker containers/sandboxes — future milestone
- macOS Docker containers/sandboxes — future milestone
- Per-container MCP server setup — using Docker Desktop MCP Toolkit instead
- VS Code Dev Container integration — using Claude Code remote control instead
- Kubernetes/cluster orchestration — single-machine Docker tool
- Web-based IDE — CLI-first philosophy
- Automatic container scaling — personal use tool
- Selectable per-container packages — deferred to v2 (PKG-V2-01/02)

## Context

Shipped v1.0 with 1,933 lines Bash, 2,327 lines BATS tests, 209 lines Dockerfile/entrypoint.
Tech stack: Bash (lib/*.sh modules), BATS (testing), Docker (multi-stage Dockerfile), jq (JSON).
8 phases, 17 plans, 169 BATS tests passing, 140 git commits over 3 days.

Known tech debt: PS1 Windows manager frozen at pre-Phase-3 feature level (no backup/restore/preferences/MCP/security hardening). 17 human verification items requiring live Docker environment.

## Constraints

- **Platform**: Linux primary, macOS secondary, Windows legacy (PS1 scripts)
- **Container runtime**: Docker (Docker Desktop on macOS/Windows, Docker Engine on Linux)
- **Installation**: Claude Code via native installer, not NPM
- **Audience**: UX must be accessible to non-Docker-experts

## Key Decisions

| Decision | Rationale | Outcome |
|----------|-----------|---------|
| Linux support first | Claude can self-test in its Linux environment | ✓ Good — enabled rapid development and testing |
| Bash for scripting | Existing codebase is Bash/PowerShell; Bash is portable | ✓ Good — 1,933 LOC, ShellCheck clean, modular |
| Docker export for backups | Captures full container state, simplest approach | ✓ Good — docker commit + save + workspace tar works reliably |
| Config file + CLI menu for settings | Config file as source of truth, CLI for convenience | ✓ Good — atomic JSON writes, settings_get used everywhere |
| Docker Desktop MCP Toolkit | Shared MCP across all instances without per-container setup | ✓ Good — auto-probes gateway, graceful fallback |
| Native installer for Claude Code | More reliable than NPM installation | ✓ Good — curl pipe bash works in Dockerfile |
| Two container variants (CLI, GUI) | Covers headless coding and visual testing needs | ✓ Good — multi-stage Dockerfile, shared base |
| _docker_build_run_cmd shared helper | Single source of truth for docker run flags | ✓ Good — eliminated create/restore flag divergence |
| JSON null for unset container_type | Distinguishes "not chosen" from explicit selection | ✓ Good — first-time users get interactive prompt |
| BATS for testing | Shell-native testing framework, no dependencies | ✓ Good — 169 tests, comprehensive coverage |

---
*Last updated: 2026-03-14 after v1.0 milestone*
