---
phase: 1
slug: foundation-security
status: draft
nyquist_compliant: false
wave_0_complete: false
created: 2026-03-13
---

# Phase 1 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | Bash + ShellCheck (linting) + BATS (Bash Automated Testing System) |
| **Config file** | none — Wave 0 installs |
| **Quick run command** | `shellcheck bin/csm lib/*.sh` |
| **Full suite command** | `shellcheck bin/csm lib/*.sh && bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `shellcheck bin/csm lib/*.sh`
- **After every plan wave:** Run `shellcheck bin/csm lib/*.sh && bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 1-01-01 | 01 | 0 | QUAL-04 | lint | `shellcheck bin/csm lib/*.sh` | ❌ W0 | ⬜ pending |
| 1-01-02 | 01 | 0 | PLAT-04 | unit | `bats tests/platform.bats` | ❌ W0 | ⬜ pending |
| 1-01-03 | 01 | 0 | BUG-01, BUG-02 | unit | `bats tests/instances.bats` | ❌ W0 | ⬜ pending |
| 1-01-04 | 01 | 0 | SEC-01, SEC-02, SEC-03, SEC-04 | unit | `bats tests/docker.bats` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 1 | PLAT-01 | smoke | `bash bin/csm --help` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 1 | PLAT-04 | unit | `bats tests/platform.bats` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 2 | SEC-01 | unit | `! grep -q 'chpasswd' scripts/Dockerfile` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 2 | SEC-02 | unit | `grep -q '127.0.0.1' lib/docker.sh` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 2 | SEC-03 | unit | `grep -q 'cap-drop' lib/docker.sh` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 2 | SEC-04 | unit | `grep -q 'memory' lib/docker.sh` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 3 | BUG-01 | unit | `bats tests/docker.bats` | ❌ W0 | ⬜ pending |
| 1-xx-xx | xx | 3 | BUG-02 | unit | `bats tests/instances.bats` | ❌ W0 | ⬜ pending |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [ ] `tests/` directory — create test infrastructure
- [ ] `tests/platform.bats` — stubs for PLAT-01, PLAT-04
- [ ] `tests/instances.bats` — stubs for BUG-01, BUG-02
- [ ] `tests/docker.bats` — stubs for SEC-01 through SEC-04
- [ ] ShellCheck installation: `sudo apt-get install -y shellcheck`
- [ ] BATS installation: `sudo apt-get install -y bats` or git clone from bats-core

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Windows PS scripts unchanged | PLAT-03 | Cannot run PS on Linux CI | Verify no changes to `scripts/*.ps1` via `git diff` |
| Modular structure | QUAL-01 | Architectural check | Verify `lib/*.sh` files exist and are sourced from `bin/csm` |

---

## Validation Sign-Off

- [ ] All tasks have `<automated>` verify or Wave 0 dependencies
- [ ] Sampling continuity: no 3 consecutive tasks without automated verify
- [ ] Wave 0 covers all MISSING references
- [ ] No watch-mode flags
- [ ] Feedback latency < 5s
- [ ] `nyquist_compliant: true` set in frontmatter

**Approval:** pending
