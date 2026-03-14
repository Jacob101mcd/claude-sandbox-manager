# Phase 1: Foundation + Security - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Cross-platform entry point (Linux first), modular code structure, security hardening, and bug fixes for the existing codebase. Windows support maintained via existing PowerShell scripts. No new features — this phase makes the existing tool portable and secure.

</domain>

<decisions>
## Implementation Decisions

### Scripting language
- Bash for Linux/macOS — clean rewrite, not a line-by-line port of the PowerShell
- Bash 4+ features allowed (arrays, associative arrays, [[ ]], etc.)
- Windows keeps existing PowerShell scripts as-is — two separate codebases sharing the same Dockerfile
- jq is a required dependency for JSON parsing

### Code structure
- Single entry point (`csm`) that sources `lib/*.sh` modules (docker.sh, ssh.sh, instances.sh, etc.)
- Layout: `bin/csm` (entry point), `lib/*.sh` (modules) at project root
- Windows scripts remain in `scripts/` directory
- Instance state continues using `.instances.json` (parsed with jq)

### Entry point & CLI UX
- Command name: `csm`
- Interactive menu mode (like current Windows manager) — shows instance list and action menu in a loop
- Run from project directory only — no global install step
- After starting an instance, prompt user: "SSH into instance now? (y/N)"

### Security hardening
- Hardcoded password removed — passwordless sudo for claude user (NOPASSWD)
- SSH bound to localhost only: `-p 127.0.0.1:${port}:22`
- Docker capabilities: drop only unused ones (MKNOD, AUDIT_WRITE, SETFCAP, SETPCAP, NET_BIND_SERVICE, SYS_CHROOT, FSETID) — keep all others for sudo/apt/debugging compatibility
- Resource limits: 2GB RAM (`--memory=2g`), 2 CPUs (`--cpus=2`) as defaults
- `--no-new-privileges` flag added to container run

### Claude's Discretion
- Exact lib/*.sh module breakdown and naming
- Error message wording and color scheme
- How to detect and display orphaned containers (BUG-01, BUG-02)
- Dockerfile optimization (layer ordering, cleanup)
- SSH key management approach for Linux (adapt from PowerShell logic)

</decisions>

<specifics>
## Specific Ideas

- Interactive menu should feel similar to the current Windows PowerShell manager — familiar UX for existing users
- Clean rewrite means using Bash idioms, not translating PowerShell patterns

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `scripts/common.ps1`: Reference implementation for all shared logic (~339 lines) — instance registry, SSH key management, Docker build/run, port allocation, workspace migration
- `scripts/claude-manager.ps1`: Reference for interactive menu (start/stop/create/remove loop)
- `scripts/Dockerfile`: Base container definition — needs security fixes but structure is reusable
- `.instances.json`: Existing state format — continue using this schema

### Established Patterns
- Instance naming: `claude-sandbox-{name}` for containers, `claude-{name}` for SSH aliases
- Port allocation: starts at 2222, increments to find free port
- SSH key per instance: stored in `ssh/{name}/` directory
- Workspace volumes: `workspaces/{name}/` mounted to `/home/claude/workspace`
- Backup directories: `backups/{name}/`

### Integration Points
- Dockerfile is shared between Bash and PowerShell paths
- `.instances.json` schema must be compatible if users switch between platforms
- SSH config entries written to `~/.ssh/config`

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 01-foundation-security*
*Context gathered: 2026-03-13*
