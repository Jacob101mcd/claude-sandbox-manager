---
phase: 5
slug: integration-layer
status: validated
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-13
validated: 2026-03-14
---

# Phase 5 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (Bash Automated Testing System) |
| **Config file** | `tests/test_helper.bash` (sets CSM_ROOT) |
| **Quick run command** | `bats tests/instances.bats tests/docker.bats tests/menu.bats` |
| **Full suite command** | `bats tests/` |
| **Estimated runtime** | ~10 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats tests/instances.bats tests/docker.bats tests/menu.bats`
- **After every plan wave:** Run `bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 10 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 05-01-01 | 01 | 1 | MCP-01 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 05-01-02 | 01 | 1 | MCP-01 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 05-01-03 | 01 | 1 | MCP-01 | unit | `bats tests/instances.bats` | ✅ | ✅ green |
| 05-02-01 | 02 | 1 | MCP-03 | unit | `bats tests/entrypoint.bats` | ✅ | ✅ green |
| 05-02-02 | 02 | 1 | INST-02 | unit | `bats tests/entrypoint.bats` | ✅ | ✅ green |
| 05-03-01 | 03 | 1 | INST-02 | unit | `bats tests/docker.bats` | ✅ | ✅ green |
| 05-03-02 | 03 | 1 | INST-02 | unit | `bats tests/instances.bats` | ✅ | ✅ green |
| 05-03-03 | 03 | 1 | INST-02 | unit | `bats tests/menu.bats` | ✅ | ✅ green |
| 05-04-01 | 04 | 2 | MCP-02 | manual | `grep -q "Integrations" README.md` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/entrypoint.bats` — 23 static-analysis tests for MCP-03 (idempotent config write) and INST-02 (remote control startup); all green
- [ ] README integration check validated manually: `grep -q "Integrations" README.md && echo "ok"`

*Existing infrastructure (`tests/docker.bats`, `tests/instances.bats`, `tests/menu.bats`) covers remaining requirements.*

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| README contains Integrations section with MCP + Remote Control subsections | MCP-02 | Content review needed | 1. Open README.md 2. Verify "Integrations" heading exists 3. Check MCP Toolkit and Remote Control subsections have setup steps |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 10s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** validated

---

## Validation Audit 2026-03-14

| Metric | Count |
|--------|-------|
| Gaps found | 2 |
| Resolved | 2 |
| Escalated | 0 |

Tests created: `tests/entrypoint.bats` (23 static-analysis tests covering MCP auto-config and remote control startup blocks).
