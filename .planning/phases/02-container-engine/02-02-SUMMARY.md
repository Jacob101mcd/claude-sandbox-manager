---
phase: 02-container-engine
plan: 02
subsystem: infra
tags: [bash, docker, credentials, container-types, menu, instances]

# Dependency graph
requires:
  - phase: 02-container-engine
    plan: 01
    provides: lib/credentials.sh with .env parsing and docker env flag generation
provides:
  - Credential injection wired into docker run via -e flags
  - Container type selection menu in creation flow
  - Instance registry extended with type field and backward compat
affects: [03-ssh-access, container-management, instance-display]

# Tech tracking
tech-stack:
  added: []
  patterns: [container-type-selection, runtime-credential-injection-wiring, backward-compat-defaults]

key-files:
  created: [tests/menu.bats]
  modified: [lib/docker.sh, lib/instances.sh, lib/menu.sh, bin/csm, tests/docker.bats, tests/instances.bats, tests/test_helper.bash]

key-decisions:
  - "Container type menu shown even with only one type available -- per locked decision from research"
  - "instances_add called in menu_action_new before docker_start_instance -- type registered early, docker_start_instance skips re-add"
  - "test_helper.bash adds ~/.local/bin to PATH -- ensures jq and shellcheck available in BATS tests"

patterns-established:
  - "Container type flow: menu_select_container_type -> instances_add with type -> instances_get_type for display"
  - "Backward compat via jq // default: instances_get_type returns cli for entries without type field"

requirements-completed: [CONT-01, CONT-03, CRED-01, CRED-03, CRED-04]

# Metrics
duration: 3min
completed: 2026-03-13
---

# Phase 02 Plan 02: Container Engine Integration Summary

**Credential injection wired into docker run -e flags, container type selection menu added to creation flow, instance registry extended with type tracking and backward compat**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-13T18:51:14Z
- **Completed:** 2026-03-13T18:54:23Z
- **Tasks:** 2
- **Files modified:** 8

## Accomplishments
- docker_run_instance injects ANTHROPIC_API_KEY and GITHUB_TOKEN from .env via -e flags
- Container type selection menu appears when creating a new instance (CLI now, GUI placeholder)
- Instance registry stores and displays type field with cli default for backward compat
- bin/csm sources credentials.sh in dependency order
- Full test suite expanded to 53 tests with zero regressions

## Task Commits

Each task was committed atomically:

1. **Task 1: Wire credentials into docker.sh and extend instances.sh with type field** - `2dfce4a` (feat)
2. **Task 2: Add container type selection menu and update creation flow** - `3347837` (feat)

## Files Created/Modified
- `lib/docker.sh` - Credential injection via credentials_load + CSM_DOCKER_ENV_FLAGS in docker_run_instance; credentials_ensure_env_file in docker_start_instance
- `lib/instances.sh` - instances_add accepts type parameter; new instances_get_type with cli fallback; instances_list_with_status shows type
- `lib/menu.sh` - menu_select_container_type function; menu_action_new calls type selection and instances_add before docker_start_instance; menu_main registers default with cli type
- `bin/csm` - Sources lib/credentials.sh after common.sh
- `tests/docker.bats` - Tests for credential injection and env flag generation
- `tests/instances.bats` - Tests for type field storage, default, get_type, and backward compat
- `tests/menu.bats` - Tests for container type selection with various inputs
- `tests/test_helper.bash` - Added ~/.local/bin to PATH for jq availability

## Decisions Made
- Container type menu shown even when only CLI is available -- matches locked research decision for consistent UX
- instances_add called in menu_action_new before docker_start_instance -- docker_start_instance detects existing port and skips re-add
- test_helper.bash adds ~/.local/bin to PATH to fix jq availability in BATS test environment

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Added ~/.local/bin to PATH in test_helper.bash**
- **Found during:** Task 1 (running BATS tests)
- **Issue:** jq binary installed at ~/.local/bin/jq was not in PATH for BATS test environment, causing all jq-dependent tests to fail
- **Fix:** Added PATH augmentation in tests/test_helper.bash
- **Files modified:** tests/test_helper.bash
- **Verification:** All 53 tests pass
- **Committed in:** 2dfce4a (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Essential for test execution. No scope creep.

## Issues Encountered
None beyond the PATH fix documented above.

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- Phase 2 complete: credentials parsed, injected, type tracked, menu wired
- Ready for Phase 3 (SSH access, backups, lifecycle management)
- All 53 tests pass with full ShellCheck compliance

---
*Phase: 02-container-engine*
*Completed: 2026-03-13*
