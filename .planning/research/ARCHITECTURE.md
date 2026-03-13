# Architecture Patterns

**Domain:** Docker-based AI sandbox management (cross-platform CLI)
**Researched:** 2026-03-13

## Current Architecture (As-Is)

The existing system is a Windows-only PowerShell application with a flat script structure:

```
claude-manager.bat          (entry point - calls PowerShell)
  scripts/
    common.ps1              (shared functions: instance registry, SSH, Docker ops)
    claude-manager.ps1      (interactive menu loop)
    rebuild-claude.ps1      (rebuild a container)
    backup-claude.ps1       (commit + export container)
    restore-claude.ps1      (load image + restart container)
    ssh-claude.ps1          (SSH into container)
    Dockerfile              (single container type: Ubuntu + Node + Claude Code)
```

**State management:** `.instances.json` file in project root (flat JSON, name-to-port mapping).

**Key coupling problems:**
- All logic in `common.ps1` -- instance registry, SSH key management, Docker operations, SSH config writing, port management are a single 339-line file
- Container type is hardcoded (one Dockerfile for all instances)
- Platform locked to Windows (PowerShell + .bat wrappers)
- No configuration system (no settings file, no defaults management)
- Backup uses `docker commit` + `docker save` rather than `docker export`

## Recommended Architecture (To-Be)

Use **Bash** as the cross-platform scripting language. Bash runs natively on Linux and macOS, and on Windows via Git Bash (ships with Git for Windows) or WSL. This avoids introducing a Node.js/Python runtime dependency just for the manager itself. The containers already need Docker -- adding another runtime for the manager tool is unnecessary weight.

### Component Diagram

```
User
  |
  v
bin/csm                          (entry point: dispatches subcommands)
  |
  +-- lib/core/config.sh         (settings file read/write)
  +-- lib/core/registry.sh       (instance state: CRUD on instances.json)
  +-- lib/core/platform.sh       (OS detection, path normalization)
  |
  +-- lib/docker/images.sh       (image build: selects Dockerfile by type)
  +-- lib/docker/containers.sh   (container lifecycle: create/start/stop/rm)
  +-- lib/docker/backup.sh       (docker export/import for backups)
  |
  +-- lib/ssh/keys.sh            (SSH keypair generation + staging)
  +-- lib/ssh/config.sh          (SSH config block management)
  |
  +-- lib/ui/menu.sh             (interactive menu for TUI mode)
  +-- lib/ui/output.sh           (colored output, progress, errors)
  |
  +-- dockerfiles/
  |     minimal.Dockerfile       (headless: Ubuntu + Claude Code CLI)
  |     gui.Dockerfile           (desktop: + Xfce/noVNC + browser)
  |
  +-- templates/
        packages.conf            (default package lists per container type)
```

### Component Boundaries

| Component | Responsibility | Communicates With |
|-----------|---------------|-------------------|
| `bin/csm` | Entry point, argument parsing, subcommand dispatch | All lib modules |
| `lib/core/config.sh` | Read/write settings.json, provide defaults, validate values | Registry (for defaults), UI (for settings menu) |
| `lib/core/registry.sh` | CRUD operations on instance metadata (name, port, type, created date) | Config (for defaults), Docker modules (for status queries) |
| `lib/core/platform.sh` | OS detection, path separator handling, Docker socket detection | Used by all other modules |
| `lib/docker/images.sh` | Build Docker images from type-specific Dockerfiles, cache management | Registry (for instance type), Platform (for Docker path) |
| `lib/docker/containers.sh` | Container lifecycle: create, start, stop, remove, status | Registry (for container names/ports), Images (for image existence) |
| `lib/docker/backup.sh` | Export container state, compress, restore from backup | Containers (for stop/start), Registry (for metadata) |
| `lib/ssh/keys.sh` | Generate ed25519 keypairs, stage keys for Docker build context | Platform (for path handling) |
| `lib/ssh/config.sh` | Add/remove SSH config blocks in user's ~/.ssh/config | Registry (for port/alias), Platform (for SSH config path) |
| `lib/ui/menu.sh` | Interactive menu loop (TUI mode), instance selection dialogs | All other modules via subcommand dispatch |
| `lib/ui/output.sh` | Consistent colored output, error formatting, progress indicators | Used by all modules |
| `dockerfiles/*.Dockerfile` | Container image definitions per type | Built by images.sh |

### Data Flow

#### Instance Creation Flow

