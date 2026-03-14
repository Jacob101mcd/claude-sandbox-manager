# Phase 7: Fix Backup Restore Integration - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

Restored containers receive the same MCP/RC environment flags and SSH alias as freshly created ones, fixing the "Restore → SSH with MCP/RC" end-to-end flow. This is a targeted bug fix — no new capabilities.

</domain>

<decisions>
## Implementation Decisions

### Fix approach — Extract shared helper
- Create `_docker_build_run_cmd` helper in lib/docker.sh that both `docker_run_instance` and `backup_restore` call
- Helper takes instance name, port, and image tag — builds the full `docker run` command array with all security, resource, GUI, MCP, and credential flags
- Only the image tag differs between fresh create (build image) and restore (backup image)
- Eliminates the flag duplication/sync problem between docker.sh and backup.sh permanently
- Remove the "keep in sync" comments from backup.sh — they're no longer needed

### Restore completeness — Full GUI + MCP support
- Restore reads container type from backup metadata to apply type-specific flags
- GUI containers get VNC port mapping and `--shm-size=512m` on restore (currently missing)
- Linux Engine gets `--add-host=host.docker.internal:host-gateway` for MCP (currently missing)
- `credentials_get_docker_env_flags` called with instance name so MCP/RC env vars are injected (currently called without name)
- `ssh_write_config` called after restore so the SSH alias works immediately (currently missing)

### Post-restore UX — Match menu_action_start behavior
- After restoring a GUI container: show noVNC URL + "Open in browser?" prompt
- After restoring a CLI container: "SSH into instance now?" prompt
- Same UX pattern as `menu_action_start` — consistent user experience

### Claude's Discretion
- Exact signature and naming of the shared helper function
- Whether the helper populates a global array or takes a nameref
- Test structure for verifying the restore flow

</decisions>

<specifics>
## Specific Ideas

No specific requirements — the fixes are mechanical alignment of backup_restore with docker_run_instance behavior.

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docker_run_instance` (lib/docker.sh:56-124): Contains the complete, correct docker run command with all flags — this becomes the shared helper's body
- `docker_start_instance` (lib/docker.sh:161-202): Shows the full orchestration pattern (keys → build → run → ssh_write_config) that restore should mirror for SSH config
- `_docker_detect_variant` (lib/docker.sh:17-23): Already exists for MCP --add-host detection

### Established Patterns
- Global array pattern: `CSM_DOCKER_ENV_FLAGS` populated by `credentials_get_docker_env_flags` — shared helper could use similar `_DOCKER_RUN_CMD` global array
- Underscore-prefixed internal functions: `_docker_detect_variant`, `_CREDENTIALS_KNOWN_KEYS` — shared helper should follow this convention
- Type-aware branching: `instances_get_type` + `instances_get_vnc_port` for GUI-specific behavior

### Integration Points
- `backup_restore` (lib/backup.sh:129-199): Primary fix target — replace duplicated docker run command with shared helper call, add ssh_write_config
- `docker_run_instance` (lib/docker.sh:56-124): Refactor target — extract body into shared helper
- `menu_action_restore` (lib/menu.sh:295-329): UX fix target — add type-aware post-restore prompts matching menu_action_start

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 07-backup-restore-integration*
*Context gathered: 2026-03-14*
