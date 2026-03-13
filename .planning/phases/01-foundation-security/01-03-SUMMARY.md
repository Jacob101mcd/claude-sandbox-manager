---
phase: 01-foundation-security
plan: 03
subsystem: infra
tags: [bash, docker, ssh, security, ed25519, shellcheck, bats]

requires:
  - phase: 01-foundation-security (plan 02)
    provides: common.sh helpers, instances.sh registry CRUD
provides:
  - "lib/docker.sh with hardened container build/run/stop/remove operations"
  - "lib/ssh.sh with ed25519 key generation, build staging, SSH config management"
  - "Full security hardening: localhost-only SSH, 7 cap-drops, memory/CPU limits, no-new-privileges"
  - "docker_start_instance orchestrator for complete instance lifecycle"
affects: [01-04, phase-2, phase-3]

tech-stack:
  added: [ssh-keygen, docker-security-flags]
  patterns: [bash-array-command-building, ssh-config-block-parsing, build-staging-directory]

key-files:
  created:
    - lib/docker.sh
    - lib/ssh.sh
    - tests/docker.bats
  modified:
    - tests/security.bats

key-decisions:
  - "Docker run command built as Bash array for safe argument handling"
  - "SSH config blocks parsed line-by-line for clean removal/replacement"
  - "Build staging dir (_build_ssh/) cleaned and recreated each build for deterministic state"

patterns-established:
  - "Module prefix naming: docker_, ssh_ (consistent with common_, platform_, instances_)"
  - "Orchestrator function pattern: docker_start_instance chains lower-level operations"
  - "Security-as-code: all hardening flags in docker_run_instance array, easily auditable"

requirements-completed: [SEC-02, SEC-03, SEC-04, QUAL-02, QUAL-03]

duration: 2min
completed: 2026-03-13
---

# Phase 1 Plan 3: Docker and SSH Modules Summary

**Security-hardened Docker operations (localhost SSH, 7 cap-drops, resource limits) and ed25519 SSH key lifecycle management with config block parsing**

## Performance

- **Duration:** 2 min
- **Started:** 2026-03-13T17:42:21Z
- **Completed:** 2026-03-13T17:43:50Z
- **Tasks:** 2
- **Files modified:** 4

## Accomplishments
- lib/ssh.sh provides full SSH key lifecycle: generate ed25519 keys, stage for Docker build, write/remove SSH config blocks
- lib/docker.sh implements all security hardening: SSH bound to 127.0.0.1 (SEC-02), 7 capabilities dropped (SEC-03), memory/CPU limits and no-new-privileges (SEC-04)
- docker_start_instance orchestrates the complete flow: keys -> staging -> port allocation -> build -> run -> SSH config
- Container removal before recreation prevents orphaned containers (BUG-01)
- All 13 BATS tests pass, ShellCheck clean on both modules

## Task Commits

Each task was committed atomically:

1. **Task 1: Create lib/ssh.sh** - `a947d48` (feat)
2. **Task 2: Create lib/docker.sh with tests** - `0fd2d4b` (feat)

## Files Created/Modified
- `lib/ssh.sh` - SSH key generation, build staging, config block management
- `lib/docker.sh` - Docker build/run/stop/remove with full security hardening
- `tests/docker.bats` - 8 tests verifying all security flags and BUG-01 fix
- `tests/security.bats` - 5 tests with skip guards removed (docker.sh now exists)

## Decisions Made
- Docker run command built as Bash array for safe argument handling (avoids quoting issues with complex flag lists)
- SSH config blocks parsed line-by-line for clean removal/replacement (no sed dependency)
- Build staging directory (_build_ssh/) cleaned and recreated each build for deterministic state

## Deviations from Plan

None - plan executed exactly as written.

## Issues Encountered

None.

## User Setup Required

None - no external service configuration required.

## Next Phase Readiness
- Docker and SSH engine modules ready for use by bin/csm CLI entry point (Plan 04)
- All foundational lib modules complete: common.sh, platform.sh, instances.sh, ssh.sh, docker.sh
- Security hardening is fully implemented and tested

## Self-Check: PASSED

All 4 created/modified files verified on disk. Both commit hashes (a947d48, 0fd2d4b) verified in git log.

---
*Phase: 01-foundation-security*
*Completed: 2026-03-13*
