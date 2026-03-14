# Phase 3: Backup + Data Safety - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Port the existing working backup/restore system to Linux and macOS, and add the optional auto-backup-on-startup toggle. Windows PowerShell scripts are left as-is — this phase creates the Bash equivalent. No new backup features beyond what Windows has plus auto-backup.

</domain>

<decisions>
## Implementation Decisions

### Backup strategy
- `docker commit` + `docker save` (image-based backup, matching Windows approach)
- Captures both container image AND workspace volume as separate archives
- Workspace archived as tar.gz (native Linux format, smaller than zip)
- Image saved via `docker save` (produces image.tar, then compressed to image.tar.gz)
- Backup naming: timestamp folders `backups/{instance}/YYYYMMDD-HHMM/` containing image.tar.gz, workspace.tar.gz, metadata.json
- Metadata includes image tag, instance name, port, container type

### Restore flow
- Replace in-place: stop current container, load backup image, overwrite workspace, start from backup
- Same instance name and port preserved
- Backup selection: numbered list newest-first with size, like Windows UX
- Confirmation: user types YES before destructive overwrite
- Post-restore: auto-start container + prompt "SSH into instance now? (y/N)" — consistent with create/start flow
- Credentials (ANTHROPIC_API_KEY, GITHUB_TOKEN) injected from current .env into restored container via -e flags

### Auto-backup on startup
- Triggers when an instance is started (before the instance actually starts)
- Captures last-known-good state from previous session
- Toggle via `CSM_AUTO_BACKUP=1` in .env file (reuses existing .env from Phase 2)
- Phase 6 settings CLI can read/write this variable later
- No auto-cleanup of old backups — user manages disk space manually
- Brief status output: "Auto-backup: creating backup..." then "Auto-backup: done (245 MB)"

### Menu integration
- [B] Backup an instance and [E] Restore an instance added to action menu
- Single-char dispatch consistent with existing S/T/N/R/Q pattern
- Instance selection reuses existing `menu_select_instance` helper
- Step-by-step progress messages during long operations: "Committing container...", "Saving image...", "Archiving workspace..."

### Module structure
- New `lib/backup.sh` module for all backup/restore logic
- Menu actions in `lib/menu.sh` call into backup.sh functions
- Windows PowerShell scripts left unchanged

### Claude's Discretion
- Exact metadata.json schema beyond required fields
- Error handling for partial/failed backups (cleanup strategy)
- How to calculate and display backup sizes
- docker commit tag naming convention
- Whether to check available disk space before backup

</decisions>

<specifics>
## Specific Ideas

- Match the Windows backup UX as closely as possible — users familiar with the PowerShell version should feel at home
- "Backup before start" pattern for auto-backup — captures last-known-good state as safety net
- Keep it simple: no retention policies, no incremental backups, no deduplication — just timestamped full snapshots

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `common_backup_dir()` in lib/common.sh: already returns `backups/{name}/` path
- `menu_select_instance()` in lib/menu.sh: numbered instance selection with auto-select for single instance
- `docker_start_instance()` in lib/docker.sh: handles credential injection via -e flags — restore should reuse this
- `scripts/backup-claude.ps1` and `scripts/restore-claude.ps1`: reference implementations for the backup flow

### Established Patterns
- Atomic jq writes via tmp file + mv (instances.sh) — use for any metadata writes
- Docker run command built as Bash array for safe argument handling — restore's docker run should follow this
- `msg_info`, `msg_ok`, `msg_warn`, `msg_error` from common.sh for consistent output
- Build staging dir pattern: clean and recreate for deterministic state

### Integration Points
- `lib/menu.sh`: Add B/E action keys to `menu_show_actions()` and dispatch in `menu_main()`
- `docker_start_instance()`: Hook auto-backup call before container start (when CSM_AUTO_BACKUP=1)
- `.env` file: Add CSM_AUTO_BACKUP variable alongside existing ANTHROPIC_API_KEY and GITHUB_TOKEN
- `lib/credentials.sh`: Reuse `.env` parsing for reading CSM_AUTO_BACKUP toggle

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 03-backup-data-safety*
*Context gathered: 2026-03-13*
