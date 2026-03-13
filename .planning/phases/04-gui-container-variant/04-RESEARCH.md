# Phase 4: GUI Container Variant - Research

**Researched:** 2026-03-13
**Domain:** Docker multi-stage Dockerfile, TigerVNC, noVNC, Xfce4, Chromium, Bash shell scripting
**Confidence:** HIGH (core stack), MEDIUM (Xfce configuration specifics)

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**noVNC access & ports:**
- Each GUI instance gets two auto-allocated ports: SSH (2222+) and noVNC (6080+)
- Both ports stored in .instances.json per instance
- noVNC bound to localhost only (127.0.0.1:{port}:6080) — no VNC password needed
- After GUI instance starts: print noVNC URL + "Open in browser? (y/N)" prompt
- No SSH prompt for GUI instances — users connect via SSH separately if needed
- URL format: http://localhost:{noVNC_port}

**Desktop experience:**
- Screen resolution: 1920x1080, 24-bit color
- Auto-login as claude user — no login screen
- Session persists when browser tab is closed — VNC server keeps running, reconnect shows same desktop
- Stripped-down Xfce: minimal panel, file manager, terminal emulator, browser — no screensaver, power manager, or unnecessary plugins
- Workspace desktop shortcut: folder icon on desktop pointing to /home/claude/workspace
- Terminal emulator pinned to Xfce panel for quick access
- Chromium pinned to Xfce panel alongside terminal
- noVNC clipboard integration enabled (sidebar panel for copy/paste between host and container)

**Browser inside container:**
- Chromium pre-installed (not Firefox)
- Container-safe launch flags via wrapper script or .desktop file: --no-sandbox, --disable-gpu, --disable-dev-shm-usage
- Homepage set to about:blank (fastest start, no network requests)
- --shm-size=512m on docker run ensures Chromium stability (CONT-05)

**Dockerfile structure:**
- Multi-stage single Dockerfile: `base` (shared), `cli` (extends base), `gui` (extends base with Xfce/VNC/Chromium)
- docker_build() reads instance type from .instances.json and passes --target cli or --target gui
- Image tags are type-suffixed: claude-sandbox-{name}-cli, claude-sandbox-{name}-gui
- Single entrypoint.sh detects variant (checks for VNC binaries or env var) — starts Xvfb + VNC + noVNC before SSH for GUI, just SSH for CLI
- GUI stage installs: xfce4 (core only), tigervnc-standalone-server, novnc, websockify, chromium-browser

### Claude's Discretion
- Exact Xfce panel configuration and theme
- TigerVNC vs other VNC server implementation details
- noVNC version and configuration specifics
- Desktop icon styling and placement
- Xvfb color depth and DPI settings
- How entrypoint detects GUI vs CLI variant
- Chromium wrapper script implementation details
- Port range start for noVNC (6080+ suggested but flexible)

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| CONT-02 | User can build and run a GUI container with desktop environment and browser | Multi-stage Dockerfile (gui target), xfce4 + TigerVNC + noVNC stack, chromium-browser install |
| CONT-04 | GUI container runs Xvfb + noVNC for browser-based desktop access | TigerVNC's Xvnc provides virtual framebuffer + VNC in one; websockify bridges VNC to WebSocket for noVNC |
| CONT-05 | GUI containers start with adequate shared memory (--shm-size=512m minimum) | docker run --shm-size=512m flag added conditionally for GUI type in docker_run_instance() |
</phase_requirements>

---

## Summary

Phase 4 adds a GUI container variant to the existing CLI container. The entire implementation is a surgical extension of existing code: the Dockerfile gets split into a multi-stage build (base/cli/gui), docker.sh gains type-awareness, instances.sh gains vnc_port storage, menu.sh's action_start branches on type, and entrypoint.sh detects and launches VNC services for GUI containers.

