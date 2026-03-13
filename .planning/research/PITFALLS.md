# Pitfalls Research

**Domain:** Docker-based AI coding sandbox management (cross-platform, GUI containers, backup, security)
**Researched:** 2026-03-13
**Confidence:** HIGH (verified against official docs, CVE databases, and existing codebase analysis)

## Critical Pitfalls

### Pitfall 1: Hardcoded Password in Dockerfile Becomes a Shared Secret

**What goes wrong:**
The current Dockerfile contains `echo 'claude:claude123' | chpasswd` -- a hardcoded password baked into every image layer. Even though SSH password auth is disabled, this password grants `sudo` access inside the container. Anyone who pulls the image or inspects its layers can see it. If password auth is ever accidentally re-enabled (e.g., a config change, a different SSH daemon, or `su` from another process), the container is trivially compromised.

**Why it happens:**
During initial prototyping, a password is the quickest way to create a user with sudo. It works, so it never gets revisited.

**How to avoid:**
- Use `NOPASSWD` sudo for the claude user instead: `echo 'claude ALL=(ALL) NOPASSWD:ALL' >> /etc/sudoers.d/claude`
- Lock the password entirely: `passwd -l claude`
- Never embed secrets in Dockerfiles -- they persist in image layers even if "deleted" in later layers

**Warning signs:**
- `chpasswd` or plaintext passwords anywhere in a Dockerfile
- Grep the Dockerfile for common password patterns during security audit phase

**Phase to address:**
Security hardening phase. This is a quick fix that should be among the first changes.

---

### Pitfall 2: docker export Loses Volume Data -- Backup Creates False Sense of Security

