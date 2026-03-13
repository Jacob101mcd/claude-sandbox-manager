---
phase: 03-backup-data-safety
plan: 02
subsystem: ui
tags: [bash, menu, backup, restore, auto-backup, docker]

# Dependency graph
requires:
  - phase: 03-01
    provides: backup_create, backup_restore, backup_list functions in lib/backup.sh
provides:
  - B/E menu keys that trigger manual backup and restore from the main menu
  - Auto-backup hook in docker_start_instance triggered by CSM_AUTO_BACKUP=1
  - backup.sh sourced in bin/csm in correct dependency order
affects:
  - any future phase that adds menu actions or modifies docker_start_instance

# Tech tracking
tech-stack:
  added: []
  patterns: [menu action functions follow select-instance -> action -> optional-ssh pattern]

key-files:
  created: []
  modified:
    - lib/menu.sh
    - lib/docker.sh
    - bin/csm

key-decisions:
  - "Auto-backup reads CSM_AUTO_BACKUP via credentials_load; silently skips when container status is not created"
  - "backup.sh sourced after docker.sh and before menu.sh: backup depends on docker functions, menu calls backup functions"

patterns-established:
  - "Menu restore action validates numeric input against _BACKUP_LISTED_DIRS array length before indexing"
  - "Destructive menu actions require YES (uppercase exact match) confirmation"

requirements-completed: [BACK-02, BACK-01, BACK-04]

# Metrics
duration: 2min
completed: 2026-03-13
---

# Phase 3 Plan 02: Backup Integration Summary

**Backup and restore wired into the main menu ([B]/[E] keys) with YES confirmation for restore, auto-backup hook in docker_start_instance for CSM_AUTO_BACKUP=1, and backup.sh sourced in correct load order**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-13T21:22:18Z
- **Completed:** 2026-03-13T21:24:12Z
- **Tasks:** 2
- **Files modified:** 3

## Accomplishments
- Added `menu_action_backup` and `menu_action_restore` to lib/menu.sh with [B]/[E] dispatch
- Restore action lists backups, validates selection, requires "YES" confirmation, calls backup_restore, offers post-restore SSH prompt
- Auto-backup in `docker_start_instance`: checks CSM_AUTO_BACKUP=1 via credentials_load, backs up running/exited containers, silently skips if not created
- Added `source "$CSM_ROOT/lib/backup.sh"` in bin/csm between docker.sh and menu.sh

## Task Commits

Each task was committed atomically:

1. **Task 1: Add menu actions for backup and restore** - `27f4bde` (feat)
2. **Task 2: Auto-backup hook and source backup.sh** - `f762892` (feat)

**Plan metadata:** (pending docs commit)

## Files Created/Modified
- `lib/menu.sh` - Added menu_action_backup, menu_action_restore, [B]/[E] in show_actions and case dispatch
- `lib/docker.sh` - Added auto-backup block in docker_start_instance after credentials_ensure_env_file
- `bin/csm` - Added source of lib/backup.sh between docker.sh and menu.sh

## Decisions Made
- Auto-backup silently skips when `docker_status` returns "not created" -- no container to back up, this is normal on first start
- Used `credentials_load || true` for auto-backup so a missing .env doesn't abort container start
- backup.sh placed after docker.sh in load order because backup_create calls docker_status; placed before menu.sh because menu calls backup_create/backup_restore

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

- `npx shellcheck bin/csm` emits SC1091 info-level warnings about unresolvable source paths -- pre-existing, not introduced by this plan. Used `--severity=error` to confirm no real errors.

## User Setup Required

None - no external service configuration required. CSM_AUTO_BACKUP=1 is set in the project .env file if desired.

## Next Phase Readiness

- Backup module fully integrated: create, list, restore accessible from menu and auto-triggered before start
- All 67 tests pass across the full suite
- Phase 03 complete: data safety feature delivered

---
*Phase: 03-backup-data-safety*
*Completed: 2026-03-13*

## Self-Check: PASSED

- SUMMARY.md: FOUND
- Task commits 27f4bde, f762892: FOUND
- menu_action_backup in lib/menu.sh: FOUND
- CSM_AUTO_BACKUP in lib/docker.sh: FOUND
- backup.sh sourced in bin/csm: FOUND
