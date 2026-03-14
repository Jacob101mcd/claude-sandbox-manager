# Milestones

## v1.0 MVP (Shipped: 2026-03-14)

**Phases completed:** 8 phases, 17 plans, 0 tasks

**Stats:** 140 commits, 117 files changed, ~19.9K insertions, 3 days (Mar 12-14, 2026)
**Code:** 1,933 lines Bash, 2,327 lines BATS tests, 209 lines Dockerfile/entrypoint

**Key accomplishments:**
1. Cross-platform CLI manager (`bin/csm`) with modular architecture — 7 library modules, all ShellCheck clean
2. Full container lifecycle (create/start/stop/SSH/remove) with runtime credential injection (API key + GitHub CLI)
3. GUI desktop container variant via multi-stage Dockerfile (Xfce + noVNC + Chromium) accessible in-browser
4. Backup/restore system with auto-backup toggle — captures both container image and workspace volume
5. MCP Toolkit auto-connection + Claude Code remote control on container startup
6. Interactive settings CLI, comprehensive README, Apache 2.0 license, and SECURITY.md risk analysis

---

