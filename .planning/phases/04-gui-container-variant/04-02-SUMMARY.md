---
phase: 04-gui-container-variant
plan: 02
subsystem: instances-docker-menu
tags: [gui, vnc, docker, instances, menu, bats, tdd]
dependency_graph:
  requires: [04-01]
  provides: [GUI container workflow end-to-end]
  affects: [lib/instances.sh, lib/docker.sh, lib/menu.sh]
tech_stack:
  added: []
  patterns: [atomic-jq-write, bash-array-cmd-builder, tdd-red-green]
key_files:
  created: []
  modified:
    - lib/instances.sh
    - lib/docker.sh
    - lib/menu.sh
    - tests/instances.bats
    - tests/docker.bats
    - tests/dockerfile.bats
    - tests/menu.bats
decisions:
  - vnc_port allocation mirrors ssh port allocation pattern: starts at 6080, checks registry then system
  - image tag includes type suffix (claude-sandbox-{name}-{type}) to distinguish cli/gui images
  - GUI flags (shm-size, noVNC port) added conditionally in docker_run_instance before image tag
  - instances_list_with_status shows different format for GUI: ssh:port vnc:port vs port only
  - menu_action_new uses container_type variable already in scope (no extra instances_get_type call)
metrics:
  duration: 7min
  completed_date: "2026-03-13"
  tasks: 2
  files_modified: 7
---

# Phase 04 Plan 02: GUI Container Bash Module Wiring Summary

**One-liner:** Type-aware GUI container workflow with vnc_port allocation in instances.sh, --target build flag in docker.sh, and noVNC URL display replacing SSH prompt in menu.sh.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (RED) | Failing tests for instances/docker/dockerfile | a927301 | tests/instances.bats, tests/docker.bats, tests/dockerfile.bats |
| 1 (GREEN) | vnc_port allocation + type-aware docker build/run | 03195cb | lib/instances.sh, lib/docker.sh |
| 2 (RED) | Failing tests for menu GUI type selection | dc4e222 | tests/menu.bats |
| 2 (GREEN) | Activate GUI type in menu + noVNC URL display | bec1c3d | lib/menu.sh |

## What Was Built

### lib/instances.sh

- `instances_next_free_vnc_port()`: finds next free port starting at 6080, checks registry and system via `ss`
- `instances_get_vnc_port()`: retrieves vnc_port for named instance (empty for CLI instances)
- `instances_add()` updated: when type=gui, allocates vnc_port and stores it atomically in JSON registry
- `instances_list_with_status()` updated: GUI instances display `(ssh:port vnc:port)` format

### lib/docker.sh

- `docker_build()` updated: reads instance type, sets `--target {type}`, uses `claude-sandbox-{name}-{type}` image tag
- `docker_run_instance()` updated: uses type-suffixed image tag, adds `--shm-size=512m` and `-p 127.0.0.1:{vnc_port}:6080` for GUI instances

### lib/menu.sh

- `menu_select_container_type()` updated: option 2 returns "gui" (no more "coming soon" fallback)
- `menu_action_start()` updated: branches on instance type — GUI shows noVNC URL + "Open in browser?" prompt, CLI keeps SSH prompt
- `menu_action_new()` updated: same branching after docker_start_instance using `container_type` variable already in scope

### Tests (96 total, all passing)

- `tests/instances.bats`: 6 new tests for vnc_port allocation, retrieval, and next-free logic
- `tests/docker.bats`: 9 new tests (static grep + functional mock tests) for --target, shm-size, noVNC port
- `tests/dockerfile.bats`: 10 new tests for multi-stage structure and GUI packages
- `tests/menu.bats`: 2 new tests for GUI type selection returning "gui" and no "coming soon"

## Deviations from Plan

None — plan executed exactly as written.

## Self-Check: PASSED

Files created/modified exist:
- lib/instances.sh: FOUND
- lib/docker.sh: FOUND
- lib/menu.sh: FOUND
- tests/instances.bats: FOUND
- tests/docker.bats: FOUND
- tests/dockerfile.bats: FOUND
- tests/menu.bats: FOUND

Commits exist:
- a927301: FOUND (test RED: instances/docker/dockerfile)
- 03195cb: FOUND (feat: instances.sh + docker.sh implementation)
- dc4e222: FOUND (test RED: menu)
- bec1c3d: FOUND (feat: menu.sh implementation)

Full test suite: 96/96 passing