```
User: csm create --name myproject --type minimal
  |
  v
1. config.sh    -> Load settings (default packages, backup preference)
  |
  v
2. registry.sh  -> Allocate next free port, register instance metadata
  |
  v
3. keys.sh      -> Generate SSH keypair if not exists, stage to _build_ssh/
  |
  v
4. images.sh    -> Select minimal.Dockerfile, run docker build
  |                (injects SSH keys, installs Claude Code, applies packages)
  |
  v
5. containers.sh -> docker run with port mapping + workspace volume mount
  |
  v
6. ssh/config.sh -> Write SSH config block for this instance
  |
  v
7. (optional) backup.sh -> If auto-backup enabled, export previous state first
```

#### Instance Connection Flow

```
User: csm ssh myproject
  |
  v
1. registry.sh   -> Look up instance, get SSH alias
  |
  v
2. containers.sh -> Verify container is running (start if stopped)
  |
  v
3. exec: ssh <alias>   (uses host SSH config written during creation)
```

#### Settings Flow

```
settings.json (source of truth)
  |
  +-- Read at every operation (config.sh provides getter functions)
  |
  +-- Written via: csm settings (interactive menu)
  |                csm settings set <key> <value> (direct)

Example settings.json:
{
  "defaults": {
    "container_type": "minimal",
    "auto_backup": false,
    "packages": ["git", "curl", "build-essential"]
  },
  "github_token": "",
  "backup_dir": "./backups",
  "claude_install_method": "native"
}
```

#### Backup/Restore Flow

```
Backup:
  containers.sh (stop) -> docker export <container> > backup.tar
    -> gzip backup.tar
    -> Save metadata.json (instance name, type, port, date)

Restore:
  docker import backup.tar.gz -> new image
    -> containers.sh (create from imported image, same port/volume)
    -> ssh/config.sh (ensure SSH config exists)
```

**Note:** The current codebase uses `docker commit` + `docker save`, which captures the entire image layer history. `docker export` captures only the container filesystem as a flat tarball -- smaller, faster, and sufficient since we can rebuild the base image. This aligns with the project requirements.

## Patterns to Follow

### Pattern 1: Subcommand Dispatch

**What:** Single entry point (`csm`) that dispatches to subcommand scripts.
**When:** Always -- this is the CLI interface pattern.
**Why:** Familiar UX (like `git`, `docker`), easy to extend, each subcommand is independently testable.

```bash
# bin/csm
#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../lib/core/platform.sh"

case "${1:-}" in
  create)  shift; source "$SCRIPT_DIR/../lib/commands/create.sh" "$@" ;;
  start)   shift; source "$SCRIPT_DIR/../lib/commands/start.sh" "$@" ;;
  stop)    shift; source "$SCRIPT_DIR/../lib/commands/stop.sh" "$@" ;;
  rm)      shift; source "$SCRIPT_DIR/../lib/commands/rm.sh" "$@" ;;
  ssh)     shift; source "$SCRIPT_DIR/../lib/commands/ssh.sh" "$@" ;;
  backup)  shift; source "$SCRIPT_DIR/../lib/commands/backup.sh" "$@" ;;
  restore) shift; source "$SCRIPT_DIR/../lib/commands/restore.sh" "$@" ;;
  list|ls) shift; source "$SCRIPT_DIR/../lib/commands/list.sh" "$@" ;;
  settings) shift; source "$SCRIPT_DIR/../lib/commands/settings.sh" "$@" ;;
  ""|menu) source "$SCRIPT_DIR/../lib/ui/menu.sh" ;;
  *)       echo "Unknown command: $1"; exit 1 ;;
esac
```

### Pattern 2: Layered Module Loading

**What:** Core modules loaded by all commands; domain modules loaded on demand.
**When:** Every command execution.
**Why:** Keeps startup fast, avoids loading SSH logic when doing backups, etc.

```bash
# lib/commands/create.sh
source "$LIB_DIR/core/config.sh"
source "$LIB_DIR/core/registry.sh"
source "$LIB_DIR/docker/images.sh"
source "$LIB_DIR/docker/containers.sh"
source "$LIB_DIR/ssh/keys.sh"
source "$LIB_DIR/ssh/config.sh"
# ... command logic
```

### Pattern 3: Typed Dockerfiles with Shared Base

**What:** Separate Dockerfiles per container type, sharing a common base stage.
**When:** Building container images.
**Why:** Keeps type-specific concerns separate while sharing SSH setup, user creation, Claude Code installation.

