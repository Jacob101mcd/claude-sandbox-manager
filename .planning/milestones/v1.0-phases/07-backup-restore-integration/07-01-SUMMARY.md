---
phase: 07-backup-restore-integration
plan: 01
subsystem: docker
tags: [bash, docker, backup, restore, mcp, gui, ssh]

# Dependency graph
requires:
  - phase: 03-backup-restore
    provides: backup_create, backup_restore, backup_list functions
  - phase: 04-gui-container-variant
    provides: GUI type detection, instances_get_vnc_port, shm-size pattern
  - phase: 05-integration-layer
    provides: credentials_get_docker_env_flags with instance name, MCP env vars

provides:
  - _docker_build_run_cmd: single source of truth for docker run command construction
  - backup_restore produces containers identical to docker_run_instance
  - SSH alias works immediately after restore (ssh_write_config called)
  - MCP and RC env vars injected into restored containers
  - GUI containers restored with VNC port mapping and shared memory
  - Type-aware post-restore UX in menu_action_restore

affects: [all phases that use backup_restore or docker_run_instance]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - _DOCKER_RUN_CMD global array populated by _docker_build_run_cmd helper
    - Underscore-prefix internal function convention (_docker_build_run_cmd)
    - Single source of truth: shared helper eliminates flag duplication between create and restore

key-files:
  created: []
  modified:
    - lib/docker.sh
    - lib/backup.sh
    - lib/menu.sh
    - tests/docker.bats
    - tests/backup.bats

key-decisions:
  - "_docker_build_run_cmd populates global _DOCKER_RUN_CMD array (vs nameref) -- consistent with CSM_DOCKER_ENV_FLAGS pattern"
  - "backup_restore calls ssh_write_config after container start -- mirrors docker_start_instance orchestration"
  - "Type-aware post-restore UX copies menu_action_start pattern exactly -- consistent user experience"

patterns-established:
  - "_docker_build_run_cmd as single source of truth: both docker_run_instance and backup_restore call it"
  - "Restore completeness: stop -> load image -> restore workspace -> build cmd -> run -> ssh_write_config"

requirements-completed: [BACK-03, BACK-04, MCP-01, INST-02]

# Metrics
duration: 4min
completed: 2026-03-14
---

# Phase 7 Plan 01: Backup Restore Integration Summary

**_docker_build_run_cmd shared helper eliminates restore flag drift -- restored containers now receive identical security, resource, GUI, MCP, and credential configuration as freshly created containers**

## Performance

- **Duration:** 4 min
- **Started:** 2026-03-14T18:02:59Z
- **Completed:** 2026-03-14T18:06:56Z
- **Tasks:** 2
- **Files modified:** 5

## Accomplishments
- Extracted `_docker_build_run_cmd()` helper that is the single source of truth for docker run command construction
- Refactored `backup_restore` to call the shared helper -- eliminates duplicated flag array and "keep in sync" comments
- Added `ssh_write_config` call after restore so SSH alias works immediately without manual intervention
- `credentials_get_docker_env_flags` now receives instance name in restore path -- MCP/RC env vars injected correctly
- GUI containers restored with VNC port mapping and `--shm-size=512m` (previously missing)
- `menu_action_restore` now shows type-aware prompt (browser for GUI, SSH for CLI) matching `menu_action_start` UX

## Task Commits

Each task was committed atomically:

1. **TDD RED: Failing tests for _docker_build_run_cmd and restore fixes** - `24c3658` (test)
2. **Task 1: Extract _docker_build_run_cmd and refactor callers** - `d03b968` (feat)
3. **Task 2: Type-aware post-restore UX** - `f249876` (feat)

_Note: TDD task has separate test commit (RED) followed by implementation commit (GREEN)_

## Files Created/Modified
- `lib/docker.sh` - Added `_docker_build_run_cmd()` helper; refactored `docker_run_instance()` to delegate to it
- `lib/backup.sh` - Replaced duplicated docker run command in `backup_restore` with `_docker_build_run_cmd` call; added `ssh_write_config`; updated function comment
- `lib/menu.sh` - Added type-aware post-restore UX in `menu_action_restore` using `instances_get_type`
- `tests/docker.bats` - Added 4 new tests for `_docker_build_run_cmd` helper
- `tests/backup.bats` - Updated setup to source docker.sh/settings.sh/instances.sh; added mocks for ssh_write_config and instance name tracking; added 4 new restore tests

## Decisions Made
- `_docker_build_run_cmd` uses `_DOCKER_RUN_CMD` global array (consistent with existing `CSM_DOCKER_ENV_FLAGS` pattern)
- Placed `_docker_build_run_cmd` directly above `docker_run_instance` to emphasize the relationship
- `backup_restore` calls `ssh_write_config` after the run (not before), matching `docker_start_instance` orchestration order

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] backup.bats setup ordering: mocks overwritten by lib sourcing**
- **Found during:** Task 1 (TDD RED phase)
- **Issue:** Original backup.bats only sourced common.sh and backup.sh. New setup sources instances.sh which re-defines instances_get_port/type, overwriting the mocks exported before sourcing.
- **Fix:** Added post-source mock re-export block at end of setup() to restore mock behavior after library sourcing.
- **Files modified:** tests/backup.bats
- **Verification:** All 18 backup tests pass including pre-existing test 2 (metadata port check)
- **Committed in:** 24c3658 (RED test commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug in test setup ordering)
**Impact on plan:** Test infrastructure fix required for test harness correctness. No scope creep.

## Issues Encountered
- Mock ordering in backup.bats setup: sourcing libs after defining mocks caused mock functions to be overwritten. Resolved by re-exporting mocks after all lib sources. Classic BATS setup pattern issue.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Backup/restore end-to-end flow is now complete and correct
- Restored containers are feature-equivalent to freshly created ones
- All 159 tests pass with no regressions
- Phase 07 complete -- no remaining plans in this phase

## Self-Check: PASSED

- lib/docker.sh: FOUND
- lib/backup.sh: FOUND
- lib/menu.sh: FOUND
- 07-01-SUMMARY.md: FOUND
- Commits 24c3658, d03b968, f249876: ALL FOUND
- _docker_build_run_cmd in docker.sh: FOUND
- _docker_build_run_cmd in backup.sh: FOUND

---
*Phase: 07-backup-restore-integration*
*Completed: 2026-03-14*