The GUI stack is well-proven: TigerVNC (tigervnc-standalone-server) provides Xvnc which combines a virtual X server and VNC server in one process. noVNC is a browser-based VNC client served from /usr/share/novnc/ on Ubuntu 24.04. Websockify (python3-websockify) bridges VNC's TCP protocol to WebSockets so noVNC can connect. All three packages are in Ubuntu 24.04's official apt repositories.

The key insight is that TigerVNC's Xvnc is preferred over Xvfb + separate VNC server because it's a single process, avoids display-sharing complexity, and is the approach used in all well-maintained containerized desktop images. The --SecurityTypes None flag allows passwordless access, which is safe because noVNC is bound to localhost only and this is a single-user local sandbox environment.

**Primary recommendation:** Use TigerVNC Xvnc (not Xvfb + separate VNC) for the virtual display + VNC server, add a minimal xstartup that calls startxfce4, and launch websockify pointing at the VNC port. Reuse all existing security hardening patterns (Bash array for docker run, atomic jq writes, msg_info/msg_ok) for the new GUI-specific code.

---

## Standard Stack

### Core

| Library/Tool | Version (Ubuntu 24.04) | Purpose | Why Standard |
|---|---|---|---|
| tigervnc-standalone-server | 1.13.x (noble) | Xvnc: virtual X server + VNC server in one process | Industry standard for Docker desktop containers; no separate Xvfb needed |
| novnc | 1:1.3.0-2 (noble) | Browser-based VNC client HTML/JS app, served from /usr/share/novnc/ | Enables browser access without VNC client installation; in official Ubuntu repos |
| python3-websockify | 0.10.x (noble) | WebSocket-to-TCP bridge so noVNC can connect to VNC port | Required by noVNC; available in apt as python3-websockify |
| xfce4 | 4.18.x (noble) | Desktop environment — session, panel, window manager, desktop | Lightest full-featured DE; xfce4 package installs core only |
| xfce4-terminal | 1.1.x | Terminal emulator to pin to panel | Standard Xfce terminal, small footprint |
| chromium-browser | latest apt | Browser inside container for web testing | Required by locked decision; ubuntu 24.04 apt package |
| dbus-x11 | system | D-Bus X11 launch helper; prevents "connection refused" errors in xstartup | Required for Xfce session to start cleanly in VNC |

### Supporting

| Library/Tool | Version | Purpose | When to Use |
|---|---|---|---|
| python3-numpy | system | Performance dependency for websockify | Always install alongside python3-websockify |
| thunar | 4.18.x | Xfce file manager for workspace shortcut | Included with xfce4 package; no separate install |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| TigerVNC Xvnc | Xvfb + x11vnc | Two-process approach is more complex; x11vnc is not in Ubuntu 24.04 main repos |
| tigervnc-standalone-server | tightvncserver | TigerVNC is actively maintained; tightvncserver is older |
| apt novnc | git clone noVNC | Apt version is stable and keeps /usr/share/novnc/ convention; git adds build complexity |
| xfce4 (package) | xfce4-goodies or xubuntu-desktop | Core xfce4 is minimal; goodies/xubuntu-desktop add unneeded weight |

### Installation (GUI stage in Dockerfile)

```bash
apt-get install -y \
    xfce4 \
    xfce4-terminal \
    tigervnc-standalone-server \
    novnc \
    python3-websockify \
    python3-numpy \
    dbus-x11 \
    chromium-browser \
    && rm -rf /var/lib/apt/lists/*
```

---

## Architecture Patterns

### Recommended Project Structure Changes

```
scripts/
├── Dockerfile            # Refactor: base → cli, base → gui stages
└── entrypoint.sh         # Extend: detect GUI variant, start Xvnc + noVNC
lib/
├── docker.sh             # Extend: type-aware build target, shm-size, vnc port flag
├── instances.sh          # Extend: vnc_port field, instances_get_vnc_port()
└── menu.sh               # Extend: menu_select_container_type() activates gui,
                          #         menu_action_start() branches on type
tests/
├── dockerfile.bats       # Add: tests for gui stage presence, multi-stage structure
├── docker.bats           # Add: tests for shm-size and vnc port flags
├── instances.bats        # Add: tests for vnc_port storage/retrieval
└── menu.bats             # Add: tests for gui type selection activation
```

