---
phase: 07-backup-restore-integration
verified: 2026-03-14T18:30:00Z
status: passed
score: 5/5 must-haves verified
re_verification: null
gaps: []
human_verification:
  - test: "End-to-end GUI restore flow"
    expected: "After restoring a GUI instance, menu shows noVNC URL and browser prompt (not SSH prompt)"
    why_human: "Interactive menu flow with read -rp cannot be driven programmatically"
  - test: "SSH immediately after CLI restore"
    expected: "After restoring a CLI instance, ssh <alias> connects without manual config steps"
    why_human: "Requires actual Docker container + SSH to verify live connectivity"
---

# Phase 7: Backup Restore Integration Verification Report

**Phase Goal:** Fix the "Restore -> SSH with MCP/RC" end-to-end flow -- pass instance name to credential flags on restore, call ssh_write_config after restore, fix restore->SSH flow
**Verified:** 2026-03-14T18:30:00Z
**Status:** passed
**Re-verification:** No -- initial verification

## Goal Achievement

### Observable Truths

| #   | Truth | Status | Evidence |
| --- | ----- | ------ | -------- |
| 1   | Restored container has all security, resource, GUI, MCP, and credential flags identical to a freshly created container | VERIFIED | `_docker_build_run_cmd` is the single source of truth; both `docker_run_instance` (docker.sh:139) and `backup_restore` (backup.sh:164) call it |
| 2   | SSH alias works immediately after restore without manual intervention | VERIFIED | `ssh_write_config "$name" "$port"` called at backup.sh:173 after container start; BATS test 49 confirms call with correct args |
| 3   | MCP and remote control env vars are injected into restored containers | VERIFIED | `_docker_build_run_cmd` calls `credentials_get_docker_env_flags "$name"` (docker.sh:109) with instance name; BATS test 50 confirms instance name passed |
| 4   | GUI containers restored with VNC port mapping and shared memory | VERIFIED | GUI branch at docker.sh:91-96 adds `--shm-size=512m` and VNC port; BATS tests 51-52 confirm both flags for GUI restore |
| 5   | After restore, user gets type-aware prompt (browser for GUI, SSH for CLI) | VERIFIED | `menu_action_restore` calls `instances_get_type` at menu.sh:325 and branches at menu.sh:327-344; matches `menu_action_start` pattern exactly |

**Score:** 5/5 truths verified

### Required Artifacts

| Artifact | Expected | Status | Details |
| -------- | -------- | ------ | ------- |
| `lib/docker.sh` | `_docker_build_run_cmd` shared helper + refactored `docker_run_instance` | VERIFIED | `_docker_build_run_cmd` defined at line 57; `docker_run_instance` delegates to it at line 139; 3 occurrences of `_docker_build_run_cmd` in file |
| `lib/backup.sh` | `backup_restore` using shared helper + `ssh_write_config` call | VERIFIED | `_docker_build_run_cmd` called at line 164; `ssh_write_config` called at line 173; no "keep in sync" comment remains |
| `lib/menu.sh` | Type-aware post-restore UX in `menu_action_restore` | VERIFIED | `instances_get_type` used at line 325; GUI branch with `instances_get_vnc_port` at line 329; SSH branch at line 341-343 |
| `tests/docker.bats` | Tests for `_docker_build_run_cmd` helper | VERIFIED | 4 new tests at lines 338-383: image tag, shm-size for GUI, add-host on Linux Engine, delegation from `docker_run_instance` |
| `tests/backup.bats` | Tests for restore with `ssh_write_config`, instance name in cred flags | VERIFIED | 4 new tests at lines 453-511: ssh_write_config call, credentials instance name, shm-size for GUI, VNC port for GUI; setup sources docker.sh, settings.sh, instances.sh with post-source mock re-export |

### Key Link Verification

