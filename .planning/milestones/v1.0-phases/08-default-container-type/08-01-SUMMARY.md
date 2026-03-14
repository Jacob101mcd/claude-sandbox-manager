---
phase: 08-default-container-type
plan: 01
subsystem: settings
tags: [bash, bats, settings, menu, container-type, preferences]

# Dependency graph
requires:
  - phase: 06-settings-documentation
    provides: settings.sh with settings_get, settings_set, settings_ensure_config_file
  - phase: 05-integration-layer
    provides: menu.sh with menu_select_container_type and menu_action_new
provides:
  - Null factory default for container_type (JSON null, not string)
  - Null-aware cycle: null->cli->gui->cli in _settings_cycle_container_type
  - Human-readable preference labels: Ask each time / Minimal CLI / GUI Desktop
  - Auto-skip in menu_select_container_type when default is set
  - Interactive prompt preserved when default is null
affects: [menu.sh, settings.sh, any caller of menu_select_container_type]

# Tech tracking
tech-stack:
  added: []
  patterns:
    - Stderr-only auto-skip message so command substitution captures only the type string
    - case statement for null-aware value cycling
    - Human-readable label mapping at display layer, raw values stored internally

key-files:
  created: []
  modified:
    - lib/settings.sh
    - lib/menu.sh
    - tests/settings.bats
    - tests/menu.bats

key-decisions:
  - "defaults.container_type factory default changed from 'cli' string to JSON null — distinguishes 'user has not chosen' from explicit selection"
  - "Auto-skip message written to stderr only — command substitution in menu_action_new captures only the type string, avoids menu display corruption"
  - "Cycle has no path back to null — once set, user must re-enter preferences to cycle through cli/gui"

patterns-established:
  - "stderr for informational auto-skip messages, stdout for data only"
  - "null check in menu functions via [[ -n ]] on settings_get return value"

requirements-completed: [SETT-01, SETT-04]

# Metrics
duration: 7min
completed: 2026-03-14
---

# Phase 8 Plan 01: Default Container Type Summary

**Null factory default for container_type wires Preferences -> container creation: auto-skip when set, interactive prompt when null**

## Performance

- **Duration:** 7 min
- **Started:** 2026-03-14T18:30:00Z
- **Completed:** 2026-03-14T18:37:00Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- Changed `defaults.container_type` factory default from string "cli" to JSON null, closing the "all new users implicitly want CLI" assumption
- Updated `_settings_cycle_container_type` with case statement handling null/empty -> cli -> gui -> cli
- Updated `_settings_show_preferences_menu` to display human-readable labels (Ask each time / Minimal CLI / GUI Desktop) instead of raw values
- Updated `menu_select_container_type` to auto-skip with a plain-text stderr message when a default is set, falling back to interactive prompt when null

## Task Commits

Each task was committed atomically via TDD (RED then GREEN):

1. **Task 1 RED: failing tests for null default, cycle, display labels** - `8c5eb55` (test)
2. **Task 1 GREEN: null factory default, null-aware cycle, human-readable labels** - `4ab049a` (feat)
3. **Task 2 RED: failing tests for menu auto-skip** - `74feacc` (test)
4. **Task 2 GREEN: auto-skip container type selection when default is set** - `bfe0c4b` (feat)

_TDD tasks have separate test and feat commits._

## Files Created/Modified
- `lib/settings.sh` - Null factory default, case-based cycle, label mapping in preferences display
- `lib/menu.sh` - Auto-skip logic using settings_get, stderr message, interactive fallback
- `tests/settings.bats` - Updated null assertion + 7 new tests (cycle and label tests)
- `tests/menu.bats` - Sources settings.sh in setup + 4 new auto-skip tests

## Decisions Made
- Changed factory default to JSON null rather than keeping "cli" and adding a special "ask" sentinel string — null is the natural representation of "not set" in JSON and avoids sentinel value complexity
- Auto-skip message uses plain ASCII "->" not unicode to match existing CSM ASCII-art style
- Stderr-only for auto-skip message so `container_type="$(menu_select_container_type)"` in menu_action_new captures only the type string without arrow text

## Deviations from Plan

None - plan executed exactly as written. The only minor structural addition was sourcing `settings.sh` in menu.bats setup (Rule 3 pattern — settings_get is now a dependency of menu_select_container_type) which was anticipated by the plan's note to "verify by checking the test setup block."

## Issues Encountered
None. Full 169-test suite passes with zero regressions.

## Next Phase Readiness
- Preferences -> container creation link is complete
- menu_action_new already calls menu_select_container_type via command substitution — the auto-skip works end-to-end without any change to menu_action_new
- Phase 8 plan 01 is the only plan in this phase — phase is complete

---
*Phase: 08-default-container-type*
*Completed: 2026-03-14*
