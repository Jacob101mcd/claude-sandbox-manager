---
phase: 8
slug: default-container-type
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-14
---

# Phase 8 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (bats-core) |
| **Config file** | none — tests sourced directly |
| **Quick run command** | `~/.local/bin/bats tests/settings.bats tests/menu.bats` |
| **Full suite command** | `~/.local/bin/bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `~/.local/bin/bats tests/settings.bats tests/menu.bats`
- **After every plan wave:** Run `~/.local/bin/bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 08-01-01 | 01 | 1 | SETT-01 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ (update) | ⬜ pending |
| 08-01-02 | 01 | 1 | SETT-01 | unit | `~/.local/bin/bats tests/settings.bats` | ✅ (new) | ⬜ pending |
| 08-01-03 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/menu.bats` | ✅ (new) | ⬜ pending |
| 08-01-04 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/menu.bats` | ✅ (new) | ⬜ pending |
| 08-01-05 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/menu.bats` | ✅ (update) | ⬜ pending |
| 08-01-06 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/settings.bats` | ❌ W0 | ⬜ pending |
| 08-01-07 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/settings.bats` | ❌ W0 | ⬜ pending |
| 08-01-08 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/settings.bats` | ❌ W0 | ⬜ pending |
| 08-01-09 | 01 | 1 | SETT-04 | unit | `~/.local/bin/bats tests/settings.bats` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/settings.bats` — new tests for cycle behavior (SETT-04) and null display labels
- [ ] `tests/menu.bats` — new tests for auto-skip behavior (SETT-04)
- [ ] `tests/settings.bats` — update existing test line 45-49: assert null not "cli"

*Existing test infrastructure covers all other phase requirements.*

---

## Manual-Only Verifications

*All phase behaviors have automated verification.*

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
