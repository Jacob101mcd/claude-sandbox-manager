---
phase: 04-gui-container-variant
verified: 2026-03-13T22:13:00Z
status: passed
score: 11/11 must-haves verified
gaps: []
human_verification:
  - test: "Build GUI image and connect via noVNC"
    expected: "Browser opens http://localhost:6080, Xfce4 desktop appears, Chromium launches from panel"
    why_human: "Requires Docker build (minutes), running container, and visual desktop check"
  - test: "CLI container regression"
    expected: "SSH to CLI container works normally, no VNC services appear in process list"
    why_human: "Requires running container and SSH session to verify process isolation"
---

# Phase 4: GUI Container Variant Verification Report

**Phase Goal:** Add a GUI container variant with desktop environment accessible via noVNC browser
**Verified:** 2026-03-13T22:13:00Z
**Status:** PASSED
**Re-verification:** No — initial verification

## Goal Achievement

### Observable Truths

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | Dockerfile has base, cli, and gui named stages | VERIFIED | Lines 1, 65, 76 in scripts/Dockerfile: `FROM ubuntu:24.04 AS base`, `FROM base AS cli`, `FROM base AS gui` |
| 2 | GUI stage installs TigerVNC, noVNC, websockify, Xfce4, and Chromium | VERIFIED | Lines 79-88: single RUN with xfce4, tigervnc-standalone-server, novnc, python3-websockify, dbus-x11, chromium-browser |
| 3 | entrypoint.sh detects GUI variant and starts Xvnc + websockify before sshd | VERIFIED | Lines 24-57: `command -v vncserver` guard, vncserver :1, websockify on 6080, exec sshd remains line 59 |
| 4 | Chromium wrapper script provides container-safe launch flags | VERIFIED | Lines 91-93: /usr/local/bin/chromium-safe with --no-sandbox --disable-gpu --disable-dev-shm-usage |
| 5 | CLI containers continue to work exactly as before (no regression) | VERIFIED | cli stage (lines 65-71) is minimal: COPY entrypoint.sh + EXPOSE 22 + CMD only; 96/96 tests pass |
| 6 | User can select GUI container type and have it registered with a vnc_port | VERIFIED | menu_select_container_type returns "gui" (line 130 menu.sh); instances_add stores vnc_port atomically (lines 47-59 instances.sh) |
| 7 | docker_build passes --target gui/cli based on instance type | VERIFIED | docker_build reads type, sets target="${type}", passes --target "$target" (line 34 docker.sh) |
| 8 | docker_run_instance adds --shm-size=512m and noVNC port mapping for GUI instances | VERIFIED | Lines 82-87 docker.sh: conditional block adds -p 127.0.0.1:${vnc_port}:6080 and --shm-size=512m |
| 9 | Image tag includes type suffix: claude-sandbox-{name}-{type} | VERIFIED | image_tag="claude-sandbox-${name}-${type}" used in both docker_build (line 31) and docker_run_instance (line 55) |
| 10 | After starting a GUI instance, user sees noVNC URL and Open in browser? prompt | VERIFIED | menu_action_start (lines 147-157) and menu_action_new (lines 211-221) both branch on type=gui to show noVNC URL and prompt |
| 11 | CLI instances work exactly as before (no regression) | VERIFIED | menu fallback path shows SSH prompt; 96/96 tests pass including all pre-existing tests |

**Score:** 11/11 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `scripts/Dockerfile` | Multi-stage build with base, cli, gui stages | VERIFIED | 114 lines, 3 named stages confirmed |
| `scripts/Dockerfile` | GUI stage with desktop packages | VERIFIED | Lines 79-88: all required packages present under `FROM base AS gui` |
| `scripts/entrypoint.sh` | GUI variant detection and VNC startup | VERIFIED | 59 lines, full VNC startup block at lines 24-57 |
| `lib/instances.sh` | vnc_port allocation, storage, and retrieval | VERIFIED | instances_next_free_vnc_port (line 157), instances_get_vnc_port (line 201), instances_add GUI branch (line 47) |
| `lib/docker.sh` | Type-aware build (--target) and run (--shm-size, vnc port) | VERIFIED | --target at line 34, shm-size at line 86, vnc port mapping at line 85 |
| `lib/menu.sh` | GUI type selection returns gui, post-start shows noVNC URL | VERIFIED | case 2 returns "gui" (line 130), "Open in browser" at lines 152 and 216 |
| `tests/dockerfile.bats` | Tests for multi-stage Dockerfile structure and GUI packages | VERIFIED | 13 tests total, 10 new GUI-related tests |
| `tests/docker.bats` | Tests for --target, --shm-size, and vnc port flags | VERIFIED | 9 new tests (static grep + functional mock) all passing |
| `tests/instances.bats` | Tests for vnc_port storage and retrieval | VERIFIED | 6 new tests: gui type stores vnc_port, cli does not, next_free_vnc_port logic |
| `tests/menu.bats` | Tests for GUI type selection returning gui | VERIFIED | 5 tests including "returns gui for option 2" and "does not show coming soon" |

