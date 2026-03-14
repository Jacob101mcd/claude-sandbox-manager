---
phase: 4
slug: gui-container-variant
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
validated: 2026-03-14
---

# Phase 4 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (Bash Automated Testing System) |
| **Config file** | tests/test_helper.bash |
| **Quick run command** | `./node_modules/.bin/bats tests/dockerfile.bats tests/docker.bats tests/instances.bats tests/menu.bats` |
| **Full suite command** | `./node_modules/.bin/bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `./node_modules/.bin/bats tests/dockerfile.bats tests/docker.bats tests/instances.bats tests/menu.bats`
- **After every plan wave:** Run `./node_modules/.bin/bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 04-01-01 | 01 | 1 | CONT-02 | unit (grep) | `bats tests/dockerfile.bats` | ✅ | ✅ green |
| 04-01-02 | 01 | 1 | CONT-02 | unit (grep) | `bats tests/docker.bats` | ✅ | ✅ green |
| 04-01-03 | 01 | 1 | CONT-02 | unit | `bats tests/menu.bats` | ✅ | ✅ green |
| 04-01-04 | 01 | 1 | CONT-02 | unit | `bats tests/instances.bats` | ✅ | ✅ green |
| 04-02-01 | 02 | 1 | CONT-04 | unit (grep) | `bats tests/dockerfile.bats` | ✅ | ✅ green |
| 04-02-02 | 02 | 1 | CONT-04 | unit (grep) | `bats tests/dockerfile.bats` | ✅ | ✅ green |
| 04-02-03 | 02 | 1 | CONT-04 | unit (grep) | `bats tests/dockerfile.bats` | ✅ | ✅ green |
| 04-02-04 | 02 | 1 | CONT-04 | unit (grep) | `bats tests/dockerfile.bats` | ✅ | ✅ green |
| 04-03-01 | 03 | 2 | CONT-05 | unit (grep) | `bats tests/docker.bats` | ✅ | ✅ green |
| 04-03-02 | 03 | 2 | CONT-05 | unit (grep) | `bats tests/docker.bats` | ✅ | ✅ green |
| 04-04-01 | 04 | 2 | CONT-02 | unit | `bats tests/instances.bats` | ✅ | ✅ green |
| 04-04-02 | 04 | 2 | CONT-02 | unit | `bats tests/instances.bats` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

*Existing infrastructure covers all phase requirements.*

Existing BATS framework and test_helper.bash from Phases 1-3 cover all phase test types. All tests are new test cases added to existing .bats files, not new files.

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| noVNC desktop accessible in browser | CONT-04 | Requires running container + browser | Start GUI container, open `http://localhost:{vnc_port}`, verify desktop renders |
| Chromium renders pages inside desktop | CONT-05 | Requires GUI interaction inside container | Open Chromium in noVNC desktop, navigate to example.com, verify page renders without crash |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated 2026-03-14

## Validation Audit 2026-03-14
| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
| Total tests (phase-relevant) | 104 |
| Tests passing | 104 |
