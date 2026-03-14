---
phase: 2
slug: container-engine
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
validated: 2026-03-14
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (installed via npm devDependency) + ShellCheck |
| **Config file** | None — BATS runs directly on test files |
| **Quick run command** | `npx bats tests/` |
| **Full suite command** | `npx bats tests/ && npx shellcheck lib/*.sh bin/csm` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `npx bats tests/ -x`
- **After every plan wave:** Run `npx bats tests/ && npx shellcheck lib/*.sh bin/csm`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | CONT-01 | integration | `npx bats tests/docker.bats -f "build cli"` | ✅ | ✅ green |
| 02-01-02 | 01 | 0 | CONT-03 | unit | `npx bats tests/menu.bats -f "type select"` | ✅ | ✅ green |
| 02-01-03 | 01 | 0 | INST-01 | integration | `npx bats tests/dockerfile.bats -f "native installer"` | ✅ | ✅ green |
| 02-01-04 | 01 | 0 | CRED-01 | unit | `npx bats tests/credentials.bats -f "ANTHROPIC_API_KEY"` | ✅ | ✅ green |
| 02-01-05 | 01 | 0 | CRED-02 | integration | `npx bats tests/dockerfile.bats -f "GitHub CLI"` | ✅ | ✅ green |
| 02-01-06 | 01 | 0 | CRED-03 | unit | `npx bats tests/credentials.bats -f "GITHUB_TOKEN"` | ✅ | ✅ green |
| 02-01-07 | 01 | 0 | CRED-04 | integration | `npx bats tests/dockerfile.bats -f "credential env vars"` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/docker.bats` — covers CONT-01
- [x] `tests/menu.bats` — covers CONT-03
- [x] `tests/credentials.bats` — covers CRED-01, CRED-03
- [x] `tests/dockerfile.bats` — covers INST-01, CRED-02, CRED-04
- [x] BATS available via npm devDependency

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSH into running container | CONT-01 | Requires interactive terminal | `csm create test-box cli && csm ssh test-box` — verify shell prompt |
| Claude Code functional inside container | INST-01 | Requires API key + interactive session | SSH in, run `claude --version`, verify output |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 15s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete

---

## Validation Audit 2026-03-14

| Metric | Count |
|--------|-------|
| Gaps found | 3 |
| Resolved | 3 |
| Escalated | 0 |
