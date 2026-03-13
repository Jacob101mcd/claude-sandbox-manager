---
phase: 2
slug: container-engine
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 2 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (installed via npm devDependency) + ShellCheck |
| **Config file** | None — BATS runs directly on test files |
| **Quick run command** | `npx bats test/` |
| **Full suite command** | `npx bats test/ && npx shellcheck lib/*.sh bin/csm` |
| **Estimated runtime** | ~15 seconds |

---

## Sampling Rate

- **After every task commit:** Run `npx bats test/ -x`
- **After every plan wave:** Run `npx bats test/ && npx shellcheck lib/*.sh bin/csm`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 15 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 02-01-01 | 01 | 0 | CONT-01 | integration | `npx bats test/test_docker.bats -f "build cli"` | ❌ W0 | ⬜ pending |
| 02-01-02 | 01 | 0 | CONT-03 | unit | `npx bats test/test_menu.bats -f "type select"` | ❌ W0 | ⬜ pending |
| 02-01-03 | 01 | 0 | INST-01 | integration | `npx bats test/test_docker.bats -f "claude installed"` | ❌ W0 | ⬜ pending |
| 02-01-04 | 01 | 0 | CRED-01 | unit | `npx bats test/test_credentials.bats -f "anthropic key"` | ❌ W0 | ⬜ pending |
| 02-01-05 | 01 | 0 | CRED-02 | integration | `npx bats test/test_docker.bats -f "gh installed"` | ❌ W0 | ⬜ pending |
| 02-01-06 | 01 | 0 | CRED-03 | unit | `npx bats test/test_credentials.bats -f "github token"` | ❌ W0 | ⬜ pending |
| 02-01-07 | 01 | 0 | CRED-04 | integration | `npx bats test/test_credentials.bats -f "no secrets in layers"` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `test/test_docker.bats` — stubs for CONT-01, INST-01, CRED-02
- [ ] `test/test_menu.bats` — stubs for CONT-03
- [ ] `test/test_credentials.bats` — stubs for CRED-01, CRED-03, CRED-04
- [ ] `test/` directory creation
- [ ] BATS available via npm devDependency (from Phase 1 pattern)

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| SSH into running container | CONT-01 | Requires interactive terminal | `csm create test-box cli && csm ssh test-box` — verify shell prompt |
| Claude Code functional inside container | INST-01 | Requires API key + interactive session | SSH in, run `claude --version`, verify output |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 15s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
