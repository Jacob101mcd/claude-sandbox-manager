---
phase: 01-foundation-security
plan: 04
subsystem: platform
tags: [bash, menu, cli, interactive, entry-point]

requires:
  - phase: 01-02
    provides: "Core library modules (common, platform, instances)"
  - phase: 01-03
    provides: "Docker and SSH modules for container lifecycle"
provides:
  - "bin/csm executable entry point for Linux/macOS"
  - "Interactive menu with instance management (start/stop/new/remove)"
  - "Complete wiring of all lib/*.sh modules into runnable CLI tool"
affects: [phase-2-container-engine, phase-6-settings]

tech-stack:
  added: []
  patterns:
    - "Entry point owns set -euo pipefail and sources all lib modules in dependency order"
    - "Menu loop with clear/redraw pattern matching PowerShell UX"
    - "Instance selection auto-picks when only one exists"

key-files:
  created:
    - bin/csm
    - lib/menu.sh
  modified: []

key-decisions:
  - "Auto-create default instance when none exist, matching PowerShell behavior"
  - "Menu actions are case-insensitive single-character dispatch (S/T/N/R/Q)"
  - "SSH prompt offered after start/new actions for immediate container access"

patterns-established:
  - "bin/csm sources all modules then runs startup checks (platform_detect, platform_check_dependencies, docker_check_running) before menu_main"
  - "Instance name sanitization: tr -cd 'a-z0-9-' before registry operations"

requirements-completed: [PLAT-01, PLAT-02, PLAT-03]

duration: 3min
completed: 2026-03-13
---

# Phase 1 Plan 4: Interactive Menu + Entry Point Summary

**Interactive menu (menu.sh) with S/T/N/R/Q actions and bin/csm entry point wiring all modules into a runnable CLI tool**

## Performance

- **Duration:** 3 min
- **Started:** 2026-03-13T17:47:00Z
- **Completed:** 2026-03-13T17:51:00Z
- **Tasks:** 2 (1 auto + 1 human-verify checkpoint)
- **Files modified:** 2

## Accomplishments
- Created bin/csm entry point that sources all lib modules and runs platform/Docker startup checks
- Built interactive menu matching the PowerShell manager UX with instance listing, colored output, and action dispatch
- Menu supports Start, Stop, New, Remove, and Quit with case-insensitive input
- Auto-creates "default" instance when none exist
- SSH prompt after start/new for immediate container access
- All ShellCheck clean, all 33 BATS tests pass, Windows scripts unchanged

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/menu.sh interactive menu and bin/csm entry point** - `db492b2` (feat)
2. **Task 2: Verify interactive menu works on Linux** - checkpoint:human-verify (approved)

## Files Created/Modified
- `bin/csm` (29 lines) - Main entry point; sources all lib modules, runs startup checks, launches menu
- `lib/menu.sh` (240 lines) - Interactive menu loop with header, instance display, action dispatch, instance selection

## Decisions Made
- Auto-create "default" instance when registry is empty, matching PowerShell manager behavior
- Menu actions use single-character case-insensitive dispatch (S/T/N/R/Q)
- SSH prompt offered after both start and new actions for immediate container access
- Instance name sanitization strips all characters except lowercase alphanumerics and hyphens

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Phase 1 (Foundation + Security) is now complete with all 4 plans executed
- bin/csm entry point is ready for Phase 2 enhancements (container engine, credential injection)
- Module architecture supports extension without modifying existing files
- All PLAT-01/02/03 requirements satisfied

## Self-Check: PASSED

All files and commits verified.

---
*Phase: 01-foundation-security*
*Completed: 2026-03-13*
