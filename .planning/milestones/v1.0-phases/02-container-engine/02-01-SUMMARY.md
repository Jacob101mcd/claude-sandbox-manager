---
phase: 02-container-engine
plan: 01
subsystem: infra
tags: [bash, docker, credentials, env-parsing, gh-cli, claude-code]

# Dependency graph
requires:
  - phase: 01-foundation
    provides: lib/common.sh message helpers, BATS test infrastructure, Dockerfile base
provides:
  - lib/credentials.sh with .env parsing and docker env flag generation
  - Dockerfile with native Claude Code installer and GitHub CLI
  - .env gitignored for credential safety
affects: [02-container-engine, credential-injection, container-builds]

# Tech tracking
tech-stack:
  added: [gh-cli, claude-native-installer]
  patterns: [env-file-parsing, runtime-credential-injection]

key-files:
  created: [lib/credentials.sh, tests/credentials.bats]
  modified: [scripts/Dockerfile, .gitignore]

key-decisions:
  - "Native installer via curl pipe bash -- replaces NPM global install for Claude Code"
  - "Credentials never in image layers -- runtime injection only via docker -e flags"
  - "msg_warn for missing credentials -- non-blocking warnings, not fatal errors"

patterns-established:
  - "Credential module pattern: credentials_* prefix, CSM_ROOT guard, export for subprocesses"
  - "Docker env flags via global array CSM_DOCKER_ENV_FLAGS populated by function"

requirements-completed: [CONT-01, INST-01, CRED-01, CRED-02, CRED-03, CRED-04]

# Metrics
duration: 2min
completed: 2026-03-13
---

# Phase 02 Plan 01: Credentials + Dockerfile Summary

**Bash .env parser with quote stripping and template creation, plus Dockerfile overhauled to native Claude Code installer and gh CLI from official apt repo**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-13T18:47:21Z
- **Completed:** 2026-03-13T18:49:14Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- lib/credentials.sh with 3 exported functions: credentials_load, credentials_ensure_env_file, credentials_get_docker_env_flags
- 9 BATS tests covering .env parsing, quote stripping, comments, missing file, docker -e flag generation
- Dockerfile uses native installer (curl claude.ai/install.sh) instead of npm install
- GitHub CLI installed from official apt repository with signed keyring
- No credentials baked into Docker image layers (CRED-04 compliance)

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/credentials.sh with .env parsing and tests** - `05f2f34` (feat) - TDD: red then green
2. **Task 2: Overhaul Dockerfile with native installer and gh CLI** - `73ce2e4` (feat)

## Files Created/Modified
- `lib/credentials.sh` - .env parsing, credential loading, docker env flag generation
- `tests/credentials.bats` - 9 unit tests for credential module
- `scripts/Dockerfile` - Native installer, gh CLI, optimized layer ordering
- `.gitignore` - Added .env to prevent credential leaks

## Decisions Made
- Native installer via curl pipe bash replaces NPM global install -- more reliable per research findings
- Credentials are never in image layers -- runtime injection only via docker -e flags (CRED-04)
- msg_warn for missing credentials -- non-blocking so container creation continues without all credentials

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered
None

## User Setup Required
None - no external service configuration required.

## Next Phase Readiness
- credentials.sh ready to be wired into docker.sh (Plan 02 will integrate credential injection into container start)
- Dockerfile ready for building with new installer approach
- All 42 existing tests still pass (no regressions)

---
*Phase: 02-container-engine*
*Completed: 2026-03-13*
