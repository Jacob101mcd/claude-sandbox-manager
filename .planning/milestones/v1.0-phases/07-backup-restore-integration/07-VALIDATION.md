---
phase: 7
slug: backup-restore-integration
status: complete
nyquist_compliant: true
wave_0_complete: true
created: 2026-03-14
---

# Phase 7 — Validation Strategy

> Per-phase validation contract for feedback sampling during execution.

---

## Test Infrastructure

| Property | Value |
|----------|-------|
| **Framework** | BATS (Bash Automated Testing System), installed locally |
| **Config file** | none — test files discovered via `bats tests/` |
| **Quick run command** | `bats tests/backup.bats tests/docker.bats` |
| **Full suite command** | `bats tests/` |
| **Estimated runtime** | ~5 seconds |

---

## Sampling Rate

- **After every task commit:** Run `bats tests/backup.bats tests/docker.bats`
- **After every plan wave:** Run `bats tests/`
- **Before `/gsd:verify-work`:** Full suite must be green
- **Max feedback latency:** 5 seconds

---

## Per-Task Verification Map

| Task ID | Plan | Wave | Requirement | Test Type | Automated Command | File Exists | Status |
|---------|------|------|-------------|-----------|-------------------|-------------|--------|
| 07-01-01 | 01 | 0 | BACK-03 | unit | `bats tests/backup.bats` | ✅ | ✅ green |
| 07-01-02 | 01 | 0 | BACK-04 | unit | `bats tests/backup.bats` | ✅ | ✅ green |
| 07-01-03 | 01 | 0 | MCP-01 | unit | `bats tests/backup.bats tests/docker.bats` | ✅ | ✅ green |
| 07-01-04 | 01 | 0 | INST-02 | unit | `bats tests/backup.bats` | ✅ | ✅ green |

*Status: ⬜ pending · ✅ green · ❌ red · ⚠️ flaky*

---

## Wave 0 Requirements

- [x] `tests/backup.bats` — new test cases: restore calls ssh_write_config, passes instance name to credentials_get_docker_env_flags, adds --shm-size for gui, adds vnc port for gui
- [x] `tests/docker.bats` — new test cases: _docker_build_run_cmd populates _DOCKER_RUN_CMD with correct image tag, includes shm-size for gui type, includes add-host on Linux Engine, docker_run_instance delegates to _docker_build_run_cmd
- [x] Update mock for `credentials_get_docker_env_flags` in backup.bats setup to accept instance_name argument and record it

---

## Manual-Only Verifications

| Behavior | Requirement | Why Manual | Test Instructions |
|----------|-------------|------------|-------------------|
| Post-restore GUI UX shows noVNC URL + browser prompt | BACK-03 | Interactive terminal prompt | 1. Backup a GUI container 2. Restore it 3. Verify noVNC URL shown and "Open in browser?" prompt appears |
| Post-restore CLI UX shows SSH prompt | BACK-03 | Interactive terminal prompt | 1. Backup a CLI container 2. Restore it 3. Verify "SSH into instance now?" prompt appears |

---

## Validation Sign-Off

- [x] All tasks have `<automated>` verify or Wave 0 dependencies
- [x] Sampling continuity: no 3 consecutive tasks without automated verify
- [x] Wave 0 covers all MISSING references
- [x] No watch-mode flags
- [x] Feedback latency < 5s
- [x] `nyquist_compliant: true` set in frontmatter

**Approval:** complete

---

## Validation Audit 2026-03-14
| Metric | Count |
|--------|-------|
| Gaps found | 0 |
| Resolved | 0 |
| Escalated | 0 |
