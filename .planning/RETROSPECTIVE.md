# Project Retrospective

*A living document updated after each milestone. Lessons feed forward into future planning.*

## Milestone: v1.0 — MVP

**Shipped:** 2026-03-14
**Phases:** 8 | **Plans:** 17 | **Sessions:** ~10

### What Was Built
- Cross-platform CLI manager (`bin/csm`) with 7 modular Bash libraries
- Two container variants: minimal CLI and GUI desktop (Xfce + noVNC + Chromium)
- Full container lifecycle: create, start, stop, SSH, remove with credential injection
- Backup/restore system with auto-backup toggle, capturing container + workspace
- MCP Toolkit auto-connection and Claude Code remote control integration
- Interactive settings CLI, SECURITY.md risk analysis, comprehensive README

### What Worked
- Foundation-first phase ordering: security + platform → engine → features → integration → polish. Each phase cleanly built on the previous.
- Multi-stage Dockerfile design: base/cli/gui stages shared layers efficiently, no duplication.
- `_docker_build_run_cmd` shared helper (Phase 7): eliminated flag divergence between create and restore paths — single source of truth.
- BATS testing from Phase 1: 169 tests caught regressions early and gave confidence to refactor.
- Gap closure phases (7, 8): audit-driven phases that fixed specific E2E flow breaks were focused and effective.

### What Was Inefficient
- ROADMAP.md checkbox tracking fell out of sync with actual completion state (Phase 2 and 5 show unchecked plans despite being complete).
- SUMMARY.md `requirements_completed` frontmatter was inconsistently populated — 7 of 41 requirements verified but missing from summaries.
- Phase 3 duplicated docker run flags from docker.sh into backup.sh with a "keep in sync" comment — this was the root cause of the Phase 7 gap. Should have extracted the shared helper earlier.
- PS1 Windows manager was frozen but PLAT-03 requirement was marked complete — the requirement wording ("maintained") technically fits but creates a false sense of parity.

### Patterns Established
- Atomic jq writes via tmp file + mv for all JSON state files
- Module-prefix naming: `docker_*`, `ssh_*`, `instances_*`, `backup_*`, `settings_*`, `credentials_*`
- Auto-skip pattern: settings default → read at decision point → skip interactive prompt with stderr message
- Global array pattern: `_DOCKER_RUN_CMD`, `CSM_DOCKER_ENV_FLAGS`, `_BACKUP_LISTED_DIRS` for cross-function data
- entrypoint.sh feature detection: `command -v` for binary presence (VNC), env var for config (`CSM_MCP_ENABLED`)

### Key Lessons
1. **Extract shared helpers before duplication**: The backup_restore flag divergence (Phase 7 fix) was predictable — any time code is duplicated with a "keep in sync" comment, extract immediately.
2. **Null vs empty distinction matters for UX**: JSON null for "no opinion" vs empty string for "cleared" led to cleaner auto-skip logic (Phase 8).
3. **Audit-driven gap closure is efficient**: The milestone audit identified exactly 3 integration gaps; 2 focused phases closed them in hours rather than days.
4. **BATS tests with mock functions work well**: Source the module, re-export mock functions, test behavior — no complex test infrastructure needed.

### Cost Observations
- Model mix: ~40% opus (planning, verification), ~55% sonnet (execution, testing), ~5% haiku (quick checks)
- Sessions: ~10 across 3 days
- Notable: Phase execution averaged 2-4 minutes per plan — very fast due to clear plan specifications and BATS test-first approach

---

## Cross-Milestone Trends

### Process Evolution

| Milestone | Sessions | Phases | Key Change |
|-----------|----------|--------|------------|
| v1.0 | ~10 | 8 | Initial project — established all patterns |

### Cumulative Quality

| Milestone | Tests | Coverage | Zero-Dep Additions |
|-----------|-------|----------|-------------------|
| v1.0 | 169 BATS | Structural (no coverage tool) | 0 (jq only external dep) |

### Top Lessons (Verified Across Milestones)

1. Extract shared helpers before duplication — prevents integration gaps
2. Audit-driven gap closure phases are focused and efficient
