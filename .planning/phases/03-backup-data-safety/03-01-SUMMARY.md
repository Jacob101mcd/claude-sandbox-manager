---
phase: 03-backup-data-safety
plan: "01"
subsystem: backup
tags: [backup, restore, docker, bats, tdd]
dependency_graph:
  requires: [lib/common.sh, lib/instances.sh, lib/credentials.sh, lib/docker.sh]
  provides: [lib/backup.sh]
  affects: [bin/csm, lib/menu.sh]
tech_stack:
  added: []
  patterns: [bash-array-docker-run, atomic-jq-write, tdd-red-green]
key_files:
  created: [lib/backup.sh, tests/backup.bats]
  modified: []
decisions:
  - "Duplicate docker run flags from docker_run_instance into backup_restore with sync comment — avoids tight coupling while keeping security hardening"
  - "Atomic jq write for metadata.json via tmp+mv — consistent with existing instances.sh pattern"
  - "_BACKUP_LISTED_DIRS global array populated by backup_list for caller use (selection menus)"
  - "gunzip -c piped to docker load for restore — avoids temp file for large images"
metrics:
  duration: "2m15s"
  completed_date: "2026-03-13"
  tasks_completed: 1
  files_created: 2
  files_modified: 0
---

# Phase 3 Plan 01: Backup Module Summary

Docker commit + docker save image backup with workspace tar, metadata.json, and full restore via docker load + tar xzf with security-hardened docker run.

## What Was Built

`lib/backup.sh` implements the core backup/restore subsystem for Phase 3:

- **`backup_create "$name"`** — commits the container (`docker commit`), saves the image to `image.tar.gz` (`docker save | gzip`), archives the workspace to `workspace.tar.gz` (`tar czf`), writes `metadata.json` (imagetag, instance, port, type, timestamp), and reports size
- **`backup_restore "$name" "$backup_dir"`** — stops and removes the existing container, loads the backup image (`gunzip -c | docker load`), clears and restores the workspace (`tar xzf --no-same-owner`), then starts the container with the backup image tag using the same security-hardening flags as `docker_run_instance`
- **`backup_list "$name"`** — finds backup directories newest-first, displays numbered list with sizes, populates `_BACKUP_LISTED_DIRS` global array for callers (menu selection)

`tests/backup.bats` provides 14 BATS tests covering all behaviors with mocked docker, tar, and credential functions. Full suite: 67/67 tests pass.

## Decisions Made

1. **Duplicate docker run flags with sync comment** — `backup_restore` duplicates the `docker run` array from `docker_run_instance` rather than calling it directly (which would use the wrong image tag). A code comment marks the duplication point.
2. **Atomic jq write** — metadata.json written to `.tmp` then `mv` to prevent partial writes, matching `instances.sh` pattern.
3. **`_BACKUP_LISTED_DIRS` global array** — populated by `backup_list` so calling menu code can map user selection to a backup path without re-scanning.
4. **`gunzip -c | docker load`** — streaming decompression avoids needing disk space for an uncompressed intermediate.

## Deviations from Plan

None — plan executed exactly as written.

## Verification

- `bats tests/backup.bats` — 14/14 tests pass
- `bats tests/` — 67/67 tests pass (full suite)
- `npx shellcheck lib/backup.sh` — no errors or warnings

## Self-Check: PASSED

- lib/backup.sh exists: FOUND
- tests/backup.bats exists: FOUND
- Commit ca7ee55 (RED): FOUND
- Commit e2b9a99 (GREEN): FOUND
