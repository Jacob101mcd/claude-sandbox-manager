# Phase 1: Foundation + Security - Research

**Researched:** 2026-03-13
**Domain:** Bash CLI tooling, Docker security hardening, cross-platform container management
**Confidence:** HIGH

## Summary

Phase 1 transforms a Windows-only PowerShell sandbox manager into a cross-platform tool by writing a new Bash entry point for Linux (and later macOS), while hardening the existing Dockerfile and fixing orphaned container bugs. The existing codebase is small (~450 lines of PowerShell across two files plus a 48-line Dockerfile), well-structured, and provides a clear reference implementation. The Bash rewrite is a clean reimplementation using Bash idioms, not a line-by-line port.

The security surface is well-defined: remove the hardcoded password (`claude:claude123`), bind SSH to localhost only, drop unnecessary Docker capabilities, add resource limits, and add `--no-new-privileges`. The orphan container detection is straightforward using `docker ps -a --filter` against the naming convention `claude-sandbox-*`.

**Primary recommendation:** Structure the Bash codebase as `bin/csm` sourcing `lib/*.sh` modules, use `jq` for all JSON operations on `.instances.json`, and apply a "drop all, add back minimum" approach to Docker capabilities.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- Bash for Linux/macOS -- clean rewrite, not a line-by-line port of the PowerShell
- Bash 4+ features allowed (arrays, associative arrays, [[ ]], etc.)
- Windows keeps existing PowerShell scripts as-is -- two separate codebases sharing the same Dockerfile
- jq is a required dependency for JSON parsing
- Single entry point (`csm`) that sources `lib/*.sh` modules (docker.sh, ssh.sh, instances.sh, etc.)
- Layout: `bin/csm` (entry point), `lib/*.sh` (modules) at project root
- Windows scripts remain in `scripts/` directory
- Instance state continues using `.instances.json` (parsed with jq)
- Command name: `csm`
- Interactive menu mode (like current Windows manager) -- shows instance list and action menu in a loop
- Run from project directory only -- no global install step
- After starting an instance, prompt user: "SSH into instance now? (y/N)"
- Hardcoded password removed -- passwordless sudo for claude user (NOPASSWD)
- SSH bound to localhost only: `-p 127.0.0.1:${port}:22`
- Docker capabilities: drop only unused ones (MKNOD, AUDIT_WRITE, SETFCAP, SETPCAP, NET_BIND_SERVICE, SYS_CHROOT, FSETID) -- keep all others for sudo/apt/debugging compatibility
- Resource limits: 2GB RAM (`--memory=2g`), 2 CPUs (`--cpus=2`) as defaults
- `--no-new-privileges` flag added to container run

