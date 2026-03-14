---
phase: 06-settings-documentation
plan: "03"
subsystem: documentation
tags: [readme, documentation, open-source, cross-platform]
dependency_graph:
  requires:
    - 06-01 (settings module, [P] Preferences menu)
    - 06-02 (SECURITY.md, LICENSE)
  provides:
    - README.md (complete rewrite, 269 lines)
  affects: []
tech_stack:
  added: []
  patterns: []
key_files:
  created: []
  modified:
    - README.md
decisions:
  - "Linux/macOS documented first with bin/csm as primary entry point; Windows second with claude-manager.bat"
  - "Security section uses 5-row emoji risk table (matching SECURITY.md subset) linking to full analysis"
  - "Configuration section documents all [P] Preferences settings with defaults table and sample csm-config.json"
metrics:
  duration: "1m26s"
  completed_date: "2026-03-14"
  tasks_completed: 1
  files_changed: 1
---

# Phase 6 Plan 3: README Rewrite Summary

**One-liner:** Complete README rewrite with Linux/macOS-first platform ordering, first-person narrative Why section, Configuration docs for [P] Preferences, emoji security risk table linking to SECURITY.md, and updated container contents (native Claude Code installer, GitHub CLI, CLI+GUI variants).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Complete README.md rewrite | 05ad060 | README.md |

## What Was Built

### README.md (complete rewrite, 269 lines)

Full rewrite replacing the outdated Windows-centric README. All 13 sections written in locked order:

1. **Badges** — shields.io static badges: platform (Linux/macOS/Windows), license (Apache 2.0), Docker required
2. **Title + Description** — "Claude Sandbox Manager" with concise 2-sentence description
3. **Why I built this** — First-person narrative: safety motivation, multi-project isolation, accessibility for non-Docker users
4. **Who is this for** — 5 bullet points: AI developers, cautious users, multi-project users, teams, non-Docker-experts
5. **Prerequisites** — Table: Docker Desktop/Engine, Git, SSH client with platform notes
6. **Quick Start** — Linux/macOS (bin/csm) first, Windows (claude-manager.bat) second; includes `--dangerously-skip-permissions` command
7. **Multi-Instance Support** — Updated menu output with [B] Backup, [E] Restore, [P] Preferences; explanation of each action; instance resources table
8. **Configuration** — [P] Preferences settings table (5 settings with defaults), csm-config.json schema example, note that resource changes apply on next start
9. **Integrations** — MCP Toolkit and Remote Control sections; port override updated to reference [P] Preferences instead of .env
10. **Security** — 5-row emoji risk table (🟢/🟡); rationale for `--dangerously-skip-permissions`; link to SECURITY.md
11. **What's Included** — Updated container contents: native Claude Code installer, GitHub CLI; CLI vs GUI variants table
12. **SSH Details** — Connection parameters table
13. **Notes** — SSH keys, relative paths, workspace migration, .instances.json persistence, Apache 2.0 license link

## Deviations from Plan

None - plan executed exactly as written.

## Self-Check: PASSED

- README.md: FOUND (269 lines — within 250-350 target)
- All required sections present: Why I built this, Who is this for, Security, SECURITY.md link, Preferences, dangerously-skip-permissions, Apache, bin/csm
- Commit 05ad060: FOUND