```dockerfile
# dockerfiles/base.Dockerfile (used as build stage)
FROM ubuntu:24.04 AS base
RUN apt-get update && apt-get install -y openssh-server curl git sudo ...
RUN useradd -m -s /bin/bash claude && adduser claude sudo
# SSH setup, Claude Code install, etc.

# dockerfiles/minimal.Dockerfile
FROM base AS minimal
# Nothing extra needed -- lightweight CLI environment
EXPOSE 22
CMD ["/usr/sbin/sshd", "-D"]

# dockerfiles/gui.Dockerfile
FROM base AS gui
RUN apt-get install -y xfce4 xfce4-terminal tigervnc-standalone-server novnc ...
EXPOSE 22 6080
CMD ["/usr/local/bin/start-desktop.sh"]
```

### Pattern 4: JSON State with Shell Parsing

**What:** Use `jq` for reading/writing the instances registry and settings files.
**When:** Any state read/write operation.
**Why:** JSON is the existing format. `jq` is the standard tool for JSON in shell scripts -- available on all target platforms or easily installed.

```bash
# Read instance port
get_instance_port() {
  local name="$1"
  jq -r --arg n "$name" '.[$n].port // empty' "$INSTANCES_FILE"
}

# Register new instance
register_instance() {
  local name="$1" port="$2" type="$3"
  local tmp=$(mktemp)
  jq --arg n "$name" --arg p "$port" --arg t "$type" \
    '. + {($n): {port: ($p|tonumber), type: $t, created: now|todate}}' \
    "$INSTANCES_FILE" > "$tmp" && mv "$tmp" "$INSTANCES_FILE"
}
```

### Pattern 5: Platform Abstraction Layer

**What:** Thin abstraction for OS-specific operations (path handling, SSH config location, Docker socket).
**When:** Any operation that differs between Linux/macOS/Windows.
**Why:** Isolates platform quirks to one file instead of sprinkling `if` checks everywhere.

```bash
# lib/core/platform.sh
detect_platform() {
  case "$(uname -s)" in
    Linux*)  PLATFORM="linux" ;;
    Darwin*) PLATFORM="macos" ;;
    MINGW*|MSYS*|CYGWIN*) PLATFORM="windows" ;;
    *) echo "Unsupported platform"; exit 1 ;;
  esac
}

get_ssh_config_path() {
  case "$PLATFORM" in
    windows) echo "$USERPROFILE/.ssh/config" ;;
    *)       echo "$HOME/.ssh/config" ;;
  esac
}
```

## Anti-Patterns to Avoid

### Anti-Pattern 1: Monolithic Common Module

**What:** Putting all shared functions in a single file (current `common.ps1` pattern).
**Why bad:** 339 lines mixing SSH, Docker, registry, UI, and port management. Makes it hard to understand boundaries, test in isolation, or modify one concern without risking others.
**Instead:** Split into focused modules by domain (core, docker, ssh, ui).

### Anti-Pattern 2: Interactive-Only Interface

**What:** Requiring user interaction for every operation (current menu-only approach).
**Why bad:** Cannot be scripted, automated, or integrated with other tools. Cannot be tested non-interactively.
**Instead:** Subcommand CLI as primary interface, interactive menu as optional mode (`csm` with no args or `csm menu`).

### Anti-Pattern 3: Build Context Key Staging

**What:** Copying SSH keys to a `_build_ssh/` directory in the project root for Docker build context (current pattern).
**Why bad:** Leaves key material in an unexpected location. Build context includes the entire project directory. Race condition if two builds run simultaneously.
**Instead:** Use Docker build `--secret` flag or a dedicated, gitignored build context directory. Better yet, use multi-stage builds where keys are injected only in the final stage.

### Anti-Pattern 4: Hardcoded Container Naming Convention

**What:** Baking naming patterns like `claude-sandbox-$name` throughout the codebase.
**Why bad:** Name collisions with other Docker workloads. Hard to change convention later.
**Instead:** Define naming in one place (`registry.sh`) and always reference through that function.

### Anti-Pattern 5: Password in Dockerfile

**What:** Current Dockerfile has `echo 'claude:claude123' | chpasswd`.
**Why bad:** Password is baked into image layers, visible in `docker history`. SSH is key-only, so the password serves no purpose except `sudo`. Anyone with image access has the password.
**Instead:** Use passwordless sudo for the claude user (`claude ALL=(ALL) NOPASSWD:ALL`), remove the password entirely.

## Scalability Considerations

