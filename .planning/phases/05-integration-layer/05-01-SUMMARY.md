---
phase: 05-integration-layer
plan: 01
subsystem: infra
tags: [bash, docker, mcp, instances, credentials, registry, env-flags]

# Dependency graph
requires:
  - phase: 04-gui-container-variant
    provides: instances_add with gui type and vnc_port support, docker_run_instance with type-aware flags
  - phase: 02-container-engine
    provides: credentials_get_docker_env_flags populating CSM_DOCKER_ENV_FLAGS
provides:
  - instances_add stores mcp_enabled and remote_control per instance
  - instances_get/set_mcp_enabled and instances_get/set_remote_control functions
  - credentials_get_docker_env_flags injects CSM_MCP_ENABLED, CSM_MCP_PORT, CSM_REMOTE_CONTROL
  - _docker_detect_variant detects Docker Desktop vs Linux Engine
  - docker_run_instance adds --add-host=host.docker.internal:host-gateway on Linux Engine
  - menu_action_new prompts for remote control after type selection
affects: [05-integration-layer]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - "jq has() check for boolean backward compat (false // default fires incorrectly)"
    - "Optional instance name param on credentials function for integration flag injection"
    - "docker context show/inspect for Desktop vs Engine detection"

key-files:
  created: []
  modified:
    - lib/instances.sh
    - lib/credentials.sh
    - lib/docker.sh
    - lib/menu.sh
    - tests/instances.bats
    - tests/docker.bats
    - tests/menu.bats

key-decisions:
  - "jq has() used instead of // for boolean fields to avoid false being treated as absent"
  - "credentials_get_docker_env_flags takes optional instance name; backward compat when omitted"
  - "Remote control prompt uses default N per existing locked decision"

patterns-established:
  - "Boolean JSON fields read via jq has() check not // default to handle false correctly"
  - "Integration env var injection gated on per-instance settings, not global config"

requirements-completed: [MCP-01, MCP-03, INST-02]

# Metrics
duration: 4min
completed: 2026-03-13
---

# Phase 5 Plan 1: Integration Layer - MCP and Remote Control Wiring Summary

**Per-instance mcp_enabled/remote_control registry fields, CSM_MCP_ENABLED/CSM_MCP_PORT/CSM_REMOTE_CONTROL env injection, Linux Engine --add-host detection, and remote control menu prompt**

## Performance

- **Duration:** 3m 33s
- **Started:** 2026-03-13T22:57:20Z
- **Completed:** 2026-03-13T23:00:53Z
- **Tasks:** 2
- **Files modified:** 7

## Accomplishments

- Extended instance registry schema with `mcp_enabled` (default true) and `remote_control` (default false) fields, with backward compat for legacy entries
- Updated `credentials_get_docker_env_flags` to accept an instance name and inject `CSM_MCP_ENABLED=1`, `CSM_MCP_PORT`, and `CSM_REMOTE_CONTROL=1` env vars based on per-instance settings
- Added `_docker_detect_variant` helper that checks Docker context to distinguish Desktop from Linux Engine; `docker_run_instance` conditionally adds `--add-host=host.docker.internal:host-gateway` on Linux Engine only
- Added remote control prompt in `menu_action_new` after container type selection (default N), storing the choice and showing log path info if enabled

## Task Commits

Each task was committed atomically:

1. **Task 1: Extend instance registry and credential env flags** - `5fcf9be` (feat)
2. **Task 2: Linux Engine detection, --add-host flag, and remote control menu prompt** - `b03e751` (feat)

**Plan metadata:** (see final commit)

_Note: TDD tasks - tests written first (RED), then implementation (GREEN)._

## Files Created/Modified

- `lib/instances.sh` - Added mcp_enabled/remote_control fields to instances_add; added 4 getter/setter functions; used jq has() for backward compat
- `lib/credentials.sh` - Added optional instance name param to credentials_get_docker_env_flags; injects CSM_MCP_ENABLED, CSM_MCP_PORT, CSM_REMOTE_CONTROL
- `lib/docker.sh` - Added _docker_detect_variant helper; added --add-host on Linux Engine; pass instance name to credentials_get_docker_env_flags
- `lib/menu.sh` - Added remote control prompt in menu_action_new; shows log path info if remote control enabled
- `tests/instances.bats` - 10 new tests for mcp_enabled/remote_control fields, getters, setters, backward compat
- `tests/docker.bats` - 7 new tests for MCP/RC env flags and --add-host Linux Engine detection
- `tests/menu.bats` - 2 new grep-based tests for remote control prompt in menu.sh

## Decisions Made

- **jq has() for booleans:** Used `if (.[$name] | has("field")) then value else default end` instead of `// default` because jq treats `false` as falsy, causing `false // default` to return the default. Discovered during GREEN phase when `instances_set_mcp_enabled "test" false` was not preserved.
- **Optional instance name in credentials:** Passed as `$1`, backward compat when omitted — existing callers without instance context continue working without change.
- **Remote control default N:** Per locked decision from planning, remote control is opt-in. Prompt wording clarifies it requires claude.ai account, not API key.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Fixed jq boolean // default bug in instances_get_mcp_enabled**
- **Found during:** Task 1 GREEN phase (running tests after implementing)
- **Issue:** jq `.[$name].mcp_enabled // true` incorrectly returns `true` when the stored value is `false` because jq's alternative operator treats false as absent/null
- **Fix:** Changed to `if (.[$name] | has("mcp_enabled")) then (.[$name].mcp_enabled | tostring) else "true" end` and applied same pattern to `instances_get_remote_control`
- **Files modified:** lib/instances.sh
- **Verification:** Test 26 "instances_set_mcp_enabled updates field" now passes; all 114 tests pass
- **Committed in:** 5fcf9be (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (Rule 1 - bug)
**Impact on plan:** Essential correctness fix for boolean storage/retrieval. No scope creep.

## Issues Encountered

None beyond the jq boolean bug documented above.

## User Setup Required

None - no external service configuration required.

## Self-Check: PASSED

All created/modified files exist. Both task commits (5fcf9be, b03e751) confirmed in git log.

## Next Phase Readiness

- MCP integration variables are now injected into containers via docker run
- Remote control setting stored per-instance, ready for container entrypoint to consume
- Linux Engine --add-host ensures host.docker.internal resolves inside containers
- All 114 BATS tests pass — no regressions from 07 files changed

---
*Phase: 05-integration-layer*
*Completed: 2026-03-13*
