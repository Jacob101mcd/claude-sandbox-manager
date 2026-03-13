# Phase 4: GUI Container Variant - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Desktop environment container (Xfce + noVNC) accessible in-browser, sharing the minimal CLI variant's base Dockerfile stage. Users can create a GUI instance, access a full desktop via localhost URL, and run a browser inside the container for web testing. No new manager features — this phase adds the GUI container type alongside the existing CLI type.

</domain>

<decisions>
## Implementation Decisions

### noVNC access & ports
- Each GUI instance gets two auto-allocated ports: SSH (2222+) and noVNC (6080+)
- Both ports stored in .instances.json per instance
- noVNC bound to localhost only (127.0.0.1:{port}:6080) — no VNC password needed
- After GUI instance starts: print noVNC URL + "Open in browser? (y/N)" prompt
- No SSH prompt for GUI instances — users connect via SSH separately if needed
- URL format: http://localhost:{noVNC_port}

### Desktop experience
- Screen resolution: 1920x1080, 24-bit color
- Auto-login as claude user — no login screen
- Session persists when browser tab is closed — VNC server keeps running, reconnect shows same desktop
- Stripped-down Xfce: minimal panel, file manager, terminal emulator, browser — no screensaver, power manager, or unnecessary plugins
- Workspace desktop shortcut: folder icon on desktop pointing to /home/claude/workspace
- Terminal emulator pinned to Xfce panel for quick access
- Chromium pinned to Xfce panel alongside terminal
- noVNC clipboard integration enabled (sidebar panel for copy/paste between host and container)

### Browser inside container
- Chromium pre-installed (not Firefox)
- Container-safe launch flags via wrapper script or .desktop file: --no-sandbox, --disable-gpu, --disable-dev-shm-usage
- Homepage set to about:blank (fastest start, no network requests)
- --shm-size=512m on docker run ensures Chromium stability (CONT-05)

### Dockerfile structure
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

</decisions>

<specifics>
## Specific Ideas

- GUI instances should feel lightweight — stripped Xfce, not a full desktop distro experience
- The main use case is web testing: open a browser, check localhost dev servers, visually inspect UI
- Clipboard sharing is essential for transferring URLs and code between host and container
- "Open in browser?" prompt keeps the UX consistent with the existing "SSH into instance?" pattern from CLI instances

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docker_run_instance()` in lib/docker.sh: Bash array for docker run flags — add --shm-size=512m and second -p for noVNC port conditionally based on type
- `instances_add()` in lib/instances.sh: currently stores `{ port, type }` — extend to include vnc_port for GUI instances
- `menu_select_container_type()` in lib/menu.sh: already shows [1] CLI, [2] GUI selection
- `credentials_get_docker_env_flags()` in lib/credentials.sh: credential injection reused as-is for GUI containers
- `scripts/entrypoint.sh`: current entrypoint starts sshd — extend with VNC/noVNC startup for GUI variant

### Established Patterns
- Docker run command built as Bash array — extend with conditional flags for GUI type
- Atomic jq writes for .instances.json — use same pattern for vnc_port field
- Port allocation starts at 2222 for SSH — noVNC ports should use similar allocation from 6080+
- `msg_info`, `msg_ok` for status output — use for noVNC URL display
- Color output auto-disabled when stdout is not a terminal

### Integration Points
- `scripts/Dockerfile`: Refactor from single-stage to multi-stage (base/cli/gui)
- `docker_build()`: Add --target flag based on instance type
- `docker_run_instance()`: Conditionally add --shm-size=512m and noVNC port mapping for GUI type
- `instances_add()` / `instances_get_port()`: Handle vnc_port allocation and storage
- `menu_action_start()`: Show "Open in browser?" for GUI instances instead of "SSH into instance?"
- `scripts/entrypoint.sh`: Add GUI service startup (Xvfb, VNC, noVNC) with variant detection

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 04-gui-container-variant*
*Context gathered: 2026-03-13*
