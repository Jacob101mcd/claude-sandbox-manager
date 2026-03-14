# Phase 7: Fix Backup Restore Integration - Research

**Researched:** 2026-03-14
**Domain:** Bash shell scripting — Docker lifecycle orchestration, SSH config management
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Fix approach — Extract shared helper**
- Create `_docker_build_run_cmd` helper in lib/docker.sh that both `docker_run_instance` and `backup_restore` call
- Helper takes instance name, port, and image tag — builds the full `docker run` command array with all security, resource, GUI, MCP, and credential flags
- Only the image tag differs between fresh create (build image) and restore (backup image)
- Eliminates the flag duplication/sync problem between docker.sh and backup.sh permanently
- Remove the "keep in sync" comments from backup.sh — they're no longer needed

**Restore completeness — Full GUI + MCP support**
- Restore reads container type from backup metadata to apply type-specific flags
- GUI containers get VNC port mapping and `--shm-size=512m` on restore (currently missing)
- Linux Engine gets `--add-host=host.docker.internal:host-gateway` for MCP (currently missing)
- `credentials_get_docker_env_flags` called with instance name so MCP/RC env vars are injected (currently called without name)
- `ssh_write_config` called after restore so the SSH alias works immediately (currently missing)

**Post-restore UX — Match menu_action_start behavior**
- After restoring a GUI container: show noVNC URL + "Open in browser?" prompt
- After restoring a CLI container: "SSH into instance now?" prompt
- Same UX pattern as `menu_action_start` — consistent user experience

### Claude's Discretion
- Exact signature and naming of the shared helper function
- Whether the helper populates a global array or takes a nameref
- Test structure for verifying the restore flow

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BACK-03 | Backup captures both container filesystem and workspace volume data | backup_create already does this; restore must fully reconstruct container with correct flags so the workspace volume binding and image are both faithfully applied |
| BACK-04 | User can restore an instance from a backup | backup_restore currently starts the container but misses GUI flags, MCP host flag, credentials instance name, and ssh_write_config; fixing these makes BACK-04 fully functional |
| MCP-01 | Sandbox instances automatically connect to host Docker MCP Toolkit server on startup | CSM_MCP_ENABLED/CSM_MCP_PORT env vars must be injected on restore via credentials_get_docker_env_flags("name"); --add-host must be added on Linux Engine |
| INST-02 | Claude Code remote control optionally configured on container startup | CSM_REMOTE_CONTROL env var must be injected on restore via credentials_get_docker_env_flags("name") with instance name argument |
</phase_requirements>

## Summary

Phase 7 is a targeted bug-fix phase. The core problem is that `backup_restore` in `lib/backup.sh` (lines 129-199) manually duplicates the `docker run` command from `docker_run_instance` in `lib/docker.sh` (lines 56-124), but the copy is incomplete and stale: it omits GUI-specific flags (`--shm-size=512m`, VNC port mapping), the Linux Engine MCP flag (`--add-host=host.docker.internal:host-gateway`), and calls `credentials_get_docker_env_flags` without the instance name — so MCP and remote-control env vars are never injected into restored containers. Additionally, `ssh_write_config` is never called after restore, so `ssh <alias>` silently fails.

The fix strategy is to extract the shared `docker run` command construction from `docker_run_instance` into a new internal helper `_docker_build_run_cmd` in `lib/docker.sh`. Both `docker_run_instance` and `backup_restore` then call this helper — the only difference is the image tag argument (built image vs backup image tag). This eliminates the divergence permanently rather than patching the copy again. The menu layer (`menu_action_restore` in `lib/menu.sh`) also needs type-aware post-restore UX to match `menu_action_start`.

All changes are mechanical refactors against well-understood Bash patterns already established in the codebase. No new external dependencies or concepts are introduced.

**Primary recommendation:** Extract `_docker_build_run_cmd` into docker.sh, refactor both callers, add `ssh_write_config` to `backup_restore`, and update `menu_action_restore` for type-aware UX.

## Standard Stack

### Core

| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| Bash arrays | Bash 4+ | Building docker run command safely | Already used throughout; prevents word splitting on flag values |
| jq | ~1.6 | Read container type from backup metadata | Already used for all JSON I/O in the codebase |
| BATS | installed locally | Unit/integration test framework | Already used for all existing tests |

### Supporting

| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bash namerefs (`local -n`) | Bash 4.3+ | Pass array by reference to helper | Alternative to global array pattern; requires Bash 4.3+ |

### Alternatives Considered

| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| Global `_DOCKER_RUN_CMD` array (like `CSM_DOCKER_ENV_FLAGS`) | `local -n` nameref | Global array is simpler and matches existing pattern; nameref is cleaner but adds Bash version dependency |
| Refactor `backup_restore` to call `docker_run_instance` | Shared helper | `docker_run_instance` sets its own image tag from instance type; backup needs a specific backup image tag — can't reuse directly without adding an override parameter |

**Installation:** No new packages needed. All tools already present.

## Architecture Patterns

### Recommended Project Structure

No structural changes needed. All edits are within existing files:
```
lib/
├── docker.sh        # Add _docker_build_run_cmd; refactor docker_run_instance to call it
├── backup.sh        # Replace manual cmd construction with _docker_build_run_cmd; add ssh_write_config
└── menu.sh          # Update menu_action_restore with type-aware post-restore UX
tests/
├── docker.bats      # Add tests: _docker_build_run_cmd produces correct flags for gui/cli/engine
└── backup.bats      # Add tests: restore calls ssh_write_config; GUI flags present; MCP flags present
```

### Pattern 1: Internal Helper with Global Array Output

**What:** A function prefixed with `_` that populates a global array, which callers append to their own local command array.
**When to use:** When multiple callers need the same complex command segment and the output is array-valued (can't use stdout).
**Example:**
```bash
# Source: existing pattern in lib/credentials.sh — credentials_get_docker_env_flags populates CSM_DOCKER_ENV_FLAGS
# _docker_build_run_cmd follows the same pattern, populating _DOCKER_RUN_CMD

_docker_build_run_cmd() {
    local name="$1"
    local port="$2"
    local image_tag="$3"
    local container_name
    container_name="$(common_container_name "$name")"
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"
    local type
    type="$(instances_get_type "$name")"

    _DOCKER_RUN_CMD=(docker run -d)
    _DOCKER_RUN_CMD+=(--name "$container_name")
    _DOCKER_RUN_CMD+=(-p "127.0.0.1:${port}:22")
    _DOCKER_RUN_CMD+=(-v "${workspace_dir}:/home/claude/workspace")
    _DOCKER_RUN_CMD+=(-w /home/claude/workspace)

    local mem_limit cpu_limit
    mem_limit="$(settings_get '.defaults.memory_limit')"
    cpu_limit="$(settings_get '.defaults.cpu_limit')"
    _DOCKER_RUN_CMD+=(--memory="${mem_limit:-2g}")
    _DOCKER_RUN_CMD+=(--cpus="${cpu_limit:-2}")
    _DOCKER_RUN_CMD+=(--security-opt=no-new-privileges)
    _DOCKER_RUN_CMD+=(--cap-drop=MKNOD)
    _DOCKER_RUN_CMD+=(--cap-drop=AUDIT_WRITE)
    _DOCKER_RUN_CMD+=(--cap-drop=SETFCAP)
    _DOCKER_RUN_CMD+=(--cap-drop=SETPCAP)
    _DOCKER_RUN_CMD+=(--cap-drop=NET_BIND_SERVICE)
    _DOCKER_RUN_CMD+=(--cap-drop=SYS_CHROOT)
    _DOCKER_RUN_CMD+=(--cap-drop=FSETID)
    _DOCKER_RUN_CMD+=(--restart unless-stopped)

    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        _DOCKER_RUN_CMD+=(-p "127.0.0.1:${vnc_port}:6080")
        _DOCKER_RUN_CMD+=(--shm-size=512m)
    fi

    if [[ "$(uname -s)" == "Linux" ]]; then
        local docker_variant
        docker_variant="$(_docker_detect_variant)"
        if [[ "$docker_variant" == "engine" ]]; then
            _DOCKER_RUN_CMD+=(--add-host=host.docker.internal:host-gateway)
        fi
    fi

    credentials_load || true
    credentials_get_docker_env_flags "$name"
    _DOCKER_RUN_CMD+=("${CSM_DOCKER_ENV_FLAGS[@]}")

    _DOCKER_RUN_CMD+=("$image_tag")
}
```

### Pattern 2: Caller Delegates to Helper, Then Executes

**What:** `docker_run_instance` calls `_docker_build_run_cmd` to populate `_DOCKER_RUN_CMD`, then executes it.
**When to use:** Any function that needs to launch a container with full security/env context.
```bash
docker_run_instance() {
    local name="$1"
    local port="$2"
    local type
    type="$(instances_get_type "$name")"
    local image_tag="claude-sandbox-${name}-${type}"

    mkdir -p "$(common_workspace_dir "$name")"
    docker rm -f "$(common_container_name "$name")" 2>/dev/null || true

    _docker_build_run_cmd "$name" "$port" "$image_tag"

    msg_info "Starting container $(common_container_name "$name") on port ${port}..."
    if ! "${_DOCKER_RUN_CMD[@]}"; then
        die "Failed to start container $(common_container_name "$name")"
    fi
    msg_ok "Container $(common_container_name "$name") running on port ${port}"
}
```

### Pattern 3: backup_restore Delegates Then Adds ssh_write_config

**What:** `backup_restore` reads image tag from metadata, calls the shared helper with that tag, then calls `ssh_write_config` to register the alias.
```bash
# Step 5: Build and start container using shared helper
_docker_build_run_cmd "$name" "$port" "$image_tag"

msg_info "Starting restored container on port ${port}..."
if ! "${_DOCKER_RUN_CMD[@]}"; then
    msg_error "Failed to start container from backup image"
    return 1
fi

# Step 6: Register SSH alias (mirrors docker_start_instance)
ssh_write_config "$name" "$port"

msg_ok "Restore complete. Instance '${name}' running from backup."
```

### Pattern 4: Type-Aware Post-Restore UX in menu_action_restore

**What:** After `backup_restore` succeeds, check container type and present type-appropriate prompt — identical to the logic already in `menu_action_start`.
```bash
backup_restore "$name" "$selected_dir" || return

local type
type="$(instances_get_type "$name")"

if [[ "$type" == "gui" ]]; then
    local vnc_port
    vnc_port="$(instances_get_vnc_port "$name")"
    msg_ok "noVNC desktop: http://localhost:${vnc_port}"
    local answer
    read -rp "Open in browser? (y/N) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        xdg-open "http://localhost:${vnc_port}" 2>/dev/null || \
        open "http://localhost:${vnc_port}" 2>/dev/null || \
        true
    fi
else
    local answer
    read -rp "SSH into instance now? (y/N) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        exec ssh "$(common_ssh_alias "$name")"
    fi
fi
```

### Anti-Patterns to Avoid

- **Calling `docker_run_instance` from `backup_restore`:** `docker_run_instance` derives the image tag from instance type (`claude-sandbox-${name}-${type}`) — it cannot be given a backup image tag. Adding a parameter to override would couple caller and callee unnecessarily. The shared helper approach is cleaner.
- **Duplicating the cmd array again:** The current "keep in sync" comment approach is what created the bug. Never duplicate — always extract.
- **Calling `credentials_get_docker_env_flags` without instance name:** Without the name argument, MCP and RC env vars are silently omitted. Always pass `"$name"`.
- **Omitting `|| true` after `credentials_load`:** `credentials_load` returns 1 when .env is missing; this must not abort the restore. Follow the existing pattern from `docker_run_instance`.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Docker context detection | Custom context parsing | `_docker_detect_variant` (already exists in docker.sh:17-23) | Already handles Docker Desktop vs Engine distinction correctly |
| VNC port lookup | Direct JSON parse | `instances_get_vnc_port "$name"` | Handles missing field gracefully (returns empty for CLI instances) |
| Container type lookup | Direct JSON parse | `instances_get_type "$name"` | Returns "cli" default for backward compat with old registries |
| SSH config management | Manual file editing | `ssh_write_config "$name" "$port"` | Already handles remove-then-append pattern atomically |
| Credential env flag construction | Manual -e flag building | `credentials_get_docker_env_flags "$name"` | Handles MCP, RC, API key, and GitHub token in one call |

**Key insight:** Every piece of logic needed for a correct restore already exists in the codebase. This phase is purely about calling the right functions in the right order.

## Common Pitfalls

### Pitfall 1: credentials_get_docker_env_flags Called Without Instance Name

**What goes wrong:** MCP is not enabled in the container. `CSM_MCP_ENABLED` and `CSM_MCP_PORT` are never injected. `CSM_REMOTE_CONTROL` is also absent even if the user enabled it.
**Why it happens:** The function signature is `credentials_get_docker_env_flags [instance_name]` — name is optional for backward compat. The existing `backup_restore` calls it without a name (line 186).
**How to avoid:** Always call `credentials_get_docker_env_flags "$name"` with the instance name. The shared helper ensures this is never forgotten.
**Warning signs:** Container starts but MCP connection probe fails; `CSM_MCP_ENABLED` is not in `docker inspect` env output.

### Pitfall 2: SSH Config Not Written After Restore

**What goes wrong:** `ssh csm-<name>` fails with "host not found" because the `~/.ssh/config` block was never written.
**Why it happens:** `backup_restore` does not call `ssh_write_config`. The config block is only written in `docker_start_instance`.
**How to avoid:** Add `ssh_write_config "$name" "$port"` after the container starts successfully in `backup_restore`.
**Warning signs:** Restore reports success but immediate SSH attempt fails.

### Pitfall 3: GUI Container Restored Without VNC Port or shm-size

**What goes wrong:** The restored GUI container runs but noVNC is inaccessible (port not mapped) and Chrome crashes (insufficient shared memory).
**Why it happens:** The manual cmd array in `backup_restore` skips the `if [[ "$type" == "gui" ]]` block that adds `-p ... :6080` and `--shm-size=512m`.
**How to avoid:** The shared helper reads `instances_get_type "$name"` and adds GUI flags unconditionally — this cannot be forgotten.
**Warning signs:** `docker ps` shows no port 6080 mapping for a GUI instance; browser crashes immediately on noVNC page.

### Pitfall 4: Type Read from Registry, Not Metadata

**What goes wrong:** If the instances registry has a different type than the backup (e.g., instance was re-created as CLI after a GUI backup), the flags applied are wrong.
**Why it happens:** The metadata.json in the backup contains `type` field, but the current code ignores it — it reads type from the live registry.
**Resolution:** The CONTEXT.md decision says "Restore reads container type from backup metadata to apply type-specific flags." Use `jq -r '.type' "${backup_dir}/metadata.json"` to get the authoritative type for this restore. However, the instances registry type drives `instances_get_vnc_port` — if they diverge, the vnc_port lookup may return empty. Safest approach: use metadata type for the conditional logic but still call `instances_get_vnc_port "$name"` for port lookup (the port is registry-allocated, not stored in metadata).
**Warning signs:** GUI backup restored with CLI flags, or vice versa.

### Pitfall 5: menu_action_restore Continues to SSH Without Updated Alias

**What goes wrong:** Even after adding `ssh_write_config` to `backup_restore`, if the old menu code runs `exec ssh` before the config is written, it may use a stale entry.
**Why it happens:** The current `menu_action_restore` runs `exec ssh` immediately after `backup_restore` returns — but `ssh_write_config` is called inside `backup_restore`, so by the time the menu prompt appears, the config is already updated. This is actually safe.
**How to avoid:** No special handling needed — just ensure the `exec ssh` in the menu uses `common_ssh_alias "$name"`, which matches what `ssh_write_config` registers.

## Code Examples

Verified patterns from source inspection:

### Reading type from backup metadata
```bash
# Source: lib/backup.sh backup_create (lines 58-70) — metadata.json structure
local type
type="$(jq -r '.type' "${backup_dir}/metadata.json")"
# type will be "cli" or "gui"
```

### Existing GUI type branch in docker_run_instance (the pattern to replicate)
```bash
# Source: lib/docker.sh lines 97-102
if [[ "$type" == "gui" ]]; then
    local vnc_port
    vnc_port="$(instances_get_vnc_port "$name")"
    cmd+=(-p "127.0.0.1:${vnc_port}:6080")
    cmd+=(--shm-size=512m)
fi
```

### Existing Linux Engine MCP flag (the pattern to replicate)
```bash
# Source: lib/docker.sh lines 104-111
if [[ "$(uname -s)" == "Linux" ]]; then
    local docker_variant
    docker_variant="$(_docker_detect_variant)"
    if [[ "$docker_variant" == "engine" ]]; then
        cmd+=(--add-host=host.docker.internal:host-gateway)
    fi
fi
```

### Correct credentials call with instance name
```bash
# Source: lib/docker.sh line 115 — pass name to get MCP/RC flags
credentials_get_docker_env_flags "$name"
cmd+=("${CSM_DOCKER_ENV_FLAGS[@]}")
```

### menu_action_start type-aware UX (the pattern menu_action_restore must mirror)
```bash
# Source: lib/menu.sh lines 146-166
local type
type="$(instances_get_type "$name")"

if [[ "$type" == "gui" ]]; then
    local vnc_port
    vnc_port="$(instances_get_vnc_port "$name")"
    msg_ok "noVNC desktop: http://localhost:${vnc_port}"
    local answer
    read -rp "Open in browser? (y/N) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        xdg-open "http://localhost:${vnc_port}" 2>/dev/null || \
        open "http://localhost:${vnc_port}" 2>/dev/null || \
        true
    fi
else
    local answer
    read -rp "SSH into instance now? (y/N) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        exec ssh "$(common_ssh_alias "$name")"
    fi
fi
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Duplicated docker run cmd with sync comments | Shared `_docker_build_run_cmd` helper | Phase 7 | Sync bugs become impossible |
| `credentials_get_docker_env_flags` no-name call | Call with instance name | Phase 7 | MCP/RC env vars actually injected on restore |
| No ssh_write_config on restore | Called after restore | Phase 7 | SSH alias works immediately after restore |
| CLI-only post-restore prompt | Type-aware GUI/CLI prompt | Phase 7 | Consistent UX with menu_action_start |

**Deprecated/outdated:**
- "Keep in sync" comment on backup.sh lines 163: eliminated once shared helper exists

## Open Questions

1. **Type from metadata vs registry for GUI restore**
   - What we know: metadata.json stores `type`; instances registry also stores `type`; `instances_get_vnc_port` reads from registry
   - What's unclear: if metadata.type differs from registry.type (edge case), which should win for flag selection?
   - Recommendation: Use `instances_get_type "$name"` (registry) as primary source since the vnc_port is also in the registry. The metadata type is a useful cross-check but not the source of truth for the running system. CONTEXT.md says "reads from backup metadata" — interpret this as reading metadata to confirm/log type, but use registry for port lookups.

## Validation Architecture

### Test Framework

| Property | Value |
|----------|-------|
| Framework | BATS (Bash Automated Testing System), installed locally |
| Config file | none — test files discovered via `bats tests/` |
| Quick run command | `bats tests/backup.bats tests/docker.bats` |
| Full suite command | `bats tests/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BACK-03 | Restore produces container with all security + resource flags | unit | `bats tests/backup.bats` | ✅ (needs new tests) |
| BACK-04 | backup_restore calls ssh_write_config so SSH alias works | unit | `bats tests/backup.bats` | ✅ (needs new tests) |
| MCP-01 | backup_restore injects CSM_MCP_ENABLED/CSM_MCP_PORT on restore | unit | `bats tests/backup.bats tests/docker.bats` | ✅ (needs new tests) |
| INST-02 | backup_restore injects CSM_REMOTE_CONTROL when RC enabled | unit | `bats tests/backup.bats` | ✅ (needs new tests) |

### New Tests Required in backup.bats

The following test cases are not yet present and must be added in Wave 0 or Task 1:

- `backup_restore calls ssh_write_config after starting container`
- `backup_restore passes instance name to credentials_get_docker_env_flags`
- `backup_restore adds --shm-size=512m for gui instance type`
- `backup_restore adds vnc port mapping for gui instance type`
- `backup_restore adds --add-host on Linux Engine`
- `backup_restore does not add --add-host on Docker Desktop`

New tests in docker.bats:

- `_docker_build_run_cmd populates _DOCKER_RUN_CMD with correct image tag`
- `_docker_build_run_cmd includes shm-size for gui type`
- `_docker_build_run_cmd includes add-host on Linux Engine`
- `docker_run_instance delegates to _docker_build_run_cmd`

### Sampling Rate

- **Per task commit:** `bats tests/backup.bats tests/docker.bats`
- **Per wave merge:** `bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps

- [ ] New test cases in `tests/backup.bats` — covers BACK-03, BACK-04, MCP-01, INST-02
- [ ] New test cases in `tests/docker.bats` — covers `_docker_build_run_cmd` contract
- [ ] Update mock for `credentials_get_docker_env_flags` in backup.bats setup to accept an `instance_name` argument and record it

## Sources

### Primary (HIGH confidence)

- Source inspection: `lib/backup.sh` lines 129-199 — current `backup_restore` implementation with missing flags
- Source inspection: `lib/docker.sh` lines 56-124 — complete `docker_run_instance` with all correct flags
- Source inspection: `lib/docker.sh` lines 161-203 — `docker_start_instance` orchestration including `ssh_write_config`
- Source inspection: `lib/menu.sh` lines 139-166 — `menu_action_start` type-aware UX (the target pattern)
- Source inspection: `lib/credentials.sh` lines 87-117 — `credentials_get_docker_env_flags` with optional instance name
- Source inspection: `lib/instances.sh` — `instances_get_type`, `instances_get_vnc_port` behavior and defaults

### Secondary (MEDIUM confidence)

- Project STATE.md — Phase 03 decision: "Duplicate docker run flags... with sync comment" — confirms how the current divergence was intentionally deferred to Phase 7
- Project STATE.md — Phase 05 decision: "credentials_get_docker_env_flags takes optional instance name; backward compat when omitted" — confirms the function signature is intentional and stable

### Tertiary (LOW confidence)

None.

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are already in use; no external dependencies to verify
- Architecture: HIGH — the helper pattern, global array convention, and function signatures are all verified directly from source
- Pitfalls: HIGH — all pitfalls identified from direct source comparison between docker_run_instance and backup_restore

**Research date:** 2026-03-14
**Valid until:** This research is tied to the current source code; valid until any library files change (stable, no external dependencies)
