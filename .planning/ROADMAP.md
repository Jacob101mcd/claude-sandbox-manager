# Roadmap: Claude Sandbox Manager

## Overview

This roadmap transforms the existing Windows-only `.bat` script toolchain into a cross-platform sandbox manager with two container variants, secure credential handling, backup/restore, MCP Toolkit integration, and a settings CLI — all without requiring Docker expertise from the user. Work proceeds foundation-first: platform portability and security hardening unlock the container engine, which unlocks backup design, which unlocks the GUI variant, which unlocks integration features, which unlocks the settings and documentation layer that completes the product.

## Phases

**Phase Numbering:**
- Integer phases (1, 2, 3): Planned milestone work
- Decimal phases (2.1, 2.2): Urgent insertions (marked with INSERTED)

Decimal phases appear between their surrounding integers in numeric order.

- [x] **Phase 1: Foundation + Security** - Cross-platform entry point, modular code structure, bug fixes, and immediate security hardening of the existing codebase (completed 2026-03-13)
- [ ] **Phase 2: Container Engine** - End-to-end container lifecycle (create/start/stop/ssh) on Linux and macOS with minimal CLI variant, credential injection, and Claude Code via native installer
- [x] **Phase 3: Backup + Data Safety** - Full container backup and restore that correctly captures both container filesystem and workspace volume data, with optional auto-backup on startup (completed 2026-03-13)
- [x] **Phase 4: GUI Container Variant** - Desktop environment container (Xfce + noVNC) accessible in-browser, sharing the minimal variant's base stage (completed 2026-03-13)
- [ ] **Phase 5: Integration Layer** - Docker Desktop MCP Toolkit auto-connection, Claude Code remote control option, and resource limit enforcement
- [ ] **Phase 6: Settings + Documentation** - Interactive settings CLI, config file, README additions, and security disclaimers completing the user-facing product

## Phase Details

### Phase 1: Foundation + Security
**Goal**: Users can run the manager on Linux (and the existing Windows path continues to work), with all critical security issues in the current codebase patched
**Depends on**: Nothing (first phase)
**Requirements**: PLAT-01, PLAT-02, PLAT-03, PLAT-04, QUAL-01, QUAL-02, QUAL-03, QUAL-04, SEC-01, SEC-02, SEC-03, SEC-04, BUG-01, BUG-02
**Success Criteria** (what must be TRUE):
  1. Running `csm` (or equivalent entry point) on Linux starts the manager without errors
  2. Running the existing Windows entry point continues to work without regression
  3. Platform-specific paths and commands (Linux vs macOS vs Windows) are detected and handled without user configuration
  4. The Dockerfile no longer contains a hardcoded password; SSH is bound to localhost only
  5. Orphaned/stale container instances appear in the instance list and can be detected by the manager
**Plans:** 4/4 plans complete

Plans:
- [x] 01-01-PLAN.md — Dockerfile security hardening + test infrastructure
- [x] 01-02-PLAN.md — Core library modules (common, platform, instances)
- [x] 01-03-PLAN.md — Docker and SSH modules with security hardening
- [x] 01-04-PLAN.md — Interactive menu + entry point integration

### Phase 2: Container Engine
**Goal**: Users can create, start, stop, SSH into, and remove sandbox instances running the minimal CLI container variant, with API key and GitHub credentials automatically available inside the container
**Depends on**: Phase 1
**Requirements**: CONT-01, CONT-03, INST-01, CRED-01, CRED-02, CRED-03, CRED-04
**Success Criteria** (what must be TRUE):
  1. User can create a new minimal CLI container instance with a single command and be prompted for container type
  2. User can SSH into a running instance and find Claude Code pre-installed and functional (installed via native installer, not NPM)
  3. Claude Code inside the container has access to ANTHROPIC_API_KEY without the user manually setting it
  4. GitHub CLI inside the container is authenticated with the user's token and can run `gh` commands
  5. Credentials are not present in the Docker image layers (verified by inspecting image history)
**Plans:** 1/2 plans executed

