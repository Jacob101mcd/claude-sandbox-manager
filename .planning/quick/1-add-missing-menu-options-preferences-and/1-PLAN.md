---
phase: quick
plan: 1
type: execute
wave: 1
depends_on: []
files_modified:
  - scripts/common.ps1
  - scripts/claude-manager.ps1
autonomous: true
requirements: [PARITY-01]

must_haves:
  truths:
    - "PowerShell menu shows [B] Backup, [E] Restore, [P] Preferences options"
    - "User can create/restore backups from PowerShell menu"
    - "User can change preferences (auto-backup, container type, memory, CPU, MCP port)"
    - "New instances prompt for CLI/GUI container type selection"
    - "Docker run includes security hardening flags (cap-drop, security-opt, memory, cpus)"
    - "GUI instances get VNC port mapping and --shm-size flag"
  artifacts:
    - path: "scripts/common.ps1"
      provides: "Config management, backup/restore, container type, security hardening"
    - path: "scripts/claude-manager.ps1"
      provides: "Full menu with B/E/P actions and type-aware start/new"
  key_links:
    - from: "scripts/claude-manager.ps1"
      to: "scripts/common.ps1"
      via: "dot-source and function calls"
      pattern: "Invoke-Backup|Invoke-Restore|Show-PreferencesMenu|Select-ContainerType"
---

<objective>
Port missing features from bash manager (lib/settings.sh, lib/backup.sh, lib/menu.sh, lib/docker.sh, lib/instances.sh) to PowerShell manager (scripts/common.ps1, scripts/claude-manager.ps1) to achieve feature parity.

Purpose: Windows users currently lack Backup/Restore, Preferences, container type selection, and security hardening -- features that bash users have.
Output: Updated common.ps1 with all missing functions, updated claude-manager.ps1 with full menu.
</objective>

<execution_context>
@/home/claude/.claude/get-shit-done/workflows/execute-plan.md
@/home/claude/.claude/get-shit-done/templates/summary.md
</execution_context>

<context>
@scripts/common.ps1
@scripts/claude-manager.ps1
@lib/settings.sh
@lib/backup.sh
@lib/docker.sh
@lib/instances.sh
@lib/menu.sh
</context>

<tasks>

<task type="auto">
  <name>Task 1: Add config management, container type, security hardening, and backup/restore to common.ps1</name>
  <files>scripts/common.ps1</files>
  <action>
Add the following functions to scripts/common.ps1, porting behavior from the bash equivalents:

**Config file management (port from lib/settings.sh):**
- `Ensure-ConfigFile` -- Creates `csm-config.json` at `$Script:Root` with defaults if missing: `{ defaults: { container_type: null, memory_limit: "2g", cpu_limit: 2 }, backup: { auto_backup: false }, integrations: { mcp_port: 8811 } }`. Use `ConvertTo-Json`/`ConvertFrom-Json` (no jq dependency on Windows).
- `Get-Setting($JqPath)` -- Read a dotted path (e.g. ".defaults.memory_limit") from csm-config.json. Parse path segments, walk the PSObject tree. Return empty string if missing.
- `Get-SettingBool($JqPath)` -- Same as Get-Setting but returns "true"/"false" string, defaulting to "false".
- `Set-Setting($JqPath, $Value)` -- Write a value at the given dotted path in csm-config.json. Support string, bool ($true/$false), and number types. Write atomically (write to .tmp then Move-Item).

**Container type support (port from lib/instances.sh):**
- Update `Register-Instance($Name, $Type)` -- Accept optional `$Type` parameter (default "cli"). Store `type`, `mcp_enabled=$true`, `remote_control=$false` in instance record. For "gui" type, also allocate and store `vnc_port` using `Get-NextFreeVncPort`.
- `Get-NextFreeVncPort` -- Starting at 6080, find next port not in use (same pattern as Get-NextFreePort but checking vnc_port fields).
- Update `Show-InstanceList` -- Show instance type and vnc_port for GUI instances (match bash `instances_list_with_status` format: `name [type] (port N) - status` for CLI, `name [type] (ssh:N vnc:N) - status` for GUI).

**Security hardening in docker run (port from lib/docker.sh):**
- Update `Start-SandboxInstance` to add these flags to `$runArgs`:
  - `--memory` from config (default "2g"), `--cpus` from config (default 2)
  - `--security-opt=no-new-privileges`
  - `--cap-drop=MKNOD`, `--cap-drop=AUDIT_WRITE`, `--cap-drop=SETFCAP`, `--cap-drop=SETPCAP`, `--cap-drop=NET_BIND_SERVICE`, `--cap-drop=SYS_CHROOT`, `--cap-drop=FSETID`
  - Bind SSH to localhost: change `-p "${port}:22"` to `-p "127.0.0.1:${port}:22"`
  - Use `--target` in docker build: `docker build -t $imageName --target $type -f ...`
  - For GUI type: add `-p "127.0.0.1:${vnc_port}:6080"` and `--shm-size=512m`
  - Support auto-backup before start: if `Get-SettingBool '.backup.auto_backup'` is "true" and container exists, call `Invoke-Backup` before rebuilding.