### Pattern 1: Multi-Stage Dockerfile (base/cli/gui)

**What:** Single Dockerfile with three named stages. `base` has everything shared. `cli` and `gui` extend `base`. Docker build uses `--target` to select variant.

**When to use:** Whenever a codebase needs multiple related Docker images sharing a common foundation.

**Example:**
```dockerfile
# Source: Docker official multi-stage docs
FROM ubuntu:24.04 AS base
# ... shared layers (SSH, Node.js, gh, claude user, Claude Code, GSD) ...

FROM base AS cli
# No additional packages needed for CLI
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 22
CMD ["/usr/local/bin/entrypoint.sh"]

FROM base AS gui
RUN apt-get update && apt-get install -y \
    xfce4 xfce4-terminal tigervnc-standalone-server \
    novnc python3-websockify python3-numpy \
    dbus-x11 chromium-browser \
    && rm -rf /var/lib/apt/lists/*
# ... GUI-specific setup (xstartup, chromium wrapper) ...
COPY scripts/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh
EXPOSE 22 5901 6080
CMD ["/usr/local/bin/entrypoint.sh"]
```

**docker_build() change:**
```bash
docker_build() {
    local name="$1"
    local type
    type="$(instances_get_type "$name")"
    local image_tag="claude-sandbox-${name}-${type}"
    local target="${type}"   # "cli" or "gui"

    msg_info "Building Docker image ${image_tag} (target: ${target})..."
    if ! docker build --target "$target" -t "$image_tag" \
            -f "${CSM_ROOT}/scripts/Dockerfile" "$CSM_ROOT"; then
        die "Docker build failed for ${image_tag}"
    fi
    msg_ok "Docker image built: ${image_tag}"
}
```

### Pattern 2: TigerVNC Xvnc Startup in entrypoint.sh

**What:** entrypoint.sh detects GUI variant, runs vncserver (which uses Xvnc internally), then starts websockify, then sshd. All services run in background except sshd (which runs -D in foreground).

**When to use:** When starting multiple services in a single-entrypoint container.