Plans:
- [ ] 02-01-PLAN.md — Credential module + Dockerfile overhaul (native installer, gh CLI)
- [ ] 02-02-PLAN.md — Credential injection wiring, container type selection, instance registry extension

### Phase 3: Backup + Data Safety
**Goal**: Port the existing working backup/restore system to Linux and macOS, and add the optional auto-backup-on-startup toggle
**Depends on**: Phase 2
**Requirements**: BACK-01, BACK-02, BACK-03, BACK-04
**Note**: Backup system already exists and works on Windows. This phase ports it cross-platform and adds auto-backup.
**Success Criteria** (what must be TRUE):
  1. Existing backup/restore functionality works on Linux and macOS without modification
  2. After restore, the container's workspace directory contains the same files as before backup
  3. Auto-backup can be toggled on; when on, a backup archive is created each time an instance starts
  4. User can restore an instance from a specific backup archive and have it running via SSH
**Plans:** 2/2 plans complete

Plans:
- [ ] 03-01-PLAN.md — Backup module with backup_create, backup_restore, backup_list + BATS tests
- [ ] 03-02-PLAN.md — Menu integration (B/E actions), auto-backup hook, entry point wiring

### Phase 4: GUI Container Variant
**Goal**: Users can create a GUI container instance and access a full desktop environment with a browser through a web URL, with no VNC client installation required
**Depends on**: Phase 2
**Requirements**: CONT-02, CONT-04, CONT-05
**Success Criteria** (what must be TRUE):
  1. User can select "GUI" container type at creation time and have it build and start without additional steps
  2. User can open a browser and reach the container's desktop environment at a localhost URL
  3. A browser opened inside the container desktop renders web pages correctly (shared memory is sufficient — no crash on page load)
**Plans:** 2/2 plans complete

Plans:
- [ ] 04-01-PLAN.md — Multi-stage Dockerfile (base/cli/gui) + entrypoint VNC startup
- [ ] 04-02-PLAN.md — VNC port allocation, type-aware build/run, GUI menu activation + BATS tests

### Phase 5: Integration Layer
**Goal**: All sandbox instances automatically connect to the host Docker Desktop MCP Toolkit server on startup, and Claude Code remote control is available as an optional toggle
**Depends on**: Phase 2
**Requirements**: MCP-01, MCP-02, MCP-03, INST-02
**Success Criteria** (what must be TRUE):
  1. A newly started container can reach the host MCP Gateway without any manual per-container configuration
  2. The README contains clear instructions for setting up Docker Desktop MCP Toolkit on the host before creating instances
  3. MCP connection works consistently across multiple running instances without conflicts
  4. User can optionally enable Claude Code remote control on a container at startup time
**Plans**: TBD

### Phase 6: Settings + Documentation
**Goal**: Users can browse and change all manager preferences through an interactive CLI menu, and the README fully represents the project's purpose, security posture, and setup requirements
**Depends on**: Phase 5
**Requirements**: SETT-01, SETT-02, SETT-03, SETT-04, SEC-05, SEC-06, DOC-01, DOC-02, DOC-03
**Success Criteria** (what must be TRUE):
  1. User can run `csm settings` and change preferences (auto-backup toggle, default container type) without editing a config file manually
  2. A user with zero prior configuration can clone the repo and create a working container with only their API key — all other defaults are sensible
  3. The README explains "Why I built this" and "Who is this for" in plain language
  4. The README contains a security risk summary and appropriate disclaimers about running AI agents in containers
  5. A documented security risk analysis (with mitigations) exists and is referenced from the README
**Plans**: TBD

## Progress

**Execution Order:**
Phases execute in numeric order: 1 → 2 → 3 → 4 → 5 → 6

| Phase | Plans Complete | Status | Completed |
|-------|----------------|--------|-----------|
| 1. Foundation + Security | 4/4 | Complete   | 2026-03-13 |
| 2. Container Engine | 1/2 | In Progress|  |
| 3. Backup + Data Safety | 2/2 | Complete   | 2026-03-13 |
| 4. GUI Container Variant | 2/2 | Complete   | 2026-03-13 |
| 5. Integration Layer | 0/? | Not started | - |
| 6. Settings + Documentation | 0/? | Not started | - |
