---
phase: 3
slug: backup-data-safety
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
updated: 2026-03-14
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
| 3-01-01 | 01 | 0 | BACK-01 | unit | `bats tests/backup.bats` | ✅ | ✅ green |
| 3-01-02 | 01 | 0 | BACK-02 | unit | `bats tests/backup.bats` | ✅ | ✅ green |
| 3-01-03 | 01 | 0 | BACK-03 | unit | `bats tests/backup.bats` | ✅ | ✅ green |
| 3-01-04 | 01 | 0 | BACK-04 | unit | `bats tests/backup.bats` | ✅ | ✅ green |
| 3-02-01 | 02 | 1 | BACK-02 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 3-02-02 | 02 | 1 | BACK-02 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 3-02-03 | 02 | 1 | BACK-01/BACK-04 | unit | `bats tests/menu.bats` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/backup.bats` — test stubs for BACK-01 through BACK-04
- [x] Docker mocking strategy — use function override pattern (override docker commit/save/load in test setup)

*Existing BATS infrastructure from Phase 1-2 covers test framework setup.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Post-restore SSH prompt works interactively | BACK-04 | Requires TTY interaction | After restore, verify "SSH into instance now?" prompt appears and responds to y/N |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** 2026-03-14 — all gaps filled, 213/213 tests pass

---

## Validation Audit 2026-03-14

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 3 |
| Escalated | 0 |

**Note:** Implementation uses `settings_get_bool '.backup.auto_backup'` (config file) rather than raw `CSM_AUTO_BACKUP` env var. The config approach subsumes the env var via migration in `settings_ensure_config_file`. Tests written against actual implementation.
