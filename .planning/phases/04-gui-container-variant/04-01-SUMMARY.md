---
phase: 04-gui-container-variant
plan: 01
subsystem: infra
tags: [docker, dockerfile, multi-stage, xfce4, tigervnc, novnc, websockify, chromium, vnc]

# Dependency graph
requires:
  - phase: 02-container-engine
    provides: scripts/Dockerfile and scripts/entrypoint.sh CLI baseline
provides:
  - Multi-stage Dockerfile with base, cli, and gui named stages
  - GUI container image target with full Xfce4 + TigerVNC + noVNC + Chromium stack
  - entrypoint.sh with GUI variant auto-detection and VNC/noVNC service startup
affects: [04-02-host-side-gui-support, 05-mcp-toolkit]

# Tech tracking
tech-stack:
  added: [xfce4, xfce4-terminal, tigervnc-standalone-server, novnc, python3-websockify, python3-numpy, dbus-x11, chromium-browser]
  patterns: [multi-stage-dockerfile, variant-detection-via-binary-check, daemon-sidecar-before-pid1]

key-files:
  created: []
  modified:
    - scripts/Dockerfile
    - scripts/entrypoint.sh

key-decisions:
  - "GUI variant detected at runtime via 'command -v vncserver' — no env var needed, binary presence is authoritative"
  - "VNC port 5901 is container-internal only; only SSH (22) and noVNC (6080) exposed"
  - "chromium-safe wrapper script provides --no-sandbox --disable-gpu --disable-dev-shm-usage for rootless container safety"
  - "vncserver :1 runs as claude user via su - claude -c to avoid root VNC session"
  - "websockify runs with --daemon flag; VNC readiness polled via ss/netstat rather than fixed sleep"

patterns-established:
  - "Multi-stage Dockerfile pattern: base stage holds all shared layers; cli/gui extend independently"
  - "Entrypoint sidecar pattern: background services start before exec PID1 (sshd)"

requirements-completed: [CONT-02, CONT-04]

# Metrics
duration: 1min
completed: 2026-03-13
---

# Phase 4 Plan 01: GUI Container Variant — Dockerfile and Entrypoint Summary

**Multi-stage Dockerfile (base/cli/gui) with TigerVNC + Xfce4 + noVNC + Chromium GUI stack, and entrypoint.sh auto-detecting GUI variant to start VNC services before sshd**

## Performance

- **Duration:** 1 min
- **Started:** 2026-03-13T22:03:18Z
- **Completed:** 2026-03-13T22:04:34Z
- **Tasks:** 2
- **Files modified:** 2

## Accomplishments
- Refactored single-stage Dockerfile into three named stages (base, cli, gui) with shared layers in base
- GUI stage installs full desktop stack: xfce4, tigervnc-standalone-server, novnc, python3-websockify, dbus-x11, chromium-browser
- Added chromium-safe wrapper script with container-safe flags and workspace Desktop shortcut
- Extended entrypoint.sh with VNC/noVNC service startup for GUI containers, CLI containers unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Refactor Dockerfile to multi-stage base/cli/gui** - `ca04ef2` (feat)
2. **Task 2: Extend entrypoint.sh with GUI variant detection and VNC startup** - `c84990f` (feat)

**Plan metadata:** (docs commit follows)

## Files Created/Modified
- `scripts/Dockerfile` - Refactored to three named stages; gui stage adds full desktop+VNC stack
- `scripts/entrypoint.sh` - Added GUI detection block with vncserver/websockify startup before sshd

## Decisions Made
- GUI variant detected via `command -v vncserver` — binary presence is authoritative, no environment variable needed
- VNC port 5901 is container-internal only; EXPOSE 22 6080 in gui stage (noVNC port visible)
- chromium-safe wrapper at /usr/local/bin/chromium-safe provides --no-sandbox --disable-gpu --disable-dev-shm-usage
- vncserver :1 runs as claude user via `su - claude -c` to prevent root VNC sessions
- websockify uses --daemon flag; VNC readiness uses poll loop (max 10 × 0.5s) instead of fixed sleep

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- GUI container image target is complete — ready for Plan 02 (host-side GUI support)
- Plan 02 will add --target gui to docker_build(), noVNC port allocation, and "Open in browser?" menu UX
- No blockers

---
*Phase: 04-gui-container-variant*
*Completed: 2026-03-13*
