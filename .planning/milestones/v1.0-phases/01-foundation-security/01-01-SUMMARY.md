---
phase: 01-foundation-security
plan: 01
subsystem: infra, testing
tags: [dockerfile, bats, shellcheck, security, sudo, dockerignore]

requires:
  - phase: none
    provides: first plan in project
provides:
  - Secured Dockerfile with passwordless sudo (no hardcoded passwords)
  - BATS test infrastructure with test_helper.bash
  - Security test suite (dockerfile.bats, security.bats)
  - .dockerignore for optimized build context
  - ShellCheck available via npx
affects: [01-02, 01-03, 01-04, all-future-plans]

tech-stack:
  added: [bats-core 1.13.0, shellcheck 0.11.0 (via npm)]
  patterns: [BATS test files in tests/, test_helper.bash for project root resolution]

key-files:
  created:
    - tests/test_helper.bash
    - tests/dockerfile.bats
    - tests/security.bats
    - .dockerignore
  modified:
    - scripts/Dockerfile
    - .gitignore

key-decisions:
  - "Installed BATS locally (~/.local/bin) since no sudo access available"
  - "Installed ShellCheck via npm devDependency since no sudo for apt-get"
  - "Added node_modules, package.json, package-lock.json to .gitignore for npm tooling artifacts"

patterns-established:
  - "BATS tests: load test_helper, use $CSM_ROOT for project root"
  - "Security tests: skip guard with [[ -f file ]] || skip for files not yet created"

requirements-completed: [SEC-01, QUAL-02, QUAL-04]

duration: 2min
completed: 2026-03-13
---

# Phase 1 Plan 01: Dockerfile Security + Test Infrastructure Summary

**Hardened Dockerfile with passwordless sudo, BATS/ShellCheck test tooling, and .dockerignore for optimized builds**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-13T17:36:16Z
- **Completed:** 2026-03-13T17:38:43Z
- **Tasks:** 2
- **Files modified:** 6

## Accomplishments
- Removed hardcoded password from Dockerfile, replaced with sudoers.d NOPASSWD configuration (SEC-01)
- Set up BATS test framework with 3 passing dockerfile tests and 5 skip-guarded security tests
- Created .dockerignore to exclude workspaces/, backups/, ssh/, .git/, .planning/ from build context
- ShellCheck available for future shell script linting

## Task Commits

Each task was committed atomically:

1. **Task 1: Install test tooling and create BATS test infrastructure** - `62d6406` (test)
2. **Task 2: Harden Dockerfile and create .dockerignore** - `fc7e5ba` (feat)

## Files Created/Modified
- `tests/test_helper.bash` - BATS helper setting CSM_ROOT project root
- `tests/dockerfile.bats` - Security tests for Dockerfile (no hardcoded password, NOPASSWD sudo)
- `tests/security.bats` - Placeholder tests for lib/docker.sh security hardening (all skip)
- `.dockerignore` - Build context exclusions for Docker
- `scripts/Dockerfile` - Replaced insecure chpasswd with sudoers.d NOPASSWD
- `.gitignore` - Added node_modules, package.json, package-lock.json

## Decisions Made
- Installed BATS locally to ~/.local/bin since sudo not available in this environment
- Installed ShellCheck as npm devDependency (npx shellcheck) since apt-get requires sudo
- Added npm artifacts to .gitignore to keep repo clean

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 3 - Blocking] Local BATS installation instead of system-wide**
- **Found during:** Task 1
- **Issue:** No sudo access available, cannot run `sudo apt-get install` or `sudo ./install.sh /usr/local`
- **Fix:** Installed BATS to ~/.local/bin and ShellCheck via npm devDependency
- **Files modified:** .gitignore (added node_modules, package.json, package-lock.json)
- **Verification:** `bats --version` returns 1.13.0, `npx shellcheck --version` returns 0.11.0
- **Committed in:** 62d6406 (Task 1 commit)

---

**Total deviations:** 1 auto-fixed (1 blocking)
**Impact on plan:** Installation method changed but tools function identically. No scope creep.

## Issues Encountered
- Pre-existing test files (instances.bats, platform.bats, common.bats) fail due to missing lib/ files -- these are from future plans and out of scope

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- BATS test infrastructure ready for all subsequent plans to add tests
- Dockerfile secured, ready for Docker build operations in Plan 03
- .dockerignore in place for optimized builds
- ShellCheck ready for linting shell scripts created in Plans 02-04

---
*Phase: 01-foundation-security*
*Completed: 2026-03-13*