### Key Link Verification

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| scripts/Dockerfile (gui stage) | scripts/entrypoint.sh | COPY scripts/entrypoint.sh | WIRED | Line 109: COPY in gui stage; Line 67: COPY in cli stage |
| scripts/entrypoint.sh (GUI branch) | TigerVNC Xvnc | vncserver :1 command | WIRED | Line 44: `su - claude -c "vncserver :1 -localhost yes"` |
| scripts/entrypoint.sh (GUI branch) | noVNC via websockify | websockify --web=/usr/share/novnc/ 6080 5901 | WIRED | Line 56: `websockify --web=/usr/share/novnc/ --daemon 6080 localhost:5901` |
| lib/menu.sh (menu_select_container_type) | lib/instances.sh (instances_add) | type parameter through menu_action_new | WIRED | Line 204: container_type captured; Line 207: instances_add "$name" "$container_type" |
| lib/instances.sh (instances_add) | instances_next_free_vnc_port | Conditional vnc_port allocation when type==gui | WIRED | Line 49: `vnc_port="$(instances_next_free_vnc_port)"` inside `if [[ "$type" == "gui" ]]` |
| lib/docker.sh (docker_build) | lib/instances.sh (instances_get_type) | Reads type to determine --target flag | WIRED | Line 29-30: `type="$(instances_get_type "$name")"`, `local target="${type}"` |
| lib/docker.sh (docker_run_instance) | lib/instances.sh (instances_get_vnc_port) | Reads vnc_port for -p mapping, adds --shm-size for GUI | WIRED | Line 84: `vnc_port="$(instances_get_vnc_port "$name")"` inside `if [[ "$type" == "gui" ]]` |
| lib/menu.sh (menu_action_start) | instances_get_type, instances_get_vnc_port | Branches on type to show noVNC URL | WIRED | Lines 144-157: reads type, reads vnc_port, shows URL and "Open in browser?" prompt |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| CONT-02 | 04-01, 04-02 | User can build and run a GUI container with desktop environment and browser | SATISFIED | Multi-stage Dockerfile with gui target; full Xfce4+Chromium stack; menu workflow registers and starts GUI instances |
| CONT-04 | 04-01, 04-02 | GUI container runs Xvfb + noVNC for browser-based desktop access | SATISFIED | entrypoint.sh starts vncserver :1 + websockify on 6080; noVNC web UI served; URL shown post-start |
| CONT-05 | 04-02 | GUI containers start with adequate shared memory (--shm-size=512m minimum) | SATISFIED | docker_run_instance adds --shm-size=512m conditionally for gui type (lib/docker.sh line 86) |

Note: CONT-03 (type selection menu exists) is also satisfied by this phase's work, but it was already marked complete in Phase 2 and not claimed by Phase 4 plans. No orphaned Phase 4 requirements exist in REQUIREMENTS.md — CONT-02, CONT-04, CONT-05 are the only IDs mapped to Phase 4 in the traceability table.

### Anti-Patterns Found

None. Scanned scripts/Dockerfile, scripts/entrypoint.sh, lib/instances.sh, lib/docker.sh, lib/menu.sh for TODO/FIXME/PLACEHOLDER/coming soon/return null/return {}/return []. No issues found.

### Human Verification Required

#### 1. Build and Connect via noVNC

**Test:** Run `docker build --target gui -t claude-sandbox-test-gui -f scripts/Dockerfile .` then start a container with `-p 127.0.0.1:6080:6080` and open `http://localhost:6080` in a browser.
**Expected:** noVNC web client loads, Xfce4 desktop appears, Chromium-safe launches from the panel with no sandbox errors.
**Why human:** Requires full Docker build (multi-minute operation), live container runtime, and visual desktop verification — cannot be automated in this environment.

#### 2. CLI Regression Check

**Test:** Start an existing CLI instance, SSH in, verify `pgrep vncserver` and `pgrep websockify` return nothing.
**Expected:** SSH works normally; no VNC processes exist; `vncserver` binary is absent from PATH.
**Why human:** Requires a running container and live SSH session.

### Gaps Summary

No gaps. All 11 observable truths are verified, all 10 artifacts are substantive and wired, all 8 key links are confirmed, all 3 requirements (CONT-02, CONT-04, CONT-05) are satisfied. The full BATS test suite passes at 96/96 with no skips except the Docker-unavailable orphan detection test (expected in this environment).

---

_Verified: 2026-03-13T22:13:00Z_
_Verifier: Claude (gsd-verifier)_