**Variant detection approach (Claude's Discretion area):** Check for the `tigervnc-standalone-server` binary (i.e., `command -v vncserver`) — present only in GUI images.

**Example entrypoint extension:**
```bash
# Detect GUI variant by checking for vncserver binary
if command -v vncserver &>/dev/null; then
    # GUI: start VNC + noVNC, then fall through to sshd

    # Set up VNC password-less config for claude user
    mkdir -p /home/claude/.vnc
    # SecurityTypes None = no password, safe because localhost-only
    cat > /home/claude/.vnc/config <<'EOF'
SecurityTypes=None
geometry=1920x1080
depth=24
EOF

    # xstartup: launch Xfce4 session
    cat > /home/claude/.vnc/xstartup <<'EOF'
#!/bin/sh
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
EOF
    chmod 755 /home/claude/.vnc/xstartup
    chown -R claude:claude /home/claude/.vnc

    # Start VNC server as claude user on display :1 (port 5901), localhost only
    su - claude -c "vncserver :1 -localhost yes -fg &"
    sleep 2   # brief wait for Xvnc to bind

    # Start websockify: WebSocket -> VNC bridge, serving noVNC UI on port 6080
    # (container internal port; host mapping is 127.0.0.1:{vnc_port}:6080)
    websockify --web=/usr/share/novnc/ --daemon 6080 localhost:5901
fi

# Always start SSH
exec /usr/sbin/sshd -D
```

**Important:** vncserver :1 uses port 5901 (5900 + display number). The container EXPOSE 6080 is what noVNC is served on, not 5901. VNC port 5901 is internal only (localhost within container).

### Pattern 3: VNC Port Allocation in instances.sh

**What:** instances_add() receives an optional vnc_port argument for GUI instances. A new `instances_get_vnc_port_for()` function allocates the next free port starting at 6080, similar to the existing SSH port allocation pattern.

**When to use:** For GUI instances; CLI instances store null/omit vnc_port.

**Example:**
```bash
# instances_add extended signature: $1=name, $2=type (default cli), $3=vnc_port (optional, only for gui)
instances_add() {
    local name="$1"
    local type="${2:-cli}"
    local vnc_port="${3:-}"
    local port
    port="$(instances_next_free_port)"

    local json_update
    if [[ "$type" == "gui" && -n "$vnc_port" ]]; then
        json_update='".[$name] = { \"port\": $port, \"type\": $type, \"vnc_port\": ($vnc_port | tonumber) }"'
        jq --arg name "$name" --argjson port "$port" \
           --arg type "$type" --argjson vnc_port "$vnc_port" \
           '.[$name] = { "port": $port, "type": $type, "vnc_port": $vnc_port }' \
           "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
           && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
    else
        jq --arg name "$name" --argjson port "$port" --arg type "$type" \
           '.[$name] = { "port": $port, "type": $type }' \
           "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
           && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
    fi
    echo "$port"
}

instances_next_free_vnc_port() {
    local port=6080
    local registry_vnc_ports
    registry_vnc_ports="$(jq -r '.[].vnc_port // empty' "$_INSTANCES_FILE" 2>/dev/null)"

    while true; do
        local in_registry=false
        local rp
        for rp in $registry_vnc_ports; do
            if [[ "$rp" == "$port" ]]; then
                in_registry=true
                break
            fi
        done
        if $in_registry; then (( port++ )); continue; fi
        if command -v ss &>/dev/null; then
            if ss -tln 2>/dev/null | grep -q ":${port} "; then
                (( port++ ))
                continue
            fi
        fi
        break
    done
    echo "$port"
}

instances_get_vnc_port() {
    local name="$1"
    _instances_ensure_file
    jq -r --arg name "$name" '.[$name].vnc_port // empty' "$_INSTANCES_FILE"
}
```

### Pattern 4: docker_run_instance() GUI Flags

**What:** Conditionally add --shm-size=512m and the noVNC port mapping for GUI instances.

**Example:**
```bash
docker_run_instance() {
    local name="$1"
    local port="$2"
    local type
    type="$(instances_get_type "$name")"
    local image_tag="claude-sandbox-${name}-${type}"
    # ... existing cmd array setup ...

    # GUI-specific flags
    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        cmd+=(-p "127.0.0.1:${vnc_port}:6080")    # noVNC web UI, localhost only
        cmd+=(--shm-size=512m)                      # CONT-05: Chromium shared memory
    fi

    cmd+=("${image_tag}")
    # ...
}
```

### Pattern 5: menu_action_start() Type Branch

**What:** After docker_start_instance, read instance type and show appropriate prompt.

**Example:**
```bash
menu_action_start() {
    local name
    name="$(menu_select_instance "Select instance to start:")" || return

    docker_start_instance "$name"

    local type
    type="$(instances_get_type "$name")"

    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        msg_ok "noVNC desktop: http://localhost:${vnc_port}"
        local answer
        read -rp "Open in browser? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            xdg-open "http://localhost:${vnc_port}" 2>/dev/null || true
        fi
    else
        local answer
        read -rp "SSH into instance now? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            exec ssh "$(common_ssh_alias "$name")"
        fi
    fi
}
```

### Pattern 6: Chromium Wrapper Script in Dockerfile

**What:** Install a wrapper at /usr/local/bin/chromium that adds required container flags, then use it in the .desktop file and panel launcher.

**Why:** Chromium requires --no-sandbox in containers (no SYS_ADMIN capability), --disable-dev-shm-usage prevents shared memory crashes even with --shm-size=512m (belt and suspenders), --disable-gpu is needed in virtual framebuffer environments.

**Example:**
```dockerfile
# In gui stage of Dockerfile:
RUN printf '#!/bin/sh\nexec chromium-browser --no-sandbox --disable-gpu --disable-dev-shm-usage --homepage=about:blank "$@"\n' \
    > /usr/local/bin/chromium-safe \
    && chmod +x /usr/local/bin/chromium-safe
```

### Pattern 7: Xfce Desktop Icon for Workspace

**What:** A .desktop file on the claude user's Desktop pointing to /home/claude/workspace in Thunar.

**Example:**
```ini
[Desktop Entry]
Version=1.0
Type=Application
Name=Workspace
Comment=Project workspace folder
Exec=thunar /home/claude/workspace
Icon=folder
Terminal=false
Categories=Utility;
```

Placed at: /home/claude/Desktop/workspace.desktop (created in Dockerfile or entrypoint)

### Anti-Patterns to Avoid

- **Using Xvfb + separate VNC server:** Two processes to manage; Xvnc (TigerVNC) does both in one. Xvfb + x11vnc also has display locking issues in containers.
- **Setting VNC password:** The CONTEXT.md decision is no password; localhost-only binding is the security boundary. Avoid storing a password hash in the image.
- **Using xfce4-screensaver or xfce4-power-manager:** These cause problems in virtual display environments (screensaver locks the session, power manager interferes with display). Do not install them.
- **Running vncserver as root:** Must run as claude user. The entrypoint runs as root but uses `su - claude -c "vncserver ..."` to start VNC as the correct user.
- **Hardcoding VNC display :0:** Display :0 is sometimes taken. Use :1 consistently; this maps to port 5901 which stays internal to the container.
- **Using `exec` for background services:** Only the final sshd should use `exec`. Prior services (vncserver, websockify) must run with `&` or `--daemon`.
- **Missing dbus-x11:** Without dbus-x11, xfce4-session fails to connect to D-Bus and the desktop either shows a black screen or crashes immediately.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Virtual framebuffer + VNC server | Custom display server | tigervnc-standalone-server (Xvnc) | TigerVNC handles display, VNC protocol, encoding; massively complex to replicate |
| Browser-based VNC UI | Custom WebSocket VNC client | noVNC (apt package) | noVNC is 10k+ lines of battle-tested VNC protocol JS implementation |
| WebSocket-to-TCP bridge | Custom proxy | python3-websockify | Handles handshake, framing, error cases |
| Port conflict detection | Custom netstat parsing | Extend existing instances_next_free_port() pattern | Pattern already handles ss and registry |
| Chromium safe launch | Custom sandbox setup | Wrapper script with standard flags | --no-sandbox + --disable-dev-shm-usage is the established pattern |

**Key insight:** The GUI stack (TigerVNC + noVNC + websockify) is a well-established combination with thousands of production Docker deployments. Any piece of it built custom would be worse than the existing implementations.

---

## Common Pitfalls

### Pitfall 1: Black Screen After VNC Connect
**What goes wrong:** Browser connects to noVNC, session appears, but shows only black desktop.
**Why it happens:** xstartup is missing, not executable (needs chmod 755), or Xfce session fails to start due to missing dbus. Also happens if startxfce4 is called before the display is ready.
**How to avoid:** Always include `dbus-x11` in package list. Set `unset SESSION_MANAGER` and `unset DBUS_SESSION_BUS_ADDRESS` in xstartup before `exec startxfce4`. Set xstartup permissions to 755 (not 700 or 644).
**Warning signs:** vncserver process starts but logs show "Unable to get connection to the message bus."

### Pitfall 2: vncserver Permission Denied / Running as Wrong User
**What goes wrong:** entrypoint.sh runs as root; vncserver called as root creates VNC config in /root/.vnc not /home/claude/.vnc.
**Why it happens:** TigerVNC uses the running user's home directory for .vnc/config and .vnc/xstartup.
**How to avoid:** Use `su - claude -c "vncserver :1 ..."` in the entrypoint. Set up .vnc/ directory and files before the su call, then chown -R claude:claude /home/claude/.vnc.
**Warning signs:** VNC session doesn't inherit claude's PATH, or xstartup can't find xfce4 binaries.

### Pitfall 3: Chromium Crashes with SIGBUS (shared memory)
**What goes wrong:** Chromium opens then immediately crashes with SIGBUS or "Aw, Snap!" on page load.
**Why it happens:** Default Docker /dev/shm is 64MB. Chromium renders use shared memory heavily. Even with --shm-size=512m, the --disable-dev-shm-usage flag is needed as belt-and-suspenders.
**How to avoid:** Both the docker run `--shm-size=512m` flag (CONT-05) AND the `--disable-dev-shm-usage` Chromium flag are required. Implement both.
**Warning signs:** Chromium crashes only on pages with iframes or complex rendering; blank tab works fine.

### Pitfall 4: VNC Port vs noVNC Port Confusion
**What goes wrong:** Host maps container port 5901 (VNC) instead of 6080 (noVNC), or stores the wrong port in .instances.json.
**Why it happens:** VNC runs on 5901 (internal), noVNC/websockify runs on 6080 (the one mapped to host). The user accesses 6080 via browser.
**How to avoid:** Only port 6080 (noVNC) and port 22 (SSH) are mapped to host. Port 5901 (VNC) stays container-internal. Store only vnc_port=6080-mapped-host-port in .instances.json.
**Warning signs:** Browser connects but shows raw VNC binary data; or "connection refused" on the noVNC URL.

### Pitfall 5: multi-stage Dockerfile loses COPY context
**What goes wrong:** `COPY scripts/entrypoint.sh` in the gui stage fails because the Docker build context root is CSM_ROOT, but the file path must match.
**Why it happens:** Multi-stage builds still use the same build context; relative paths must be consistent.
**How to avoid:** entrypoint.sh is copied in both cli and gui stages using the same path `scripts/entrypoint.sh`. Verify the COPY instruction path matches the file location in the repo.
**Warning signs:** `docker build --target gui` succeeds but entrypoint is missing or is the wrong version.

### Pitfall 6: instances_add Called Before vnc_port Is Allocated
**What goes wrong:** menu_action_new calls instances_add before allocating a VNC port; later docker_run_instance can't find vnc_port.
**Why it happens:** The current flow (as noted in CONTEXT.md) calls instances_add in menu before docker_start_instance. VNC port allocation must happen at the same time as SSH port allocation.
**How to avoid:** For GUI type, allocate vnc_port inside instances_add itself (or call instances_next_free_vnc_port() inside instances_add when type=="gui"). Store it atomically in the same jq write.
**Warning signs:** vnc_port field is null/missing in .instances.json for GUI instances.

---

## Code Examples

Verified patterns from official sources and established container implementations:

### TigerVNC xstartup (verified from multiple Docker/VNC references)
```bash
#!/bin/sh
# ~/.vnc/xstartup — must be chmod 755
unset SESSION_MANAGER
unset DBUS_SESSION_BUS_ADDRESS
exec startxfce4
```

### VNC Server Start (non-root user, no password, localhost-only)
```bash
# Run as claude user via su or within user context
# ~/.vnc/config approach (preferred over command-line flags):
# SecurityTypes=None
# geometry=1920x1080
# depth=24

vncserver :1 -localhost yes
# :1 maps to port 5901
```

Or inline flags approach:
```bash
vncserver :1 -localhost yes -SecurityTypes None -geometry 1920x1080 -depth 24
```

### Websockify Launch (from Ubuntu 24.04 official documentation)
```bash
# Serve noVNC on port 6080, proxy to VNC on localhost:5901
websockify --web=/usr/share/novnc/ --daemon 6080 localhost:5901
```
Source: Ubuntu 24.04 server-world.info documentation (confirmed /usr/share/novnc/ path for apt-installed novnc)

### Multi-stage docker build --target (from Docker official docs)
```bash
docker build --target gui -t claude-sandbox-myinstance-gui -f scripts/Dockerfile .
docker build --target cli -t claude-sandbox-myinstance-cli -f scripts/Dockerfile .
```
Source: Docker official multi-stage builds documentation

### Chromium wrapper script
```bash
#!/bin/sh
# /usr/local/bin/chromium-safe
exec chromium-browser \
    --no-sandbox \
    --disable-gpu \
    --disable-dev-shm-usage \
    --homepage=about:blank \
    "$@"
```

### docker run GUI flags
```bash
docker run -d \
    --name claude-sandbox-myinstance \
    -p 127.0.0.1:2222:22 \          # SSH
    -p 127.0.0.1:6081:6080 \         # noVNC (host port 6081 -> container 6080)
    --shm-size=512m \                 # CONT-05: Chromium shared memory
    # ... rest of existing security flags ...
    claude-sandbox-myinstance-gui
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|---|---|---|---|
| Xvfb + x11vnc (two separate processes) | TigerVNC Xvnc (combined X+VNC server) | TigerVNC added Xvnc mode ~2015; now standard | Single process, simpler startup, better performance |
| noVNC from git clone | novnc apt package (Ubuntu 24.04 noble) | Ubuntu 22.04+ includes novnc in main repos | No git dependency; stable version at /usr/share/novnc/ |
| VNC password required | SecurityTypes=None for local-only containers | Widely adopted in Docker Desktop tools | Simpler setup; safe when bound to localhost |
| menu_select_container_type returns "cli" only | Returns actual selection including "gui" | Phase 4 activates the stub | GUI type selection becomes functional |

**Deprecated/outdated in this phase:**
- `menu_select_container_type()` stub that falls back to "cli" for option 2: replace with real "gui" return
- Single-stage Dockerfile: must be split into base/cli/gui stages

---

## Open Questions

1. **vncserver startup timing in entrypoint.sh**
   - What we know: vncserver :1 needs 1-3 seconds to initialize before websockify connects to it
   - What's unclear: Whether `sleep 2` is sufficient or if a poll loop (`until netstat -tln | grep 5901; do sleep 0.5; done`) is better
   - Recommendation: Use a poll loop (max 10 iterations, 0.5s each) rather than fixed sleep; more robust across load conditions

2. **xdg-open availability on host for "Open in browser?" prompt**
   - What we know: The prompt runs on the host side (in menu.sh); xdg-open is Linux-standard but not guaranteed
   - What's unclear: Whether macOS users see the right behavior (open command vs xdg-open)
   - Recommendation: Print the URL clearly regardless; use `xdg-open 2>/dev/null || open 2>/dev/null || true` with a fallback message

3. **vncserver session persistence after container restart**
   - What we know: Session persists while container is running; browser tab close reconnects to same session
   - What's unclear: After `docker stop` + `docker start`, does the VNC session (including running GUI apps) persist?
   - Recommendation: Accept that restart wipes the VNC session (this is standard Docker behavior); document it

---

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | BATS (Bash Automated Testing System) |
| Config file | tests/test_helper.bash |
| Quick run command | `./node_modules/.bin/bats tests/dockerfile.bats tests/docker.bats tests/instances.bats tests/menu.bats` |
| Full suite command | `./node_modules/.bin/bats tests/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| CONT-02 | Dockerfile has gui stage | unit (grep) | `bats tests/dockerfile.bats` | ✅ (extend dockerfile.bats) |
| CONT-02 | docker_build passes --target flag | unit (grep) | `bats tests/docker.bats` | ✅ (extend docker.bats) |
| CONT-02 | menu_select_container_type returns "gui" for option 2 | unit | `bats tests/menu.bats` | ✅ (extend menu.bats) |
| CONT-02 | instances_add stores type=gui in registry | unit | `bats tests/instances.bats` | ✅ (extend instances.bats) |
| CONT-04 | Dockerfile gui stage installs novnc package | unit (grep) | `bats tests/dockerfile.bats` | ✅ (extend dockerfile.bats) |
| CONT-04 | Dockerfile gui stage installs tigervnc-standalone-server | unit (grep) | `bats tests/dockerfile.bats` | ✅ (extend dockerfile.bats) |
| CONT-04 | Dockerfile gui stage installs websockify | unit (grep) | `bats tests/dockerfile.bats` | ✅ (extend dockerfile.bats) |
| CONT-04 | entrypoint.sh contains vncserver startup | unit (grep) | `bats tests/dockerfile.bats` | ✅ (extend dockerfile.bats) |
| CONT-05 | docker_run_instance adds --shm-size=512m for gui type | unit (grep) | `bats tests/docker.bats` | ✅ (extend docker.bats) |
| CONT-05 | docker_run_instance does NOT add --shm-size for cli type | unit (grep) | `bats tests/docker.bats` | ✅ (extend docker.bats) |
| CONT-02 | instances_get_vnc_port returns allocated vnc port for gui | unit | `bats tests/instances.bats` | ✅ (extend instances.bats) |
| CONT-02 | instances_get_vnc_port returns empty for cli instance | unit | `bats tests/instances.bats` | ✅ (extend instances.bats) |

### Sampling Rate

- **Per task commit:** `./node_modules/.bin/bats tests/dockerfile.bats tests/docker.bats tests/instances.bats tests/menu.bats`
- **Per wave merge:** `./node_modules/.bin/bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

None — existing test infrastructure (BATS, test_helper.bash) covers all phase test types. All tests are new test cases added to existing .bats files, not new files.

---

## Sources

### Primary (HIGH confidence)
- Ubuntu packages.ubuntu.com — novnc (1:1.3.0-2 noble), tigervnc-standalone-server, python3-websockify (0.10.x noble) confirmed in Ubuntu 24.04 repositories
- Docker official docs (docs.docker.com/build/building/multi-stage/) — multi-stage `--target` build flag behavior
- server-world.info Ubuntu 24.04 noVNC guide — websockify command: `websockify --web=/usr/share/novnc/ 6080 localhost:5901`, package list: `novnc python3-websockify python3-numpy`

### Secondary (MEDIUM confidence)
- VNC+xfce4 gist (mixalbl4-127) — xstartup pattern: unset SESSION_MANAGER, unset DBUS_SESSION_BUS_ADDRESS, startxfce4; vncserver flags -depth 24 -geometry 1920x1080 -localhost no
- chromium.googlesource.com Linux sandboxing docs — --no-sandbox flag requirement in sandboxed container environments
- Chromium bug #736452 — --disable-dev-shm-usage flag rationale (uses /tmp instead of /dev/shm)
- accetto/ubuntu-vnc-xfce-g3 (Docker Hub) — production reference for TigerVNC + noVNC + Xfce4 + Chromium combination

### Tertiary (LOW confidence, mark for validation)
- Various forum posts on dbus-x11 being required for Xfce VNC sessions — treat as "likely true, verify by testing"
- xdg-open availability on host: assumed to work on Linux; macOS behavior (needs `open` instead) not verified against current state of menu.sh

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all packages confirmed in Ubuntu 24.04 noble apt repositories
- Architecture: HIGH — multi-stage Dockerfile and Bash array patterns verified against Docker docs and existing codebase conventions
- Pitfalls: MEDIUM — dbus/xstartup pitfalls from multiple corroborating community sources; timing issues from first-principles reasoning
- Test patterns: HIGH — BATS infrastructure confirmed present and working from Phase 1-3

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (Ubuntu 24.04 package versions stable; noVNC/TigerVNC APIs stable)