**What goes wrong:**
The project plans to use `docker export` for backups, and the current backup script uses `docker commit` + `docker save`. Both approaches have the same critical flaw: **mounted volume data is not included**. The workspace is bind-mounted at `/home/claude/workspace`, which means the most important data (user's actual code) is excluded from the container export/commit. The current script does back up the workspace separately via zip, but `docker export` alone would silently lose it.

**Why it happens:**
Docker's export/commit commands operate on the container's writable layer, not on volumes or bind mounts. This is documented but easy to miss. The name "export" implies "everything."

**How to avoid:**
- Keep the current approach of backing up workspace files separately (the existing script does this correctly)
- If switching to `docker export`, explicitly document that it does NOT capture bind-mounted workspace data
- Back up container config (ports, env vars, mount points) via `docker inspect` -- export strips this metadata
- Test restore end-to-end: create backup, destroy container, restore, verify workspace files are present

**Warning signs:**
- Backup files that are suspiciously small (container export without workspace is tiny)
- Restore tests that skip workspace verification
- Documentation that says "full backup" without mentioning volumes

**Phase to address:**
Backup system phase. Design the backup architecture with this limitation as a first-class concern.

---

### Pitfall 3: UID/GID Mismatch Breaks Bind Mounts Cross-Platform

**What goes wrong:**
On Linux, Docker bind mounts use the host kernel directly -- file ownership inside the container maps to real UIDs on the host. If the container's `claude` user has UID 1000 but the host user has UID 1001, files created in the container appear owned by a different user on the host (and vice versa), causing permission denied errors. On macOS, Docker Desktop runs in a VM with a translation layer that masks this problem. On Windows/WSL2, yet another permission model applies. Result: works on Mac, breaks on Linux, confuses on Windows.

**Why it happens:**
macOS Docker Desktop abstracts away the permission model, so developers on Mac never encounter it. The issue only surfaces when the same tool runs on Linux (which is the project's primary target).

**How to avoid:**
- Match the container user's UID/GID to a configurable value (default 1000, allow override via build arg)
- Use an entrypoint script that detects the host UID of the mounted workspace directory and adjusts the container user's UID at runtime with `usermod`
- Document this behavior explicitly for Linux users
- Test on all three platforms as part of the cross-platform phase

**Warning signs:**
- "Permission denied" errors when Claude Code tries to write to `/home/claude/workspace`
- Files in the workspace owned by `root` or numeric UIDs instead of the expected user
- Works on one developer's machine but not another's

**Phase to address:**
Cross-platform / Linux-first phase. Must be solved before the tool can reliably run on Linux.

---

### Pitfall 4: GUI Container Shared Memory Default Crashes Browsers

**What goes wrong:**
Docker allocates only 64MB to `/dev/shm` by default. Modern browsers (Chromium, Firefox) use shared memory extensively for multi-process architecture and rendering. In a GUI container with noVNC + browser, the browser will crash with SIGBUS or simply freeze after modest use. This manifests as "browser keeps crashing" with no obvious error message to the user.

**Why it happens:**
The default 64MB was set for server workloads that rarely use shared memory. GUI desktop containers with browsers are an unusual use case that Docker's defaults don't accommodate.

**How to avoid:**
- Always pass `--shm-size=512m` (minimum) or `--shm-size=2g` (recommended for heavy browser use) when running GUI containers
- Make this a non-configurable default in the container manager -- users should never have to discover this themselves
- Add a health check that monitors `/dev/shm` usage and warns before crashes

**Warning signs:**
- Browser tabs crashing inside the container with no error message
- SIGBUS in container logs
- Container works fine for simple tasks but crashes during web app testing

**Phase to address:**
GUI container variant phase. Must be set in the `docker run` command template from the start.

---

### Pitfall 5: Container Escape via Outdated Docker/runC -- AI Agents Amplify the Risk

**What goes wrong:**
In 2025, critical runC vulnerabilities (CVE-2025-31133, CVE-2025-52565, CVE-2025-52881) and a Docker API vulnerability (CVE-2025-9074, CVSS 9.3) enabled container escapes. AI coding agents are uniquely dangerous here: they generate and execute code at runtime based on potentially untrusted inputs (user prompts, repository contents). A compromised LLM output or prompt injection can attempt container escape if the sandbox is the only isolation boundary.

**Why it happens:**
Docker containers share the host kernel. Unlike VMs, they rely on Linux namespaces and cgroups -- which have a history of bypass vulnerabilities. AI agents increase the attack surface because they execute arbitrary code by design.

**How to avoid:**
- Drop all capabilities and add back only what's needed: `--cap-drop=ALL --cap-add=...`
- Use `--security-opt=no-new-privileges` to prevent privilege escalation
- Run containers with a non-root user (already partially done)
- Set filesystem to read-only where possible: `--read-only` with tmpfs for `/tmp`
- Consider `--network=none` for containers that don't need network access
- Document that Docker containers are NOT a security boundary against determined attackers -- they're a convenience boundary
- Add prominent README disclaimer about the security model

**Warning signs:**
- Running containers with `--privileged` flag
- Containers running as root
- Docker/runC not updated to latest patch level
- No capability dropping in docker run commands

**Phase to address:**
Security audit phase. Implement defense-in-depth but be honest in documentation that containers are not equivalent to VMs for isolation.

---

### Pitfall 6: Cross-Platform Script Portability -- GNU vs BSD vs PowerShell

**What goes wrong:**
The project currently uses PowerShell scripts (Windows-only). Moving to cross-platform means choosing between bash scripts (Linux/macOS) and maintaining PowerShell (Windows), or finding a unified approach. Bash itself is not portable between Linux (GNU coreutils) and macOS (BSD coreutils) -- `sed`, `grep`, `readlink`, `date`, `mktemp` all behave differently. macOS ships with bash 3.2 (GPLv2, from 2007) while Linux has bash 5.x. Even `echo -e` behaves differently.

**Why it happens:**
Developers write scripts on one platform and assume they work everywhere. macOS's ancient bash and BSD tools are the usual source of breakage.

**How to avoid:**
- Use `#!/usr/bin/env bash` shebang, never `#!/bin/bash`
- Target POSIX where possible; avoid bash 4+ features (associative arrays, `${var,,}`) unless macOS support is dropped
- Use `printf` instead of `echo -e`
- For `sed`, always use `sed -i ''` on macOS vs `sed -i` on Linux (or use a wrapper function)
- Consider a scripting approach that avoids platform-specific utilities: Python, Node.js, or a compiled CLI tool
- Run ShellCheck on all bash scripts in CI
- Test on both GNU and BSD environments

**Warning signs:**
- Scripts that work on Linux but produce errors like "invalid option" or "illegal byte sequence" on macOS
- Using bash 4+ features without checking `$BASH_VERSION`
- Hardcoded paths like `/usr/bin/grep`

**Phase to address:**
Cross-platform phase (the very first phase). The scripting language decision affects everything downstream.

---

## Technical Debt Patterns

| Shortcut | Immediate Benefit | Long-term Cost | When Acceptable |
|----------|-------------------|----------------|-----------------|
| Single Dockerfile for CLI and GUI variants | Simpler to maintain one file | GUI image is 2-5GB with desktop packages; CLI users download all of it | Never -- use separate Dockerfiles or multi-stage builds from day one |
| `--restart unless-stopped` on all containers | Containers survive host reboot | Zombie containers accumulate silently, consuming resources; user doesn't realize 5 old containers are running | Only for explicitly "always-on" instances; default should be `no` |
| Storing instance state in a JSON file on disk | No database dependency | File corruption on concurrent access, no locking, lost on accidental delete | Acceptable for MVP if file locking is added |
| SSH as the only container access method | Simple, well-understood | Requires SSH key management, port allocation, SSH config manipulation; breaks if SSH daemon crashes inside container | Acceptable for MVP, but add `docker exec` fallback |
| `--no-cache` on every rebuild | Guarantees fresh builds | Rebuilds take 5-10 minutes instead of seconds; terrible UX for non-Docker-experts | Never as default -- only as explicit "clean rebuild" option |

## Integration Gotchas

| Integration | Common Mistake | Correct Approach |
|-------------|----------------|------------------|
| Docker Desktop MCP Toolkit | Assuming it works on Docker Engine (Linux without Desktop) | MCP Gateway must be installed separately on Linux Docker Engine; detect environment and guide user to correct setup |
| Claude Code native installer | Assuming the installer URL/method is stable across versions | Pin to a specific installer version or use the official Docker image as base; have a fallback to NPM install |
| SSH config manipulation | Overwriting user's existing SSH config entries | Parse and surgically replace only managed blocks (current code does this, but the regex matching is fragile with Windows line endings -- already hit this bug) |
| GitHub CLI auth in container | Passing `GITHUB_TOKEN` as build arg (visible in image layers) | Mount token file at runtime or pass as Docker secret; never bake tokens into images |
| Claude Code remote control | Hardcoding the remote control API endpoint/protocol | The remote control feature is new and its API may change; abstract the integration behind a version-checked wrapper |

## Performance Traps

| Trap | Symptoms | Prevention | When It Breaks |
|------|----------|------------|----------------|
| GUI container image size (2-5GB with desktop + browser + Node.js) | Slow first-time setup, disk space complaints | Multi-stage build; offer "download in background" UX; compress layers | Immediately for users on slow connections or limited disk |
| Bind mount performance on macOS | Slow file I/O in container, sluggish builds | Use `:cached` or `:delegated` mount flags; consider using Docker volumes instead of bind mounts for build artifacts | With projects containing >10K files (node_modules) |
| Container accumulation without cleanup | Docker disk usage grows unbounded; `docker system df` shows gigabytes of dead containers/images | Auto-prune old backup images after configurable retention; warn user about disk usage | After 5-10 rebuild cycles |
| Backup compression of large workspaces | Backup takes minutes, blocks user workflow | Run backup async; show progress; skip `node_modules` and `.git` objects by default | Workspaces >1GB |

## Security Mistakes

| Mistake | Risk | Prevention |
|---------|------|------------|
| Running container as root (or allowing easy `sudo` to root) | Root in container can exploit kernel vulnerabilities to escape to host | Run as non-root user; if sudo needed, limit to specific commands |
| Exposing SSH port on 0.0.0.0 instead of 127.0.0.1 | Any machine on the network can attempt SSH into the container | Bind to localhost only: `-p 127.0.0.1:2222:22`; current code does NOT do this |
| Mounting Docker socket (`/var/run/docker.sock`) into containers | Container gains full control over Docker daemon -- equivalent to root on host | Never mount Docker socket; use Docker Desktop MCP Toolkit for Docker access |
| Not setting resource limits (CPU, memory) | A runaway AI agent can consume all host resources, freezing the machine | Set `--memory` and `--cpus` limits; provide sane defaults |
| API keys/tokens in environment variables visible via `docker inspect` | Anyone with Docker access can see all secrets | Use Docker secrets or file-based mounts; never pass API keys as `-e` flags |
| noVNC exposed without authentication | Anyone on the network can view/control the GUI desktop | Bind noVNC to localhost only; add VNC password; consider SSH tunnel for remote access |

## UX Pitfalls

| Pitfall | User Impact | Better Approach |
|---------|-------------|-----------------|
| Requiring Docker knowledge to troubleshoot failures | Users see cryptic Docker errors and give up | Wrap all Docker commands; translate errors to plain English ("Container failed to start -- is Docker Desktop running?") |
| Silent failures during container build | User waits 5 minutes then sees a wall of error text | Stream build output with clear phase indicators; highlight the actual error line |
| Port conflicts with no explanation | "Port 2222 already in use" means nothing to non-Docker users | Detect conflicts, explain what's using the port, auto-suggest alternatives (current code partially does this) |
| No feedback during long operations (backup, build) | User thinks the tool is frozen | Progress indicators or at minimum a spinner; estimated time for known-duration operations |
| Destroying container state on rebuild without warning | User loses installed packages, customizations, running processes | Prompt before destructive operations; offer backup first; distinguish "restart" from "rebuild from scratch" |
| SSH key management complexity | Users don't understand why they need SSH keys or what `known_hosts` warnings mean | Abstract SSH entirely behind the manager; auto-accept host keys for localhost containers (current code does this with `StrictHostKeyChecking no`) |

## "Looks Done But Isn't" Checklist

- [ ] **Cross-platform scripts:** Work on Linux + macOS + Windows -- tested on macOS with BSD coreutils, not just Linux
- [ ] **Backup/restore:** Restore actually produces a working container with workspace data, not just an image that starts
- [ ] **GUI container:** Browser doesn't crash after 10 minutes of use (shared memory issue)
- [ ] **SSH connectivity:** Works when user has existing SSH config with conflicting Host entries
- [ ] **Port management:** Handles the case where a container's port is stolen by another process between sessions
- [ ] **Container cleanup:** Old containers/images are cleaned up or user is warned about disk usage
- [ ] **Docker not installed:** Gives a clear "install Docker first" message, not a cryptic "docker: command not found"
- [ ] **First-time setup:** Works on a completely fresh machine with only Docker installed
- [ ] **Network-dependent steps:** Gracefully handle offline scenarios (cached images, skip update checks)
- [ ] **Claude Code auth:** User is guided through API key setup inside the container, not left to figure it out

## Recovery Strategies

| Pitfall | Recovery Cost | Recovery Steps |
|---------|---------------|----------------|
| Backup missing volume data | HIGH | No recovery if original container is gone; re-create from scratch. Prevention is the only option. |
| UID/GID mismatch corrupted file permissions | MEDIUM | `chown -R` the workspace directory to correct ownership; fix the entrypoint script to prevent recurrence |
| Browser crash from low shm | LOW | Stop container, restart with `--shm-size=2g`; no data loss |
| SSH config corrupted | LOW | Remove managed blocks from `~/.ssh/config`; re-run the manager to regenerate |
| Container escape / security breach | HIGH | Cannot recover trust in the host system; audit, patch Docker/runC, rotate all credentials that were on the host |
| Image bloat filling disk | MEDIUM | `docker system prune -a` to reclaim space; implement retention policy going forward |
| Port conflict on startup | LOW | Manager detects and reassigns; existing code handles this |

## Pitfall-to-Phase Mapping

| Pitfall | Prevention Phase | Verification |
|---------|------------------|--------------|
| Hardcoded password | Security hardening | `grep -r 'chpasswd\|password' Dockerfile` returns nothing |
| Backup loses volumes | Backup system design | End-to-end restore test produces working container WITH workspace files |
| UID/GID mismatch | Cross-platform (Linux first) | Create file on host, verify ownership in container; create in container, verify on host |
| Shared memory crash | GUI container variant | Run browser for 30 minutes in GUI container without crash |
| Container escape risk | Security audit | Containers run with dropped capabilities, non-root, no-new-privileges; documented risk model |
| Script portability | Cross-platform (first phase) | CI runs scripts on Linux and macOS; ShellCheck passes |
| SSH port exposure | Security hardening | `docker port` shows 127.0.0.1 binding, not 0.0.0.0 |
| Image bloat | Container variants (CLI/GUI split) | CLI image <500MB, GUI image <2GB |
| Docker socket mounting | Security audit | No container has access to Docker socket |
| Resource limits | Security hardening | All containers have memory and CPU limits set |

## Sources

- [OWASP Docker Security Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Docker_Security_Cheat_Sheet.html)
- [Docker export documentation](https://docs.docker.com/reference/cli/docker/container/export/) -- confirms volumes excluded
- [Docker bind mount permissions guide](https://eastondev.com/blog/en/posts/dev/20251217-docker-mount-permissions-guide/)
- [Container escape vulnerabilities for AI agents (2026)](https://blaxel.ai/blog/container-escape)
- [Docker in 2026: common container mistakes](https://app.daily.dev/posts/docker-in-2026-the-5-mistakes-still-killing-your-containers-in-production-smjgbcw2q)
- [Docker shared memory configuration](https://last9.io/blog/how-to-configure-dockers-shared-memory-size-dev-shm/)
- [Cross-platform shell scripting differences](https://tech-champion.com/programming/write-cross-platform-shell-linux-vs-macos-differences-that-break-production/)
- [macOS vs Linux scripting](https://dev.to/aghost7/differences-between-macos-and-linux-scripting-74d)
- [Why Docker sandboxes alone don't make AI agents safe](https://www.arcade.dev/blog/docker-sandboxes-arent-enough-for-agent-safety)
- [Docker Desktop MCP Toolkit docs](https://docs.docker.com/ai/mcp-catalog-and-toolkit/toolkit/)
- [Docker secrets management](https://docs.docker.com/engine/swarm/secrets/)
- [GitGuardian Docker security cheat sheet](https://blog.gitguardian.com/how-to-improve-your-docker-containers-security-cheat-sheet/)
- [Running GUI apps in Docker with VNC](https://www.codegenes.net/blog/can-you-run-gui-applications-in-a-linux-docker-container/)
- [Docker backup best practices](https://collabnix.com/the-importance-of-docker-container-backups-best-practices-and-strategies/)
- Existing codebase analysis: `scripts/Dockerfile`, `scripts/common.ps1`, `scripts/backup-claude.ps1`

---
*Pitfalls research for: Docker-based AI coding sandbox management*
*Researched: 2026-03-13*
