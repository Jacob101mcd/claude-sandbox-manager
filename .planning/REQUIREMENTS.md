# Requirements: Claude Sandbox Manager

**Defined:** 2026-03-13
**Core Value:** Safe, hands-free Claude Code sandboxes that anyone can spin up without Docker expertise

## v1 Requirements

Requirements for initial release. Each maps to roadmap phases.

### Cross-Platform

- [x] **PLAT-01**: Manager scripts run natively on Linux without modification
- [x] **PLAT-02**: Manager scripts run natively on macOS without modification
- [x] **PLAT-03**: Existing Windows support maintained alongside Linux/macOS
- [x] **PLAT-04**: Platform-specific differences (paths, commands) detected and handled automatically

### Container Variants

- [x] **CONT-01**: User can build and run a minimal CLI container (lightweight, headless)
- [x] **CONT-02**: User can build and run a GUI container with desktop environment and browser
- [x] **CONT-03**: Instance manager presents container type selection when creating new instances
- [x] **CONT-04**: GUI container runs Xvfb + noVNC for browser-based desktop access
- [ ] **CONT-05**: GUI containers start with adequate shared memory (--shm-size=512m minimum)

### Claude Code Installation

- [x] **INST-01**: Claude Code installed via native installer (not NPM) during container build
- [ ] **INST-02**: Claude Code remote control optionally configured on container startup

### Credential Management

- [x] **CRED-01**: ANTHROPIC_API_KEY automatically injected into container environment
- [x] **CRED-02**: GitHub CLI pre-installed in containers
- [x] **CRED-03**: GitHub CLI auto-authenticated with user-provided token on container build
- [x] **CRED-04**: Credentials never baked into Docker images (runtime injection only)

### Settings Management

- [ ] **SETT-01**: JSON config file in project root stores all user preferences
- [ ] **SETT-02**: CLI menu allows browsing and modifying settings interactively
- [ ] **SETT-03**: Settings include: auto-backup toggle, default container type, default packages
- [ ] **SETT-04**: Sensible defaults work out of the box with zero configuration

### Backup & Data Safety

- [x] **BACK-01**: User can manually trigger full container backup via docker export
- [x] **BACK-02**: Optional auto-backup on instance startup (togglable via settings)
- [x] **BACK-03**: Backup captures both container filesystem and workspace volume data
- [x] **BACK-04**: User can restore an instance from a backup

### MCP Integration

- [ ] **MCP-01**: Sandbox instances automatically connect to host Docker MCP Toolkit server on startup
- [ ] **MCP-02**: README includes instructions for setting up Docker Desktop MCP Toolkit on the host
- [ ] **MCP-03**: MCP connection works without per-container MCP configuration

### Code Quality

- [x] **QUAL-01**: Codebase restructured with clear separation of concerns (no monolithic scripts)
- [x] **QUAL-02**: Code follows Docker best practices (multi-stage builds, minimal layers, no root)
- [x] **QUAL-03**: Code follows Claude Code best practices for sandbox environments
- [x] **QUAL-04**: Consistent coding style and naming conventions across all scripts

### Security

- [x] **SEC-01**: Hardcoded passwords removed from Dockerfiles (use passwordless sudo)
- [x] **SEC-02**: SSH bound to localhost only (not 0.0.0.0)
- [x] **SEC-03**: Docker capabilities dropped to minimum required set
- [x] **SEC-04**: Resource limits set on containers (memory, CPU)
- [ ] **SEC-05**: Security risk analysis documented with mitigations
- [ ] **SEC-06**: Appropriate disclaimers added to README

### Documentation

- [ ] **DOC-01**: README includes "Why I built this" section
- [ ] **DOC-02**: README includes "Who is this for" section
- [ ] **DOC-03**: README includes security disclaimers and risk acknowledgments

### Bug Fixes

- [x] **BUG-01**: Rebuilt containers no longer pile up as orphaned instances in Docker
- [x] **BUG-02**: Manager detects and displays all existing container instances (including orphaned)

## v2 Requirements

Deferred to future release. Tracked but not in current roadmap.

### Container Variants

- **CONT-V2-01**: Windows 11 Docker container/sandbox support
- **CONT-V2-02**: macOS Docker container/sandbox support

### Package Management

- **PKG-V2-01**: User can select which packages/frameworks come pre-installed per container
- **PKG-V2-02**: Curated list of popular package "packs" (Python data science, web dev, etc.)

### Templates

- **TMPL-V2-01**: User can save container configuration as named template
- **TMPL-V2-02**: User can create new instances from saved templates

## Out of Scope

| Feature | Reason |
|---------|--------|
| Kubernetes/cluster orchestration | Massively over-scoped; this tool targets single-machine Docker users |
| VS Code Dev Container integration | Using Claude Code remote control instead |
| Web-based IDE | Duplicates existing products, not aligned with CLI-first philosophy |
| Per-container MCP server setup | Docker Desktop MCP Toolkit handles this at host level |
| Cloud provider integration | This tool is for local Docker environments |
| devcontainer.json compatibility | Would require implementing full Dev Container spec |
| Docker Compose orchestration | Moved to build/run for instance isolation |
| Automatic container scaling | Enterprise feature not needed for personal use |
| Built-in code editor | Users bring their own terminal/editor |

## Traceability

| Requirement | Phase | Status |
|-------------|-------|--------|
| PLAT-01 | Phase 1 | Complete |
| PLAT-02 | Phase 1 | Complete |
| PLAT-03 | Phase 1 | Complete |
| PLAT-04 | Phase 1 | Complete |
| QUAL-01 | Phase 1 | Complete |
| QUAL-02 | Phase 1 | Complete |
| QUAL-03 | Phase 1 | Complete |
| QUAL-04 | Phase 1 | Complete |
| SEC-01 | Phase 1 | Complete |
| SEC-02 | Phase 1 | Complete |
| SEC-03 | Phase 1 | Complete |
| SEC-04 | Phase 1 | Complete |
| BUG-01 | Phase 1 | Complete |
| BUG-02 | Phase 1 | Complete |
| CONT-01 | Phase 2 | Complete |
| CONT-03 | Phase 2 | Complete |
| INST-01 | Phase 2 | Complete |
| CRED-01 | Phase 2 | Complete |
| CRED-02 | Phase 2 | Complete |
| CRED-03 | Phase 2 | Complete |
| CRED-04 | Phase 2 | Complete |
| BACK-01 | Phase 3 | Complete |
| BACK-02 | Phase 3 | Complete |
| BACK-03 | Phase 3 | Complete |
| BACK-04 | Phase 3 | Complete |
| CONT-02 | Phase 4 | Complete |
| CONT-04 | Phase 4 | Complete |
| CONT-05 | Phase 4 | Pending |
| MCP-01 | Phase 5 | Pending |
| MCP-02 | Phase 5 | Pending |
| MCP-03 | Phase 5 | Pending |
| INST-02 | Phase 5 | Pending |
| SETT-01 | Phase 6 | Pending |
| SETT-02 | Phase 6 | Pending |
| SETT-03 | Phase 6 | Pending |
| SETT-04 | Phase 6 | Pending |
| SEC-05 | Phase 6 | Pending |
| SEC-06 | Phase 6 | Pending |
| DOC-01 | Phase 6 | Pending |
| DOC-02 | Phase 6 | Pending |
| DOC-03 | Phase 6 | Pending |

**Coverage:**
- v1 requirements: 41 total
- Mapped to phases: 41
- Unmapped: 0 ✓

---
*Requirements defined: 2026-03-13*
*Last updated: 2026-03-13 — traceability mapped after roadmap creation*