**Backup/restore functions (port from lib/backup.sh):**
- `Invoke-Backup($Name)` -- Docker commit container, docker save | gzip to `backups/$Name/$timestamp/image.tar.gz`, archive workspace to `workspace.tar.gz`, write `metadata.json` with imagetag/instance/port/type/timestamp. Use `tar` (available in Windows 10+) for archiving.
- `Get-BackupList($Name)` -- List backup directories sorted newest-first, return array of paths. Display numbered list with sizes.
- `Invoke-Restore($Name, $BackupDir)` -- Stop/remove container, `docker load` from image.tar.gz, restore workspace from workspace.tar.gz, re-run container with full security flags (reuse Start-SandboxInstance logic with custom image tag). Write SSH config after restore.

**Preferences menu (port from lib/settings.sh):**
- `Show-PreferencesMenu` -- Interactive sub-menu loop showing current values for: [1] Auto-backup (toggle), [2] Default container type (cycle: null->cli->gui->null), [3] Memory limit (prompt), [4] CPU limit (prompt), [5] MCP port (prompt), [B] Back. Include validation: memory must match Docker format, CPU must be positive number, port must be 1024-65535.

**Container type selection (port from lib/menu.sh):**
- `Select-ContainerType` -- If default container type is set in config, auto-use it (print info message). Otherwise show interactive prompt: [1] Minimal CLI, [2] GUI Desktop.
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command ". ./scripts/common.ps1; Write-Host 'Functions loaded OK'; Ensure-ConfigFile; $mem = Get-Setting '.defaults.memory_limit'; if ($mem -eq '2g') { Write-Host 'PASS: config read works' } else { Write-Host 'FAIL'; exit 1 }"</automated>
  </verify>
  <done>All functions exist in common.ps1: config CRUD, container type support, security flags in docker run, backup/restore, preferences menu, container type selection. Config file creation and read/write round-trips correctly.</done>
</task>

<task type="auto">
  <name>Task 2: Add Backup, Restore, Preferences menu options and type-aware flows to claude-manager.ps1</name>
  <files>scripts/claude-manager.ps1</files>
  <action>
Update the main menu loop in scripts/claude-manager.ps1 to match the bash menu (lib/menu.sh):

**Add menu options:**
- Add `[B] Backup an instance`, `[E] Restore an instance`, `[P] Preferences` to the displayed actions list (between [R] and [Q]).

**Add switch cases:**
- `"B"`: Select instance via `Select-Instance`, call `Invoke-Backup $name`.
- `"E"`: Select instance, call `Get-BackupList $name` (continue if no backups). Prompt for backup number, validate selection. Confirm with "Type YES to confirm restore". Call `Invoke-Restore $name $selectedDir`. After restore, if GUI type show noVNC URL and offer to open browser (`Start-Process`); if CLI offer SSH.
- `"P"`: Call `Show-PreferencesMenu`.

**Update "N" (New instance) flow:**
- After name validation, call `Select-ContainerType` to get type.
- Pass type to `Register-Instance $name $type` (was previously not passing type).
- Then call `Start-SandboxInstance $name`.
- After start, if GUI type: get vnc_port from instance, show noVNC URL, offer to open browser via `Start-Process "http://localhost:$vnc_port"`.

**Update "S" (Start) flow:**
- After starting, check instance type. If GUI: show noVNC URL, offer to open browser. If CLI: offer SSH.

**Call Ensure-ConfigFile** at script start (after auto-migration, before main loop).
  </action>
  <verify>
    <automated>pwsh -NoProfile -Command "$content = Get-Content ./scripts/claude-manager.ps1 -Raw; $checks = @('[B]','[E]','[P]','Invoke-Backup','Invoke-Restore','Show-PreferencesMenu','Select-ContainerType','Ensure-ConfigFile'); $missing = $checks | Where-Object { $content -notmatch [regex]::Escape($_) }; if ($missing) { Write-Host \"FAIL: Missing: $($missing -join ', ')\"; exit 1 } else { Write-Host 'PASS: All menu options and function calls present' }"</automated>
  </verify>
  <done>PowerShell manager menu shows all 8 options (S/T/N/R/B/E/P/Q). Backup prompts for instance and creates backup. Restore lists backups, confirms, and restores. Preferences opens sub-menu. New instance prompts for container type. Start shows type-appropriate post-start info (VNC URL for GUI, SSH for CLI).</done>
</task>

</tasks>

<verification>
- `pwsh -NoProfile -Command ". ./scripts/common.ps1"` loads without errors
- `pwsh -NoProfile -Command "Get-Content ./scripts/claude-manager.ps1 -Raw"` contains all 8 menu options
- Config file round-trip: create, read, set, read back
- Security flags present in Start-SandboxInstance: `--cap-drop`, `--security-opt`, `--memory`, `--cpus`
</verification>

<success_criteria>
PowerShell manager has feature parity with bash manager for: Preferences menu (5 settings), Backup/Restore actions, container type selection (CLI/GUI), security-hardened docker run, type-aware instance display and post-start flows.
</success_criteria>

<output>
After completion, create `.planning/quick/1-add-missing-menu-options-preferences-and/1-SUMMARY.md`
</output>
