# Project Research Summary

**Project:** Claude Sandbox Manager
**Domain:** Docker-based AI coding sandbox management (cross-platform CLI)
**Researched:** 2026-03-13
**Confidence:** HIGH

## Executive Summary

Claude Sandbox Manager is a local Docker instance manager purpose-built for Claude Code users who need isolated, reproducible coding environments without Docker expertise. The existing tool works but is Windows-only (PowerShell/.bat), uses a monolithic 339-line shared module, and has several security issues (hardcoded password, SSH ports exposed on 0.0.0.0, no resource limits). The recommended path is a cross-platform rewrite using **Bash scripts** (not Node.js) as the primary scripting layer — users already have Docker, Bash ships with Git for Windows, and adding another runtime for the manager itself would be unnecessary weight. The architecture should migrate from a single `common.ps1` blob to a layered module system with clear component boundaries.

The competitive niche is well-defined: this tool is not DevPod, not Docker Sandboxes, not Coder. Its advantage is **opinionated simplicity for Claude Code users** — sensible defaults, menu-driven interaction, built-in backup, multiple container variants (minimal CLI and GUI desktop), and optional Docker Desktop MCP Toolkit integration. The most important differentiators to build are the cross-platform CLI rewrite, credential injection (ANTHROPIC_API_KEY + GitHub token), and the minimal container variant. The GUI container, MCP Toolkit integration, and instance templates are validated differentiators but should be deferred until the foundation is solid.

Key risks are concrete and preventable: the existing Dockerfile bakes a plaintext password into image layers, `docker export` silently omits bind-mounted workspace data from backups (the most important user data), UID/GID mismatches break file permissions on Linux despite working on macOS, and GUI containers crash browsers due to Docker's 64MB `/dev/shm` default. All four are well-understood problems with clear fixes documented in the pitfalls research. Cross-platform script portability (GNU vs BSD coreutils, bash 3.2 on macOS) is the other class of risk that must be designed in from day one rather than retrofitted.

## Key Findings

### Recommended Stack

The stack is TypeScript/Node.js for the CLI host tool paired with Bash for script internals. However, the ARCHITECTURE.md research recommends Bash as the primary scripting language rather than Node.js, which conflicts with STACK.md's TypeScript recommendation. Both are coherent positions: STACK.md argues users already have Node.js (Claude Code requires it), while ARCHITECTURE.md argues Bash avoids an extra runtime dependency and runs on Git Bash/WSL on Windows. The roadmap should resolve this by choosing one direction; the current research leans toward Node.js/TypeScript given the richer library ecosystem for Docker operations (dockerode), interactive menus (@inquirer/prompts), and type safety for managing SSH keys and container configuration.

**Core technologies:**
- TypeScript 5.5 + Node.js 20 LTS: type-safe CLI — catches container config errors at compile time; Node.js is already required by Claude Code
- Commander.js 14: command parsing — zero dependencies, 18ms startup, handles 10-command CLI cleanly without oclif's 30+ dep overhead
- @inquirer/prompts 8.3: interactive menus — essential for "accessible to non-Docker-experts" goal
- dockerode 4.0.9: Docker API client — programmatic container lifecycle with typed responses, avoids fragile CLI output parsing
- execa 9.6: process execution — cross-platform ssh-keygen invocation with proper error handling
- conf 13.0: config storage — OS-native paths (avoids `.instances.json` in project root breaking on global install)
- Xvfb + x11vnc + noVNC: GUI container stack — zero-install browser access to desktop containers; lighter and more standard than KasmVNC
- ESM-only modules: chalk, ora, execa are ESM-only; `"type": "module"` in package.json is mandatory

### Expected Features

**Must have (table stakes):**
- Cross-platform CLI (Linux + macOS + Windows via Git Bash) — Windows-only is a dealbreaker; this is the biggest gap vs. every competitor
- Credential injection (ANTHROPIC_API_KEY + GitHub token) — Claude Code cannot function without API key; GitHub CLI is needed for agent workflows
- Container lifecycle management (create, start, stop, remove, list) — already exists, needs cross-platform rewrite
- Workspace persistence across restarts — already exists via bind mounts
- Backup and restore — partially exists; must be redesigned to correctly handle workspace data
- Pre-installed toolchain (Node.js, Python, Go, Git, gh CLI, ripgrep, jq) — ready-to-code expectation
- Sensible defaults + zero config — critical for non-Docker-expert target audience
- SSH access to containers — already exists

