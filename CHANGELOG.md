# Changelog

All notable changes to Claude Sandbox Manager are documented in this file.

## [1.0.0] — 2025

### Added

- **Multi-instance management** — create, start, stop, and remove isolated Docker containers, each with its own SSH port, workspace, and keys
- **Per-instance SSH keys** — Ed25519 keypairs auto-generated per instance with localhost-only binding
- **Container variants** — CLI (minimal Ubuntu + Claude Code) and GUI (Xfce desktop + noVNC + Chromium)
- **Backup and restore** — export container state and workspace to `backups/{name}/`, restore on demand
- **Configurable preferences** — memory limit, CPU limit, default container type, MCP port, auto-backup on start
- **Docker MCP Toolkit integration** — containers auto-connect to the host's MCP Gateway on startup
- **Remote control support** — optionally launch `claude remote-control` inside the container for browser/mobile access
- **Security hardening** — dropped capabilities, `no-new-privileges`, resource limits, runtime-only credential injection
- **Cross-platform support** — Bash CLI for Linux/macOS, PowerShell + batch scripts for Windows
- **Interactive CLI menu** — guided interface for all operations, no Docker knowledge required
