---
phase: quick
plan: 1
subsystem: powershell-manager
tags: [feature-parity, backup, preferences, security, gui, windows]
dependency_graph:
  requires: []
  provides: [backup-restore-ps1, preferences-menu-ps1, container-type-selection-ps1, security-hardened-docker-run-ps1]
  affects: [scripts/common.ps1, scripts/claude-manager.ps1]
tech_stack:
  added: []
  patterns: [atomic-json-write-ps1, dotted-path-config-traversal, docker-security-hardening, novnc-gui-pattern]
key_files:
  created: []
  modified:
    - scripts/common.ps1
    - scripts/claude-manager.ps1
decisions:
  - "Used PowerShell .NET GZip streams instead of gzip binary for image compression (not always on PATH in Windows)"
  - "Restore function decompresses to temp file before docker load (pipes not reliable cross-platform in PS)"
  - "Set-Setting uses PSObject.Properties mutation so existing JSON structure is preserved on write"
metrics:
  duration_seconds: 212
  completed_date: "2026-03-14T20:34:40Z"
  tasks_completed: 2
  tasks_total: 2
  files_modified: 2
---

# Phase quick Plan 1: Add Missing Menu Options (Preferences and Backup/Restore) Summary

PowerShell manager gains full feature parity with bash manager: config CRUD via csm-config.json, 5-option preferences menu, CLI/GUI container type selection, backup/restore with docker commit+save, and security-hardened docker run (7 cap-drops, localhost-only SSH, memory/CPU limits, --target build, VNC port for GUI instances).

## Tasks Completed

| Task | Name | Commit | Files |
|------|------|--------|-------|
| 1 | Add config, backup/restore, type-selection, security hardening to common.ps1 | 6be2c6c | scripts/common.ps1 |
| 2 | Add B/E/P menu options and type-aware flows to claude-manager.ps1 | 518488c | scripts/claude-manager.ps1 |

## What Was Built

### common.ps1 additions

**Config management (lib/settings.sh parity):**
- `Ensure-ConfigFile` — creates `csm-config.json` with defaults (container_type: null, memory_limit: 2g, cpu_limit: 2, auto_backup: false, mcp_port: 8811); atomic write via .tmp+Move-Item
- `Get-Setting($JqPath)` — walks PSObject tree via dotted path segments, returns value or empty string
- `Get-SettingBool($JqPath)` — same walk, returns "true"/"false" (never empty)
- `Set-Setting($JqPath, $Value)` — walks to parent, sets leaf value, writes atomically

**Container type support (lib/instances.sh parity):**
- `Get-NextFreeVncPort` — starts at 6080, skips ports in use in registry or system
- `Register-Instance($Name, $Type)` — now accepts Type param; stores type, mcp_enabled=$true, remote_control=$false; allocates vnc_port for gui type
- `Get-InstanceType($Name)` / `Get-InstanceVncPort($Name)` — accessors for instance metadata
- `Show-InstanceList` — shows `[type]` badge and `(ssh:N vnc:N)` for GUI, `(port N)` for CLI

**Security hardening in docker run (lib/docker.sh parity):**
- `Start-SandboxInstance` updated: `docker build --target $type`, SSH bound to `127.0.0.1` only, `--memory`, `--cpus`, `--security-opt=no-new-privileges`, 7x `--cap-drop` flags, VNC port mapping + `--shm-size=512m` for GUI, auto-backup before rebuild if enabled

**Backup/restore (lib/backup.sh parity):**
- `Invoke-Backup($Name)` — docker commit, save as image.tar.gz (using .NET GZipStream), tar workspace, write metadata.json with imagetag/instance/port/type/timestamp
- `Get-BackupList($Name)` — returns sorted array of backup dir paths, displays numbered list with sizes
- `Invoke-Restore($Name, $BackupDir)` — stop/rm container, decompress+load image, restore workspace via tar, re-run with full security flags, write SSH config

**Preferences menu (lib/settings.sh parity):**
- `Select-ContainerType` — auto-skips if default set in config; otherwise prompts [1] CLI / [2] GUI
- `Show-PreferencesMenu` — looping sub-menu with 5 settings: auto-backup toggle, container type cycle, memory/CPU/MCP port with validation

### claude-manager.ps1 changes

- Added `[B] Backup`, `[E] Restore`, `[P] Preferences` to menu display (8 total options)
- `B` case: select instance, call `Invoke-Backup`
- `E` case: `Get-BackupList`, validate selection, confirm, `Invoke-Restore`; show VNC URL for GUI
- `P` case: `Show-PreferencesMenu`
- `N` flow updated: `Select-ContainerType` → `Register-Instance $name $type` → `Start-SandboxInstance`; show VNC URL for GUI or SSH hint for CLI
- `S` flow updated: show type-appropriate post-start info (VNC URL vs SSH)
- `Ensure-ConfigFile` called at startup before main loop

## Deviations from Plan

### Auto-fixed Issues

**1. [Rule 2 - Missing functionality] PowerShell GZipStream instead of gzip binary**
- **Found during:** Task 1 (Invoke-Backup implementation)
- **Issue:** `gzip` is not reliably on PATH in Windows environments; the plan referenced `docker save | gzip`
- **Fix:** Used `[System.IO.Compression.GZipStream]` (.NET, available in all Windows 10+ environments) for both compress and decompress
- **Files modified:** scripts/common.ps1

**2. [Rule 2 - Missing functionality] Restore via temp file instead of pipe**
- **Found during:** Task 1 (Invoke-Restore implementation)
- **Issue:** PowerShell piping to docker commands is unreliable cross-platform; `gunzip -c ... | docker load` doesn't work natively in PS
- **Fix:** Decompress .tar.gz to a temp file in $env:TEMP, then `docker load -i tmpfile`, clean up after

## Self-Check: PASSED

- scripts/common.ps1 exists with 40 functions including all 15 new/updated ones
- scripts/claude-manager.ps1 contains all 8 required strings ([B], [E], [P], Invoke-Backup, Invoke-Restore, Show-PreferencesMenu, Select-ContainerType, Ensure-ConfigFile)
- Commit 6be2c6c exists (common.ps1 task)
- Commit 518488c exists (claude-manager.ps1 task)
- Security flags verified: --cap-drop x7, --security-opt, --memory, --cpus, 127.0.0.1 SSH bind, --target build, --shm-size for GUI