### Claude's Discretion
- Exact lib/*.sh module breakdown and naming
- Error message wording and color scheme
- How to detect and display orphaned containers (BUG-01, BUG-02)
- Dockerfile optimization (layer ordering, cleanup)
- SSH key management approach for Linux (adapt from PowerShell logic)

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| PLAT-01 | Manager scripts run natively on Linux without modification | Bash 4+ clean rewrite with `bin/csm` entry point and `lib/*.sh` modules |
| PLAT-02 | Manager scripts run natively on macOS without modification | Bash 4+ is available on macOS (pre-installed 3.2, but Homebrew provides 5.x); use portable constructs where possible, flag macOS-specific paths |
| PLAT-03 | Existing Windows support maintained alongside Linux/macOS | Windows PowerShell scripts remain untouched in `scripts/`; shared Dockerfile |
| PLAT-04 | Platform-specific differences detected and handled automatically | Use `uname -s` for OS detection; handle path differences (home dir, ssh config location, Docker socket) |
| QUAL-01 | Codebase restructured with clear separation of concerns | Modular `lib/*.sh` pattern with namespaced functions (e.g., `docker_build`, `ssh_generate_keys`) |
| QUAL-02 | Code follows Docker best practices | Multi-stage not needed yet (single stage is fine for this image); minimize layers, clean apt cache, no root runtime |
| QUAL-03 | Code follows Claude Code best practices for sandbox environments | SSH key-only auth, workspace volume mount, proper user isolation |
| QUAL-04 | Consistent coding style and naming conventions | ShellCheck compliance, snake_case functions, consistent quoting, `set -euo pipefail` |
| SEC-01 | Hardcoded passwords removed from Dockerfiles | Replace `echo 'claude:claude123' \| chpasswd` with NOPASSWD sudoers entry |
| SEC-02 | SSH bound to localhost only | `-p 127.0.0.1:${port}:22` in docker run command |
| SEC-03 | Docker capabilities dropped to minimum required set | Drop: MKNOD, AUDIT_WRITE, SETFCAP, SETPCAP, NET_BIND_SERVICE, SYS_CHROOT, FSETID |
| SEC-04 | Resource limits set on containers | `--memory=2g --cpus=2 --no-new-privileges` |
| BUG-01 | Rebuilt containers no longer pile up as orphaned instances | Stop and remove existing container before creating new one (already done in PS; replicate in Bash) |
| BUG-02 | Manager detects and displays all existing container instances | Cross-reference `.instances.json` with `docker ps -a --filter name=claude-sandbox-` to find orphans |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| Bash | 4.0+ | Script runtime | Pre-installed on all Linux distros; 4+ required for associative arrays and `[[ ]]` |
| jq | 1.6+ | JSON parsing | The standard CLI JSON processor; zero runtime dependencies, portable C binary |
| Docker CLI | 20.10+ | Container management | Direct Docker CLI calls (no Compose for instance management) |
| ssh-keygen | OpenSSH 8+ | SSH key generation | Pre-installed on Linux; ed25519 key type |
| ShellCheck | 0.9+ | Bash linting | Industry-standard static analysis for shell scripts |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| `uname` | OS/platform detection | Entry point initialization to set platform-specific paths |
| `tput` / ANSI codes | Terminal colors | Menu display and status output |
| `ss` or `lsof` | Port availability check | Finding next free port (replaces PowerShell TcpListener) |
| `docker inspect` | Container state queries | Getting container status, detecting orphans |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| jq | Python JSON | jq is lighter, no Python dependency, but less capable for complex transforms |
| Bash | POSIX sh | Bash 4+ gives arrays and associative arrays; POSIX sh is more portable but far more verbose |
| `ss` for port check | `nc -z` | `ss` is more reliable; `nc` behavior varies across distros |

**Installation (user dependencies):**
```bash
# Debian/Ubuntu
sudo apt-get install -y jq docker.io openssh-client

# macOS (Homebrew)
brew install jq bash  # macOS ships Bash 3.2; need 4+ from Homebrew
```

## Architecture Patterns

### Recommended Project Structure
```
bin/
  csm                    # Entry point script (chmod +x)
lib/
  common.sh              # Shared constants, color output, error handling
  platform.sh            # OS detection, platform-specific paths
  docker.sh              # Docker build, run, stop, remove operations
  ssh.sh                 # SSH key generation, config writing
  instances.sh           # Instance registry (CRUD on .instances.json via jq)
  menu.sh                # Interactive menu loop and display
scripts/
  Dockerfile             # Shared container definition (used by both Bash and PS)
  claude-manager.ps1     # Windows PowerShell manager (unchanged)
  common.ps1             # Windows shared functions (unchanged)
  backup-claude.ps1      # Windows backup (unchanged)
  restore-claude.ps1     # Windows restore (unchanged)
  rebuild-claude.ps1     # Windows rebuild (unchanged)
  ssh-claude.ps1         # Windows SSH (unchanged)
```

### Pattern 1: Entry Point with Library Sourcing
**What:** Single `bin/csm` script that sources all `lib/*.sh` modules
**When to use:** Always -- this is the only entry point for Linux/macOS

```bash
#!/usr/bin/env bash
set -euo pipefail

# Resolve project root (parent of bin/)
CSM_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Source all library modules
for lib in "$CSM_ROOT"/lib/*.sh; do
    # shellcheck source=/dev/null
    source "$lib"
done

# Initialize platform detection
platform_detect

# Run main menu
main_menu
```

### Pattern 2: Namespaced Functions
**What:** Prefix functions with their module name to avoid collisions
**When to use:** All functions in lib/*.sh modules

```bash
# lib/instances.sh
instances_get_all() {
    local file="$CSM_ROOT/.instances.json"
    if [[ -f "$file" ]]; then
        jq '.' "$file"
    else
        echo '{}'
    fi
}

instances_register() {
    local name="$1"
    local port
    port=$(instances_next_free_port)
    local file="$CSM_ROOT/.instances.json"
    local current
    current=$(instances_get_all)
    echo "$current" | jq --arg name "$name" --argjson port "$port" \
        '. + {($name): {port: $port}}' > "$file"
    echo "$port"
}
```

### Pattern 3: Platform Detection
**What:** Detect OS at startup, set platform-specific variables
**When to use:** Entry point initialization

```bash
# lib/platform.sh
platform_detect() {
    case "$(uname -s)" in
        Linux)  CSM_PLATFORM="linux" ;;
        Darwin) CSM_PLATFORM="macos" ;;
        *)      die "Unsupported platform: $(uname -s)" ;;
    esac

    # Platform-specific paths
    case "$CSM_PLATFORM" in
        linux)
            CSM_SSH_DIR="$HOME/.ssh"
            ;;
        macos)
            CSM_SSH_DIR="$HOME/.ssh"
            ;;
    esac
}
```

### Pattern 4: Orphaned Container Detection
**What:** Cross-reference Docker state with instance registry to find orphans
**When to use:** Instance list display, cleanup operations

```bash
# lib/instances.sh
instances_detect_orphans() {
    local registered_containers=()
    local name
    # Get registered container names from .instances.json
    while IFS= read -r name; do
        registered_containers+=("claude-sandbox-$name")
    done < <(instances_get_all | jq -r 'keys[]')

    # Get all Docker containers matching our naming pattern
    local docker_containers
    docker_containers=$(docker ps -a --filter "name=claude-sandbox-" --format '{{.Names}}')

    # Find containers in Docker but not in registry
    local container
    while IFS= read -r container; do
        [[ -z "$container" ]] && continue
        local found=false
        for reg in "${registered_containers[@]}"; do
            if [[ "$container" == "$reg" ]]; then
                found=true
                break
            fi
        done
        if [[ "$found" == "false" ]]; then
            echo "$container"  # This is an orphan
        fi
    done <<< "$docker_containers"
}
```

### Anti-Patterns to Avoid
- **Parsing JSON with grep/sed/awk:** Always use `jq`. JSON has edge cases (escaping, nesting) that regex cannot handle reliably.
- **Hardcoding paths:** Use `$CSM_ROOT` and platform detection. Never assume `/home/user` or specific directory structures.
- **Using `eval` for dynamic commands:** Build Docker commands with arrays instead: `cmd=(docker run -d); cmd+=(--name "$name"); "${cmd[@]}"`.
- **Unquoted variables:** Always quote `"$variable"` to prevent word splitting. ShellCheck will catch this.
- **Global state mutation:** Use `local` for function variables. Only `CSM_*` prefixed globals for cross-module state.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON parsing | Regex/sed extraction | `jq` | JSON has nested objects, escaped strings, arrays -- regex will break |
| Port availability check | Custom TCP socket code | `ss -tln \| grep :$port` or `docker port` | OS-level tools are authoritative |
| SSH key generation | Manual key file creation | `ssh-keygen -t ed25519 -N "" -f "$path"` | Cryptographic correctness |
| Color output | Raw ANSI escapes everywhere | Helper function wrapping `tput` or standardized ANSI codes | Consistency, terminal compatibility |
| Dockerfile linting | Manual review | `hadolint` (optional, for CI) | Catches common Dockerfile mistakes |

**Key insight:** This project's complexity is in orchestration (coordinating Docker, SSH, and state), not in any single operation. Use standard tools for each operation and focus the code on gluing them together correctly.

## Common Pitfalls

### Pitfall 1: Bash Word Splitting on Filenames/Paths
**What goes wrong:** Unquoted variables containing spaces or special characters break commands.
**Why it happens:** Bash splits unquoted variables on whitespace by default.
**How to avoid:** Quote every variable expansion: `"$var"`. Use ShellCheck (SC2086).
**Warning signs:** Commands fail only when paths contain spaces.

### Pitfall 2: jq Atomic File Writes
**What goes wrong:** Writing jq output directly to the same input file truncates it.
**Why it happens:** Shell redirects (`>`) truncate the file before jq reads it.
**How to avoid:** Write to a temp file, then `mv`: `jq '...' "$file" > "$file.tmp" && mv "$file.tmp" "$file"`.
**Warning signs:** `.instances.json` becomes empty after updates.

### Pitfall 3: Docker Container Name Conflicts
**What goes wrong:** `docker run --name X` fails if container X already exists (even if stopped).
**Why it happens:** Docker keeps stopped containers until explicitly removed.
**How to avoid:** Always `docker rm -f "$container" 2>/dev/null` before `docker run --name "$container"`.
**Warning signs:** "Conflict. The container name is already in use" errors.

### Pitfall 4: SSH Key Permissions
**What goes wrong:** SSH refuses to use keys with too-open permissions.
**Why it happens:** OpenSSH requires private keys to be mode 600 and `.ssh/` to be mode 700.
**How to avoid:** `chmod 600 "$key"` and `chmod 700 "$ssh_dir"` immediately after creation.
**Warning signs:** "WARNING: UNPROTECTED PRIVATE KEY FILE!" errors.

### Pitfall 5: Docker Build Context Size
**What goes wrong:** `docker build` takes forever or runs out of memory.
**Why it happens:** Build context includes workspaces, backups, and other large directories.
**How to avoid:** Use `.dockerignore` to exclude `workspaces/`, `backups/`, `ssh/`, `.git/`, etc.
**Warning signs:** Slow builds, "sending build context" step takes minutes.

### Pitfall 6: `set -e` with Intentional Failures
**What goes wrong:** Script exits when `docker stop` or `docker rm` fails on non-existent containers.
**Why it happens:** `set -e` exits on any non-zero exit code.
**How to avoid:** Use `|| true` for commands that are expected to fail: `docker stop "$name" 2>/dev/null || true`.
**Warning signs:** Script exits unexpectedly during cleanup operations.

### Pitfall 7: macOS Bash 3.2 Incompatibility
**What goes wrong:** Associative arrays, `readarray`, `mapfile`, and other Bash 4+ features fail.
**Why it happens:** macOS ships Bash 3.2 (2007) due to GPL v3 licensing.
**How to avoid:** Phase 1 targets Linux only. For future macOS support (Phase 1 prep): document that Homebrew Bash 4+ is required, detect version at startup.
**Warning signs:** "declare: -A: invalid option" on macOS.

## Code Examples

### Docker Run with Security Hardening
```bash
# Source: CONTEXT.md locked decisions + Docker security best practices
docker_run_instance() {
    local name="$1"
    local port="$2"
    local container_name="claude-sandbox-${name}"
    local image_name="claude-sandbox-${name}"
    local workspace_dir="$CSM_ROOT/workspaces/${name}"

    # Remove existing container (handles BUG-01)
    docker rm -f "$container_name" 2>/dev/null || true

    docker run -d \
        --name "$container_name" \
        -p "127.0.0.1:${port}:22" \
        -v "${workspace_dir}:/home/claude/workspace" \
        -w /home/claude/workspace \
        --memory=2g \
        --cpus=2 \
        --security-opt=no-new-privileges \
        --cap-drop=MKNOD \
        --cap-drop=AUDIT_WRITE \
        --cap-drop=SETFCAP \
        --cap-drop=SETPCAP \
        --cap-drop=NET_BIND_SERVICE \
        --cap-drop=SYS_CHROOT \
        --cap-drop=FSETID \
        --restart unless-stopped \
        "$image_name"
}
```

### Dockerfile Security Fix (SEC-01)
```dockerfile
# BEFORE (insecure):
# RUN echo 'claude:claude123' | chpasswd

# AFTER (passwordless sudo, no password set):
RUN useradd -m -s /bin/bash claude \
    && usermod -aG sudo claude \
    && echo 'claude ALL=(ALL) NOPASSWD:ALL' > /etc/sudoers.d/claude \
    && chmod 0440 /etc/sudoers.d/claude
```

### SSH Key Generation for Linux
```bash
# Source: ssh-keygen man page, adapted from PowerShell Ensure-SshKeys
ssh_ensure_keys() {
    local name="$1"
    local ssh_dir="$CSM_ROOT/ssh/${name}"

    mkdir -p "$ssh_dir"

    # User keypair
    if [[ ! -f "$ssh_dir/id_claude" ]]; then
        msg_info "Generating SSH user keypair for '${name}'..."
        ssh-keygen -t ed25519 -f "$ssh_dir/id_claude" -N "" -C "claude-sandbox-${name}"
        chmod 600 "$ssh_dir/id_claude"
        msg_ok "SSH user keypair generated."
    fi

    # Host key (baked into image for stable fingerprint)
    if [[ ! -f "$ssh_dir/ssh_host_ed25519_key" ]]; then
        msg_info "Generating SSH host key for '${name}'..."
        ssh-keygen -t ed25519 -f "$ssh_dir/ssh_host_ed25519_key" -N "" -C "claude-sandbox-${name}-host"
        msg_ok "SSH host key generated."
    fi
}
```

### Instance JSON Operations with jq
```bash
# Source: jq documentation (jqlang.org)
instances_add() {
    local name="$1" port="$2"
    local file="$CSM_ROOT/.instances.json"
    [[ -f "$file" ]] || echo '{}' > "$file"
    jq --arg n "$name" --argjson p "$port" '. + {($n): {port: $p}}' "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
}

instances_remove() {
    local name="$1"
    local file="$CSM_ROOT/.instances.json"
    jq --arg n "$name" 'del(.[$n])' "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
}

instances_get_port() {
    local name="$1"
    local file="$CSM_ROOT/.instances.json"
    jq -r --arg n "$name" '.[$n].port // empty' "$file"
}
```

### Port Availability Check (Linux)
```bash
# Source: Linux networking utilities
port_is_available() {
    local port="$1"
    # ss -tln shows listening TCP sockets; grep for the port
    if ss -tln 2>/dev/null | grep -q ":${port} "; then
        return 1  # Port in use
    fi
    return 0  # Port available
}

port_next_free() {
    local port=2222
    while ! port_is_available "$port"; do
        ((port++))
    done
    echo "$port"
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `echo 'user:pass' \| chpasswd` | `NOPASSWD` sudoers entry | Docker security best practices 2023+ | No password to leak, no brute-force surface |
| `-p PORT:22` (all interfaces) | `-p 127.0.0.1:PORT:22` | Always available, increasingly recommended | SSH not exposed to network |
| No capability restrictions | `--cap-drop` unused caps | Docker 1.2+ (2014), widely adopted 2020+ | Reduced attack surface |
| No resource limits | `--memory=2g --cpus=2` | Always available, best practice | Prevents container resource exhaustion |

**Deprecated/outdated:**
- `docker-compose.yml` for single-instance management: The project already moved past this (the existing compose file is for the old single-instance setup). Phase 1 uses direct `docker run` for multi-instance support.
- Password-based SSH: The existing Dockerfile already disables password auth in sshd_config. Phase 1 removes the leftover `chpasswd` call.

## Open Questions

1. **macOS Bash version handling**
   - What we know: macOS ships Bash 3.2; Homebrew provides 5.x. Phase 1 targets Linux only.
   - What's unclear: Whether to add a version check now or defer to later phase.
   - Recommendation: Add a version check in `bin/csm` that warns and exits if Bash < 4. Low effort, prevents confusing errors for early macOS adopters.

2. **`.dockerignore` file**
   - What we know: The build context currently has no `.dockerignore`, which means `workspaces/`, `backups/`, etc. get sent to the Docker daemon.
   - What's unclear: Whether there's an existing `.dockerignore` we haven't seen.
   - Recommendation: Create `.dockerignore` in Phase 1 with: `workspaces/`, `backups/`, `ssh/`, `.git/`, `.planning/`, `_build_ssh/` (build SSH keys are staged separately via COPY).

3. **Shared Dockerfile compatibility**
   - What we know: Both Bash and PowerShell paths use the same Dockerfile. Security changes (removing `chpasswd`) affect both.
   - What's unclear: Whether existing Windows users will be affected by the sudo change.
   - Recommendation: The sudo change is strictly better (removes password, keeps sudo access). No breaking change for Windows users.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | Bash + ShellCheck (linting) + BATS (Bash Automated Testing System) |
| Config file | None -- Wave 0 |
| Quick run command | `shellcheck bin/csm lib/*.sh` |
| Full suite command | `shellcheck bin/csm lib/*.sh && bats tests/` |

### Phase Requirements to Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| PLAT-01 | csm runs on Linux without error | smoke | `bash bin/csm --help` (or similar non-interactive flag) | No -- Wave 0 |
| PLAT-03 | Windows PS scripts unchanged | manual-only | Verify no changes to `scripts/*.ps1` via `git diff` | N/A |
| PLAT-04 | Platform detection works | unit | `bats tests/platform.bats` | No -- Wave 0 |
| QUAL-01 | Modular structure | manual-only | Verify `lib/*.sh` files exist and are sourced | N/A |
| QUAL-04 | ShellCheck passes | lint | `shellcheck bin/csm lib/*.sh` | No -- Wave 0 |
| SEC-01 | No hardcoded password in Dockerfile | unit | `! grep -q 'chpasswd' scripts/Dockerfile` | No -- Wave 0 |
| SEC-02 | SSH bound to localhost | unit | `grep -q '127.0.0.1' lib/docker.sh` | No -- Wave 0 |
| SEC-03 | Capabilities dropped | unit | `grep -q 'cap-drop' lib/docker.sh` | No -- Wave 0 |
| SEC-04 | Resource limits present | unit | `grep -q 'memory' lib/docker.sh` | No -- Wave 0 |
| BUG-01 | Old container removed before new one | unit | `bats tests/docker.bats` | No -- Wave 0 |
| BUG-02 | Orphans detected | unit | `bats tests/instances.bats` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `shellcheck bin/csm lib/*.sh`
- **Per wave merge:** `shellcheck bin/csm lib/*.sh && bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/` directory -- create test infrastructure
- [ ] `tests/platform.bats` -- covers PLAT-01, PLAT-04
- [ ] `tests/instances.bats` -- covers BUG-01, BUG-02
- [ ] `tests/docker.bats` -- covers SEC-01 through SEC-04
- [ ] ShellCheck installation: `sudo apt-get install -y shellcheck`
- [ ] BATS installation: `sudo apt-get install -y bats` or git clone from https://github.com/bats-core/bats-core

## Sources

### Primary (HIGH confidence)
- Existing codebase: `scripts/common.ps1` (339 lines), `scripts/claude-manager.ps1` (115 lines), `scripts/Dockerfile` (48 lines) -- direct reference implementation
- [Docker Docs - Running containers](https://docs.docker.com/engine/containers/run/) -- capability management, port binding
- [Docker Docs - Security](https://docs.docker.com/engine/security/) -- security best practices
- [jq official site](https://jqlang.org/) -- JSON processing patterns
- [ssh-keygen man page](https://man7.org/linux/man-pages/man1/ssh-keygen.1.html) -- key generation flags

### Secondary (MEDIUM confidence)
- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html) -- defense-in-depth recommendations
- [Docker Capabilities Lab](https://dockerlabs.collabnix.com/advanced/security/capabilities/) -- default capabilities list (14 capabilities confirmed)
- [Greg's Wiki BashGuide](https://mywiki.wooledge.org/BashGuide/Practices) -- Bash best practices
- [Docker Capabilities and no-new-privileges](https://raesene.github.io/blog/2019/06/01/docker-capabilities-and-no-new-privs/) -- no-new-privileges explanation

### Tertiary (LOW confidence)
- [Modular Bash patterns (WafaiCloud)](https://wafaicloud.com/blog/crafting-modular-bash-script-libraries-for-enhanced-reusability/) -- library sourcing patterns (well-known practice, low risk)
- [Bash namespace patterns (lost-in-it)](https://www.lost-in-it.com/posts/designing-modular-bash-functions-namespaces-library-patterns/) -- function naming conventions

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- Bash + jq + Docker CLI is the obvious and only reasonable choice for this project
- Architecture: HIGH -- `bin/` + `lib/` sourcing pattern is well-established for Bash projects; existing PS code provides clear reference
- Security hardening: HIGH -- All changes are well-documented Docker best practices with official docs support
- Pitfalls: HIGH -- Common Bash pitfalls are extremely well-documented; Docker pitfalls verified against official docs
- Orphan detection: MEDIUM -- Approach is straightforward but needs testing against real Docker state edge cases

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (stable domain, unlikely to change)
