---
phase: 06-settings-documentation
plan: "01"
subsystem: settings
tags: [settings, config, menu, validation, tdd]
dependency_graph:
  requires: []
  provides:
    - lib/settings.sh
    - csm-config.json auto-creation
    - [P] Preferences interactive menu
    - instance name strict validation
  affects:
    - lib/docker.sh
    - lib/credentials.sh
    - lib/backup.sh
    - lib/menu.sh
    - bin/csm
tech_stack:
  added: []
  patterns:
    - jq atomic write via tmp+mv (extended to new settings module)
    - settings_get_bool uses type() check instead of // to avoid false-as-absent
    - Module guard pattern [[ -n "${CSM_ROOT:-}" ]]
key_files:
  created:
    - lib/settings.sh
    - tests/settings.bats
  modified:
    - lib/docker.sh
    - lib/credentials.sh
    - lib/backup.sh
    - lib/menu.sh
    - bin/csm
    - .gitignore
    - tests/docker.bats
    - tests/security.bats
decisions:
  - "settings_get_bool uses jq type() check instead of has() for nested paths — simpler expression handles any depth"
  - "settings.sh sourced before credentials.sh in bin/csm — credentials.sh calls settings_get for mcp_port"
  - "Auto-backup credentials_load removed from docker_start_instance — no longer needed now that settings_get_bool reads config directly"
metrics:
  duration: "3m29s"
  completed_date: "2026-03-14"
  tasks_completed: 2
  files_changed: 9
---

# Phase 6 Plan 1: Settings Module and Caller Integration Summary

**One-liner:** JSON config file (csm-config.json) with full CRUD functions, .env migration, interactive [P] Preferences menu, and config-driven resource limits replacing all hardcoded values.

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 (TDD RED) | Failing tests for settings module | d755df3 | tests/settings.bats |
| 1 (TDD GREEN) | Create lib/settings.sh | 200b8dc | lib/settings.sh, .gitignore |
| 2 | Integrate settings into all callers | 13bb476 | lib/docker.sh, lib/credentials.sh, lib/backup.sh, lib/menu.sh, bin/csm, tests/docker.bats, tests/security.bats |

## What Was Built

### lib/settings.sh (new module, 262 lines)

- `settings_ensure_config_file()` — auto-creates csm-config.json with locked schema on first run; migrates `CSM_AUTO_BACKUP=1` and `CSM_MCP_PORT` from .env with `msg_warn` notification
- `settings_get()` — reads any dotted jq path, returns empty string for missing keys
- `settings_get_bool()` — reads boolean fields using `type()` check to avoid `false // default` pitfall
- `settings_set()` — atomic write via tmp+mv; uses `--argjson` for bool/number, `--arg` for string to preserve JSON types
- `settings_menu()` — interactive preferences sub-menu: auto-backup toggle, container type cycle, memory/cpu/port free-text with validation
- Validation helpers: `_settings_validate_port` (1024-65535), `_settings_validate_memory` (docker format), `_settings_validate_cpu` (positive number)

### Caller Integration

- **bin/csm**: sources settings.sh after common.sh, before credentials.sh; calls `settings_ensure_config_file` in startup block
- **lib/docker.sh** `docker_run_instance()`: `--memory` and `--cpus` now read from config with `${val:-default}` fallback
- **lib/docker.sh** `docker_start_instance()`: auto-backup reads from `settings_get_bool '.backup.auto_backup'`; removed `credentials_load` call that existed only for `CSM_AUTO_BACKUP`
- **lib/credentials.sh** `credentials_get_docker_env_flags()`: `CSM_MCP_PORT` reads from `settings_get '.integrations.mcp_port'`
- **lib/backup.sh** `backup_restore()`: resource limits read from config (mirroring docker_run_instance)
- **lib/menu.sh** `menu_show_actions()`: `[P] Preferences` added between `[E]` and `[Q]`
- **lib/menu.sh** `menu_main()`: `p) settings_menu ;;` dispatch added
- **lib/menu.sh** `menu_action_new()`: silent `tr -cd` sanitization replaced with regex validation `^[a-z0-9][a-z0-9-]{2,8}[a-z0-9]$` with clear error message

### Tests

- **tests/settings.bats** (37 tests): covers all settings functions and validation helpers
- **tests/docker.bats**: updated 2 grep tests to match config-driven pattern; added settings.sh to setup source order
- **tests/security.bats**: updated 2 grep tests to match config-driven pattern

**Full suite result:** 151/151 tests pass.

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 1 - Bug] Updated grep tests in docker.bats and security.bats**
- **Found during:** Task 2 verification (full suite run)
- **Issue:** `tests/docker.bats` and `tests/security.bats` had `grep -q 'memory=2g'` and `grep -q 'cpus=2'` checks that tested the hardcoded strings we intentionally replaced. Tests also did not source settings.sh in their setup, so functional tests calling `docker_run_instance` failed with `settings_get: command not found`.
- **Fix:** Updated grep tests to check for `settings_get.*memory_limit` / `settings_get.*cpu_limit`; added `source settings.sh` to docker.bats setup block.
- **Files modified:** tests/docker.bats, tests/security.bats
- **Commit:** 13bb476 (included in Task 2 commit)

**2. [Rule 2 - Missing] settings_get_bool uses type() instead of has() for nested paths**
- **Found during:** Task 1 implementation
- **Issue:** The research document showed `has("backup") and (.backup | has("auto_backup"))` for nested path checking. For a simple top-level `has()` this works, but for arbitrary dotted paths passed as parameters (like `.backup.auto_backup`) a single `has()` expression is not straightforward. Using `jq -r "if (${jq_path} | type) == \"boolean\" then ${jq_path} else false end"` is simpler and handles any nesting depth.
- **Fix:** Implemented `settings_get_bool` with `type()` comparison instead of `has()` chains.
- **Files modified:** lib/settings.sh
- **Commit:** 200b8dc

## Self-Check: PASSED

- lib/settings.sh: FOUND
- tests/settings.bats: FOUND
- 06-01-SUMMARY.md: FOUND
- Commit d755df3 (TDD RED): FOUND
- Commit 200b8dc (TDD GREEN): FOUND
- Commit 13bb476 (Task 2): FOUND