| Concern | 1-3 instances | 10-20 instances | 50+ instances |
|---------|---------------|-----------------|---------------|
| Port management | Sequential scan fine | Need port range config to avoid collisions | Consider port range allocation per project |
| SSH config | Individual blocks fine | Config file gets long but manageable | Consider Include directive for sandbox-specific config |
| Image builds | Rebuild each time OK | Shared base image with layer caching critical | Pre-built base images pushed to local registry |
| Backup storage | Local directory fine | Need cleanup/rotation policy | Need external storage or pruning strategy |
| Instance registry | Single JSON file fine | Single JSON file fine | Consider SQLite or split files per instance |

For this project's target audience (individual developers, likely 1-5 instances), the single JSON file and sequential port scan are perfectly adequate. Do not over-engineer for scale that will not materialize.

## Suggested Build Order (Dependencies)

The architecture has clear dependency layers that dictate build order:

```
Phase 1: Foundation (no dependencies)
  - lib/core/platform.sh    (OS detection -- everything else needs this)
  - lib/core/config.sh      (settings management -- most operations need defaults)
  - lib/core/registry.sh    (instance state -- all commands need this)
  - lib/ui/output.sh        (colored output -- all user-facing commands need this)
  - bin/csm                  (entry point with subcommand dispatch)

Phase 2: Container Engine (depends on Phase 1)
  - dockerfiles/minimal.Dockerfile  (first container type)
  - lib/docker/images.sh     (image building)
  - lib/docker/containers.sh (container lifecycle)
  - lib/ssh/keys.sh          (keypair management)
  - lib/ssh/config.sh        (SSH config blocks)
  - Commands: create, start, stop, rm, list, ssh

Phase 3: Data Safety (depends on Phase 2)
  - lib/docker/backup.sh     (export/import)
  - Commands: backup, restore
  - Auto-backup on startup hook

Phase 4: Extended Container Types (depends on Phase 2)
  - dockerfiles/gui.Dockerfile  (desktop + browser container)
  - GUI-specific startup scripts (VNC/noVNC)
  - Container type selection in create command

Phase 5: Integration Layer (depends on Phase 2)
  - Docker Desktop MCP Toolkit configuration
  - Claude Code remote control setup hooks
  - GitHub CLI authentication passthrough

Phase 6: Settings & Polish (depends on all above)
  - Commands: settings (interactive menu)
  - Package selection per container type
  - Migration from old .bat structure
  - Security audit + hardening
```

**Rationale for this ordering:**
- Platform detection and config must exist before anything else runs
- Container lifecycle is the core value -- get it working first
- Backups are critical but depend on working containers
- GUI containers are a variant of working containers -- not needed for MVP
- MCP/remote control are integration features layered on top
- Settings management spans all features, easier to build once features are stable

## Windows Compatibility Strategy

The existing Windows users need a migration path. Recommended approach:

1. **Keep `.bat` wrappers** as thin shims that call the bash scripts via Git Bash
2. **Detect Git Bash** at startup: `which bash` or check for `C:\Program Files\Git\bin\bash.exe`
3. **Fall back to WSL** if Git Bash unavailable
4. **Document requirement**: Git for Windows (which most developers already have) or WSL

```batch
@echo off
REM claude-manager.bat (backward-compatible wrapper)
where bash >nul 2>nul
if %ERRORLEVEL% EQU 0 (
    bash "%~dp0bin/csm" %*
) else if exist "C:\Program Files\Git\bin\bash.exe" (
    "C:\Program Files\Git\bin\bash.exe" "%~dp0bin/csm" %*
) else (
    echo ERROR: bash not found. Install Git for Windows or WSL.
    pause
    exit /b 1
)
```

## Sources

- Existing codebase analysis (primary source for as-is architecture)
- [Docker SDK Documentation](https://docs.docker.com/reference/api/engine/sdk/) -- container management patterns
- [Docker MCP Toolkit](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/) -- MCP integration architecture
- [devcontainers/cli](https://github.com/devcontainers/cli) -- reference architecture for container management CLIs
- [Claude Code Development Containers](https://code.claude.com/docs/en/devcontainer) -- Claude Code container integration
- [Node.js CLI Apps Best Practices](https://github.com/lirantal/nodejs-cli-apps-best-practices) -- CLI design patterns (applied to Bash equivalent)
- [Claude Code Remote Control Guide](https://www.digitalapplied.com/blog/claude-code-remote-control-feature-guide/) -- remote control integration requirements
