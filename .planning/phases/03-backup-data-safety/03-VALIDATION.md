---
phase: 3
slug: backup-data-safety
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 3 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (Bash Automated Testing System) |
| **Config file** | none — tests run via `bats tests/` |
| **Quick run command** | `bats tests/backup.bats` |
| **Full suite command** | `bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats tests/backup.bats`
- **After every plan wave:** Run `bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 3-01-01 | 01 | 0 | BACK-01 | unit | `bats tests/backup.bats -f "backup_create"` | ❌ W0 | ⬜ pending |
| 3-01-02 | 01 | 0 | BACK-02 | unit | `bats tests/backup.bats -f "auto.backup"` | ❌ W0 | ⬜ pending |
| 3-01-03 | 01 | 0 | BACK-03 | unit | `bats tests/backup.bats -f "captures both"` | ❌ W0 | ⬜ pending |
| 3-01-04 | 01 | 0 | BACK-04 | unit | `bats tests/backup.bats -f "backup_restore"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/backup.bats` — test stubs for BACK-01 through BACK-04
- [ ] Docker mocking strategy — use function override pattern (override docker commit/save/load in test setup)

*Existing BATS infrastructure from Phase 1-2 covers test framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Post-restore SSH prompt works interactively | BACK-04 | Requires TTY interaction | After restore, verify "SSH into instance now?" prompt appears and responds to y/N |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