**Should have (competitive differentiators):**
- Multiple container variants (minimal CLI, GUI desktop with noVNC) — biggest differentiator; Docker Sandboxes offers one type
- Settings manager with config file + CLI menu — no competitor has a lightweight settings UI
- Selectable pre-installed packages/frameworks — no competitor allows per-instance customization at creation time
- Docker Desktop MCP Toolkit integration — unique to this tool; gives Claude Code in containers access to 200+ MCP tools
- Auto-backup on startup (toggleable) — no competitor does this; protects against container corruption
- Claude Code native installer (not NPM) — more reliable, preferred by Anthropic

**Defer (v2+):**
- GUI container variant: high complexity (X11/VNC stack); validate CLI variant demand first
- Instance templates/profiles: natural follow-up after settings + container variants exist
- Claude Code remote control integration: depends on native installer; secondary to SSH
- Docker Desktop MCP Toolkit: requires Docker Desktop 4.50+; ship as opt-in later

**Explicit anti-features** (do not build): Kubernetes, VS Code Dev Container integration, web IDE, per-container MCP server setup, cloud provider integration, devcontainer.json compatibility, Docker Compose orchestration.

### Architecture Approach

The architecture follows a layered module pattern replacing the current monolithic `common.ps1`. A single entry point (`bin/csm`) dispatches to subcommands; core modules (platform detection, config, registry, output) are loaded by all commands; domain modules (docker, ssh, backup) load on demand. State lives in a JSON registry file (adequate for 1-5 instances; don't over-engineer for scale). Two Dockerfiles — `minimal.Dockerfile` and `gui.Dockerfile` — share a common base stage but diverge for the desktop stack. Windows users get thin `.bat` wrappers that call bash via Git Bash or WSL.

**Major components:**
1. `bin/csm` (entry point) — argument parsing, subcommand dispatch, help output
2. `lib/core/` (platform, config, registry) — OS detection, settings store, instance state CRUD
3. `lib/docker/` (images, containers, backup) — image building, container lifecycle, export/import
4. `lib/ssh/` (keys, config) — keypair generation, SSH config block management
5. `lib/ui/` (menu, output) — interactive menus, colored output, progress indicators
6. `dockerfiles/` (minimal, gui) — container image definitions per type

### Critical Pitfalls

1. **Hardcoded password in Dockerfile** — use `NOPASSWD` sudo + `passwd -l claude` instead; fix immediately in Phase 1 security pass
2. **docker export silently drops bind-mounted workspace data** — design backup to explicitly tar the workspace directory separately from container export; test restore end-to-end
3. **UID/GID mismatch breaks file permissions on Linux** — use an entrypoint script that detects host UID and adjusts container user at runtime with `usermod`; must be solved before Linux can be primary target
4. **GUI containers crash browsers due to 64MB /dev/shm default** — always pass `--shm-size=2g` for GUI containers; make this non-configurable
5. **Cross-platform script portability (GNU vs BSD coreutils)** — use `printf` not `echo -e`, use `#!/usr/bin/env bash`, avoid bash 4+ features, run ShellCheck in CI, test on macOS BSD environment
6. **SSH port exposed on 0.0.0.0** — bind to `127.0.0.1` only; current code does NOT do this and is an active security issue

## Implications for Roadmap

Based on combined research, the architecture's own build-order analysis and the pitfalls' phase-to-prevention mapping strongly agree on a 5-6 phase structure:

### Phase 1: Foundation + Security Fixes

**Rationale:** Platform detection and config must exist before any other module runs. Security issues in the existing Dockerfile are quick fixes that should not persist into the rewrite. This phase has no dependencies and unblocks all subsequent phases.
**Delivers:** Cross-platform entry point, core module skeleton, settings store, instance registry, secure Dockerfile (no hardcoded password, localhost-only SSH port binding)
**Addresses:** Cross-platform CLI (table stakes), sensible defaults (table stakes)
**Avoids:** Hardcoded password pitfall, SSH port exposure pitfall, monolithic common module anti-pattern
**Research flag:** Standard patterns — well-documented CLI structure and Docker security hardening; skip phase research

### Phase 2: Container Engine (Core Value)

**Rationale:** Container lifecycle is the core value proposition. Once the foundation exists, this phase delivers the end-to-end create/start/stop/ssh flow on Linux and macOS. This is what users need before anything else.
**Delivers:** `csm create`, `csm start`, `csm stop`, `csm rm`, `csm list`, `csm ssh` — all cross-platform; minimal container variant with expanded toolchain; SSH key management; credential injection (ANTHROPIC_API_KEY + GitHub token)
**Addresses:** All table-stakes features (lifecycle, SSH access, workspace persistence, toolchain, credential injection)
**Avoids:** UID/GID mismatch pitfall (Linux-first entrypoint design), interactive-only interface anti-pattern
**Research flag:** Standard patterns for container lifecycle; may need targeted research on UID remapping entrypoint implementation

### Phase 3: Data Safety (Backup/Restore)

**Rationale:** Backup depends on working containers. The backup architecture must explicitly address the docker export + workspace volume gap — designing this after the container layer is working means the correct architecture can be chosen based on how volumes are actually structured.
**Delivers:** `csm backup`, `csm restore`, auto-backup-on-startup toggle; backup correctly captures both container filesystem and workspace directory; end-to-end restore test
**Addresses:** Backup and restore (table stakes), auto-backup differentiator
**Avoids:** Backup loses volume data pitfall (critical design requirement)
**Research flag:** Standard patterns for docker export + file archiving; no research phase needed

### Phase 4: GUI Container Variant

**Rationale:** GUI is a validated differentiator but high complexity. Building it after the minimal variant is proven means the base stage is stable, and the GUI-specific startup scripts (VNC/supervisord) layer on top without destabilizing the core.
**Delivers:** `gui.Dockerfile` with Xfce + x11vnc + noVNC, supervisord process management, `--shm-size=2g` enforced, browser access at localhost:6080
**Addresses:** Multiple container variants (primary differentiator)
**Avoids:** Shared memory crash pitfall (must set shm-size from day one), single Dockerfile anti-pattern (separate files)
**Research flag:** Needs phase research — Xvfb + x11vnc + noVNC + supervisord stack has integration complexity; reference implementations exist but need validation

### Phase 5: Integration Layer

**Rationale:** Integration features (MCP Toolkit, Claude Code remote control, GitHub CLI auth passthrough) layer on working containers. They require environment detection and graceful degradation; building them after core is stable avoids coupling integration concerns to foundational code.
**Delivers:** Docker Desktop MCP Toolkit detection + configuration, Claude Code native installer switch, GitHub CLI auth passthrough, resource limits (memory + CPU defaults)
**Addresses:** MCP Toolkit differentiator, Claude Code native installer, security resource limits
**Avoids:** Docker socket mounting security mistake, API keys in environment variables mistake
**Research flag:** MCP Toolkit integration needs phase research — requires Docker Desktop 4.50+, Linux behavior differs from Desktop, API may evolve

### Phase 6: Settings, Polish, and Migration

**Rationale:** Settings management spans all features — easier to build the settings menu once all features are stable and their configuration surface is known. Migration from the existing `.bat` structure is last because it requires the full replacement to be working.
**Delivers:** `csm settings` interactive menu, package selection per container type, instance templates, migration tooling from old `.bat` structure, ShellCheck CI, disk usage warnings
**Addresses:** Settings manager differentiator, selectable packages differentiator, instance templates (v1.5 feature)
**Avoids:** Container accumulation performance trap, `--no-cache` anti-pattern, user-visible Docker error messages
**Research flag:** Standard patterns for CLI settings menus; no research phase needed

### Phase Ordering Rationale

- Platform detection must precede everything — it's a zero-dependency module that all others import
- Security fixes are bundled with Phase 1 not because they're complex, but because they should not persist another day
- Container engine (Phase 2) before backup (Phase 3) because backup design depends on knowing how volumes are structured in practice
- GUI (Phase 4) after minimal CLI is proven — shares the base Dockerfile stage; GUI-specific complexity doesn't contaminate core
- Integration features (Phase 5) require working containers as a prerequisite and should degrade gracefully when Docker Desktop features aren't present
- Settings and migration are last because they're summarizing/configuring what's already built

### Research Flags

Phases needing deeper research during planning:
- **Phase 4 (GUI Container):** Xvfb + x11vnc + noVNC + supervisord integration has multiple moving parts; reference implementations exist but interactions need validation; GUI desktop startup sequencing is non-trivial
- **Phase 5 (MCP Toolkit):** Docker Desktop MCP Gateway behavior differs between macOS/Windows (Docker Desktop) and Linux (Docker Engine without Desktop); detection and fallback strategy needs research; API endpoint stability unknown

Phases with standard patterns (skip research-phase):
- **Phase 1 (Foundation):** CLI subcommand dispatch, JSON config, platform detection — all well-documented patterns
- **Phase 2 (Container Engine):** Docker lifecycle, SSH key management, credential injection — established patterns with clear documentation
- **Phase 3 (Backup):** docker export + file archiving + restore — documented Docker patterns; the key insight (volumes not captured) is already known
- **Phase 6 (Settings/Polish):** CLI interactive menus, migration scripts — standard patterns

## Confidence Assessment

| Area | Confidence | Notes |
|------|------------|-------|
| Stack | HIGH | All packages confirmed on npm with exact versions; compatibility notes (ESM-only, dockerode CJS interop) verified |
| Features | HIGH | Competitive landscape well-researched; PROJECT.md provides explicit scope constraints; anti-features explicitly called out |
| Architecture | HIGH | Based on existing codebase analysis + established CLI patterns; build order has clear dependency rationale |
| Pitfalls | HIGH | Critical pitfalls verified against official Docker docs, CVE databases, and existing codebase issues (SSH line endings bug already hit in production) |

**Overall confidence:** HIGH

### Gaps to Address

- **Node.js vs Bash scripting language decision:** STACK.md recommends TypeScript/Node.js; ARCHITECTURE.md recommends Bash. Both are coherent. This is the single biggest unresolved question. Recommendation: resolve in requirements definition by checking if the team wants type safety (Node.js) or minimal runtime dependency (Bash). The current PROJECT.md's existing Bash/PowerShell dual approach suggests Bash is acceptable.
- **Claude Code native installer stability:** Research notes the installer URL/method may change across versions. Pin to a specific version or add a fallback to NPM; validate the current installer URL before implementing.
- **MCP Toolkit on Linux Docker Engine:** Whether MCP Gateway can be configured on plain Docker Engine (without Docker Desktop) needs hands-on validation. The documentation is sparse for Linux-only environments.
- **macOS bind mount performance:** `:cached`/`:delegated` mount flags behavior has changed across Docker Desktop versions; validate current flag support before relying on them for workspace performance.

## Sources

### Primary (HIGH confidence)
- Commander.js npm (v14.0.3 confirmed), dockerode npm (v4.0.9), @inquirer/prompts npm (v8.3.0), execa npm (v9.6.1)
- [Docker export documentation](https://docs.docker.com/reference/cli/docker/container/export/) — volumes excluded behavior confirmed
- [Docker Sandboxes Documentation](https://docs.docker.com/ai/sandboxes/) — competitive feature comparison
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- Existing codebase analysis (scripts/Dockerfile, scripts/common.ps1, scripts/backup-claude.ps1) — as-is architecture

### Secondary (MEDIUM confidence)
- [Docker MCP Toolkit docs](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/) — MCP integration architecture; Linux behavior not fully documented
- [vnc-containers GitHub](https://github.com/silentz/vnc-containers) — Xvfb + x11vnc + noVNC reference
- [Gitpod vs Codespaces vs Coder vs DevPod Comparison](https://www.vcluster.com/blog/comparing-coder-vs-codespaces-vs-gitpod-vs-devpod) — competitive landscape
- [Container escape vulnerabilities for AI agents (2026)](https://blaxel.ai/blog/container-escape) — CVE-2025-31133, CVE-2025-52565

### Tertiary (MEDIUM-LOW confidence)
- [Claude Code Remote Control Guide](https://www.digitalapplied.com/blog/claude-code-remote-control-feature-guide/) — remote control integration; API stability unknown
- [tsup GitHub](https://github.com/egoist/tsup) — maintenance mode noted; tsdown is successor but too new

---
*Research completed: 2026-03-13*
*Ready for roadmap: yes*
