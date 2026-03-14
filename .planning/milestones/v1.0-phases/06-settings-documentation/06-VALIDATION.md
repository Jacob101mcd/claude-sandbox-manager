---
phase: 6
slug: settings-documentation
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
validated: 2026-03-14
---

# Phase 6 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (Bash Automated Testing System) |
| **Config file** | none — test files use `load test_helper` convention |
| **Quick run command** | `~/.local/bin/bats tests/settings.bats` |
| **Full suite command** | `~/.local/bin/bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `~/.local/bin/bats tests/settings.bats`
- **After every plan wave:** Run `~/.local/bin/bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 06-01-01 | 01 | 1 | SETT-01 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-01-02 | 01 | 1 | SETT-01 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-01-03 | 01 | 1 | SETT-01 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-01-04 | 01 | 1 | SETT-01 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-02-01 | 02 | 1 | SETT-02 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-02-02 | 02 | 1 | SETT-02 | unit | `~/.local/bin/bats tests/menu.bats` | ✅ | ✅ green |
| 06-03-01 | 01 | 1 | SETT-03 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-04-01 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ | ✅ green |
| 06-05-01 | 02 | 1 | SEC-05 | smoke | `test -f SECURITY.md` | ✅ | ✅ green |
| 06-06-01 | 03 | 2 | SEC-06 | smoke | `grep -q "## Security" README.md` | ✅ | ✅ green |
| 06-07-01 | 03 | 2 | DOC-01 | smoke | `grep -q "Why I built this" README.md` | ✅ | ✅ green |
| 06-08-01 | 03 | 2 | DOC-02 | smoke | `grep -q "Who is this for" README.md` | ✅ | ✅ green |
| 06-09-01 | 03 | 2 | DOC-03 | smoke | `grep -qi "dangerously" README.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/settings.bats` — 43 tests covering config CRUD, defaults, migration, validation, menu display (SETT-01 through SETT-04)
- [x] `tests/menu.bats` — existing tests cover menu integration; `[P] Preferences` dispatch wired in lib/menu.sh
- [x] No new framework install needed — BATS already at `~/.local/bin/bats`

*Existing infrastructure (tests/settings.bats, tests/menu.bats, tests/docker.bats, tests/security.bats) covers all requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Settings menu visual layout matches existing menu style | SETT-02 | Visual/UX consistency | Run `csm`, press [P], verify layout matches main menu style |
| README reads well as narrative | DOC-01, DOC-02 | Subjective quality | Read README.md top-to-bottom, verify tone and flow |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated

---

## Validation Audit 2026-03-14

| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |

All 9 requirements have automated verification. 43 settings-specific BATS tests + 5 smoke checks for doc/security requirements. Full suite: 236/236 tests pass.