| From | To | Via | Status | Details |
| ---- | -- | --- | ------ | ------- |
| `lib/backup.sh` | `lib/docker.sh` | `_docker_build_run_cmd` call | WIRED | backup.sh:164 calls `_docker_build_run_cmd "$name" "$port" "$image_tag"` |
| `lib/backup.sh` | `ssh_write_config` | function call after container start | WIRED | backup.sh:173 calls `ssh_write_config "$name" "$port"` inside success path |
| `lib/docker.sh (_docker_build_run_cmd)` | `credentials_get_docker_env_flags` | passes instance name argument | WIRED | docker.sh:109 calls `credentials_get_docker_env_flags "$name"` -- with name, not without |
| `lib/menu.sh (menu_action_restore)` | `instances_get_type` | type-aware UX branch | WIRED | menu.sh:325 calls `instances_get_type "$name"` post-restore; branches at line 327 |

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
| ----------- | ----------- | ----------- | ------ | -------- |
| BACK-03 | 07-01-PLAN.md | Backup captures both container filesystem and workspace volume data | SATISFIED | `backup_restore` restores both `image.tar.gz` (docker load) and `workspace.tar.gz` (tar xzf); BATS tests 47-48 verify both paths |
| BACK-04 | 07-01-PLAN.md | User can restore an instance from a backup | SATISFIED | `backup_restore` fully implemented; `menu_action_restore` provides UX; full test suite (BATS tests 45-52) passes |
| MCP-01 | 07-01-PLAN.md | Sandbox instances automatically connect to host Docker MCP Toolkit server on startup | SATISFIED | `_docker_build_run_cmd` calls `credentials_get_docker_env_flags "$name"` which injects `CSM_MCP_ENABLED`, `CSM_MCP_PORT` env vars; now applies to restore path as well as create path |
| INST-02 | 07-01-PLAN.md | Claude Code remote control optionally configured on container startup | SATISFIED | `credentials_get_docker_env_flags "$name"` injects `CSM_REMOTE_CONTROL` when enabled; now applies to restore path; BATS test 50 confirms instance name passed so RC flag is picked up |

No orphaned requirements: REQUIREMENTS.md traceability table maps BACK-03, BACK-04, MCP-01, INST-02 to "Phase 5, Phase 7" or "Phase 3, Phase 7" -- all claimed by this plan.

### Anti-Patterns Found

| File | Line | Pattern | Severity | Impact |
| ---- | ---- | ------- | -------- | ------ |
| (none) | -- | -- | -- | No anti-patterns found in any modified file |

No TODO/FIXME/PLACEHOLDER comments. No empty implementations. No stub handlers. The "keep in sync" comment from the old backup.sh has been removed.

### Human Verification Required

#### 1. End-to-end GUI restore flow

**Test:** Create a GUI instance, create a backup, restore it via the menu (option E), observe post-restore prompt
**Expected:** Menu displays "noVNC desktop: http://localhost:{vnc_port}" and asks "Open in browser? (y/N)"
**Why human:** Interactive `read -rp` prompt driven by a real terminal session; cannot be driven via BATS

#### 2. SSH immediately after CLI restore

**Test:** Create a CLI instance, create a backup, restore it via menu, say Y to SSH prompt
**Expected:** `ssh csm-{name}` connects without requiring manual `~/.ssh/config` edits
**Why human:** Requires live Docker daemon, running container, and SSH daemon -- full integration test

### Gaps Summary

No gaps. All five observable truths verified against the codebase. All four required artifacts exist, are substantive, and are wired. All four key links confirmed present with correct arguments. All 52 BATS tests in docker.bats and backup.bats pass. Requirements BACK-03, BACK-04, MCP-01, and INST-02 are fully satisfied by the implementation.

The critical root cause this phase addressed -- `backup_restore` duplicating the docker run command without GUI flags, MCP flags, instance name for credentials, or ssh_write_config -- is eliminated. `_docker_build_run_cmd` is now the single source of truth and both creation and restore paths go through it.

---

_Verified: 2026-03-14T18:30:00Z_
_Verifier: Claude (gsd-verifier)_
