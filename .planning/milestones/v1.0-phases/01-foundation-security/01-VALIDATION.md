---
phase: 1
slug: foundation-security
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
validated: 2026-03-14
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash + ShellCheck (linting) + BATS (Bash Automated Testing System) |
| **Config file** | none |
| **Quick run command** | `npx shellcheck bin/csm lib/*.sh` |
| **Full suite command** | `npx shellcheck bin/csm lib/*.sh && bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `npx shellcheck bin/csm lib/*.sh`
- **After every plan wave:** Run `npx shellcheck bin/csm lib/*.sh && bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Requirement | Test Type | Automated Command | File | Status |
|---------|------|-------------|-----------|-------------------|------|--------|
| 1-01-01 | 01 | QUAL-04 | lint | `npx shellcheck bin/csm lib/*.sh` | ✅ | ✅ green |
| 1-01-02 | 01 | PLAT-04 | unit | `bats tests/platform.bats` | ✅ | ✅ green |
| 1-01-03 | 01 | BUG-01 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 1-01-04 | 01 | BUG-02 | unit | `bats tests/instances.bats` | ✅ | ✅ green |
| 1-01-05 | 01 | SEC-01 | unit | `bats tests/dockerfile.bats` | ✅ | ✅ green |
| 1-03-01 | 03 | SEC-02 | unit | `bats tests/security.bats` | ✅ | ✅ green |
| 1-03-02 | 03 | SEC-03 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 1-03-03 | 03 | SEC-04 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 1-03-04 | 03 | QUAL-03 | unit | `bats tests/ssh.bats` | ✅ | ✅ green |
| 1-04-01 | 04 | PLAT-01 | smoke | `bats tests/platform.bats` | ✅ | ✅ green |
| 1-04-02 | 04 | PLAT-02 | unit | `bats tests/menu.bats` | ✅ | ✅ green |
| 1-04-03 | 04 | QUAL-02 | lint | `npx shellcheck bin/csm lib/*.sh` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Windows PS scripts unchanged | PLAT-03 | Cannot run PS on Linux CI | Verify no changes to `scripts/*.ps1` via `git diff` |
| Modular structure | QUAL-01 | Architectural check | Verify `lib/*.sh` files exist and are sourced from `bin/csm` |

---

## Validation Sign-Off

- [x] All tasks have automated verify commands
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] All MISSING references resolved
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete

---

## Validation Audit 2026-03-14

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 3 |
| Escalated | 0 |

**Tests added:**
- `tests/platform.bats` — 10 tests added (PLAT-01: bin/csm smoke tests)
- `tests/menu.bats` — 10 tests added (PLAT-02: menu dispatch tests)
- `tests/ssh.bats` — 16 tests created (QUAL-03: SSH key/config management)
