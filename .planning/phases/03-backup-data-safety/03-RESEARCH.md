# Phase 3: Backup + Data Safety - Research

**Researched:** 2026-03-13
**Domain:** Docker container backup/restore via Bash scripting
**Confidence:** HIGH

## Summary

Phase 3 ports the existing Windows PowerShell backup/restore system (`scripts/backup-claude.ps1` and `scripts/restore-claude.ps1`) to Bash and adds an auto-backup-on-startup toggle. The Windows implementation is a clear reference: it uses `docker commit` + `docker save` for image backup, filesystem archival for workspace data, and JSON metadata. The Bash port is straightforward since all Docker CLI commands are identical cross-platform -- the only differences are archive format (tar.gz instead of zip) and shell syntax.

The codebase already has all the scaffolding needed: `common_backup_dir()` returns the backup path, `menu_select_instance()` handles instance selection, `docker_start_instance()` handles container orchestration with credential injection, and `credentials_load()` reads .env variables. The new `lib/backup.sh` module needs to implement ~6 functions (backup, restore, list backups, auto-backup hook) and integrate into `lib/menu.sh` with two new action keys (B and E).

**Primary recommendation:** Follow the PowerShell scripts line-for-line as the reference implementation, translating to Bash idioms and using tar.gz instead of zip. Keep the module structure flat -- a single `lib/backup.sh` file with all backup/restore logic.

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- `docker commit` + `docker save` (image-based backup, matching Windows approach)
- Captures both container image AND workspace volume as separate archives
- Workspace archived as tar.gz (native Linux format, smaller than zip)
- Image saved via `docker save` (produces image.tar, then compressed to image.tar.gz)
- Backup naming: timestamp folders `backups/{instance}/YYYYMMDD-HHMM/` containing image.tar.gz, workspace.tar.gz, metadata.json
- Metadata includes image tag, instance name, port, container type
- Replace in-place restore: stop current container, load backup image, overwrite workspace, start from backup
- Same instance name and port preserved on restore
- Backup selection: numbered list newest-first with size, like Windows UX
- Confirmation: user types YES before destructive overwrite
- Post-restore: auto-start container + prompt "SSH into instance now? (y/N)"
- Credentials injected from current .env into restored container via -e flags
- Auto-backup triggers before instance start when CSM_AUTO_BACKUP=1 in .env
- No auto-cleanup of old backups
- Brief status output for auto-backup
- [B] Backup and [E] Restore added to action menu
- New `lib/backup.sh` module
- Windows PowerShell scripts left unchanged

### Claude's Discretion
- Exact metadata.json schema beyond required fields
- Error handling for partial/failed backups (cleanup strategy)
- How to calculate and display backup sizes
- docker commit tag naming convention
- Whether to check available disk space before backup

### Deferred Ideas (OUT OF SCOPE)
None -- discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| BACK-01 | User can manually trigger full container backup | `backup_create()` function in lib/backup.sh; uses `docker commit` + `docker save` + `tar` for workspace |
| BACK-02 | Optional auto-backup on instance startup (togglable via settings) | CSM_AUTO_BACKUP=1 in .env; hook in `docker_start_instance()` before container start |
| BACK-03 | Backup captures both container filesystem and workspace volume data | Image saved as image.tar.gz via `docker save`; workspace saved as workspace.tar.gz via `tar czf` |
| BACK-04 | User can restore an instance from a backup | `backup_restore()` function; stops container, loads image, overwrites workspace, restarts with credentials |
</phase_requirements>

## Standard Stack

### Core
| Tool | Version | Purpose | Why Standard |
|------|---------|---------|--------------|
| docker commit | Docker CLI | Capture running container state to image | Only way to snapshot container filesystem changes |
| docker save | Docker CLI | Export image to tar archive | Standard Docker image portability mechanism |
| docker load | Docker CLI | Import image from tar archive | Counterpart to docker save |
| tar + gzip | System | Archive workspace directory | Native Linux/macOS, no dependencies, smaller than zip |
| jq | System | Read/write metadata.json | Already a project dependency (platform.sh checks for it) |

### Supporting
| Tool | Purpose | When to Use |
|------|---------|-------------|
| du -sb / du -sk | Calculate backup directory size | Display size in backup listing |
| date +%Y%m%d-%H%M | Generate timestamp for backup folder names | Backup naming convention |
| stat / ls -l | Get file sizes | Display individual archive sizes |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| docker save | docker export | docker export loses image layers and history; docker save preserves the full image for `docker load` |
| tar.gz | zip | zip requires `zip` utility (not always present on minimal Linux); tar.gz is native and smaller |
| gzip | zstd | zstd is faster but not universally available; gzip is everywhere |

## Architecture Patterns

### Module Structure
```
lib/
├── backup.sh          # NEW: all backup/restore logic
├── common.sh          # existing: common_backup_dir() already defined
├── credentials.sh     # existing: credentials_load(), CSM_AUTO_BACKUP reading
├── docker.sh          # MODIFIED: auto-backup hook in docker_start_instance()
├── instances.sh       # existing: registry access for metadata
├── menu.sh            # MODIFIED: add B/E actions
├── platform.sh        # existing: no changes
└── ssh.sh             # existing: no changes
```

### Backup Directory Layout
```
backups/
└── {instance-name}/
    └── YYYYMMDD-HHMM/
        ├── image.tar.gz       # docker save output, gzipped
        ├── workspace.tar.gz   # workspace directory archived
        └── metadata.json      # instance metadata for restore
```

### Pattern 1: Backup Create Flow
**What:** Full snapshot of instance state (image + workspace + metadata)
**When to use:** Manual backup via menu [B] or auto-backup on startup

```bash
backup_create() {
    local name="$1"
    local container_name
    container_name="$(common_container_name "$name")"

    local timestamp
    timestamp="$(date +%Y%m%d-%H%M)"

    local backup_dir
    backup_dir="$(common_backup_dir "$name")/${timestamp}"
    mkdir -p "$backup_dir"

    # 1. Commit container state to tagged image
    local image_tag="${container_name}-backup-${timestamp}"
    msg_info "Committing container..."
    docker commit "$container_name" "$image_tag"

    # 2. Save + compress Docker image
    msg_info "Saving image..."
    docker save "$image_tag" | gzip > "${backup_dir}/image.tar.gz"

    # 3. Archive workspace
    msg_info "Archiving workspace..."
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"
    tar czf "${backup_dir}/workspace.tar.gz" -C "$workspace_dir" .

    # 4. Write metadata
    local port
    port="$(instances_get_port "$name")"
    local type
    type="$(instances_get_type "$name")"

    jq -n \
        --arg imagetag "$image_tag" \
        --arg instance "$name" \
        --argjson port "$port" \
        --arg type "$type" \
        --arg timestamp "$timestamp" \
        '{imagetag: $imagetag, instance: $instance, port: $port, type: $type, timestamp: $timestamp}' \
        > "${backup_dir}/metadata.json"

    # 5. Report size
    local size
    size="$(du -sh "$backup_dir" | cut -f1)"
    msg_ok "Backup complete: ${backup_dir} (${size})"
}
```

### Pattern 2: Restore Flow
**What:** Stop container, load backup image, overwrite workspace, restart
**When to use:** Manual restore via menu [E]

```bash
backup_restore() {
    local name="$1"
    local backup_dir="$2"  # full path to selected backup folder

    local container_name
    container_name="$(common_container_name "$name")"

    # Read image tag from metadata
    local image_tag
    image_tag="$(jq -r '.imagetag' "${backup_dir}/metadata.json")"

    # 1. Stop and remove current container
    msg_info "Stopping container..."
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true

    # 2. Load Docker image from backup
    msg_info "Loading image..."
    gunzip -c "${backup_dir}/image.tar.gz" | docker load

    # 3. Restore workspace
    msg_info "Restoring workspace..."
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"
    rm -rf "${workspace_dir:?}"/*          # safe: variable checked
    tar xzf "${backup_dir}/workspace.tar.gz" -C "$workspace_dir"

    # 4. Start container from backup image (reuse docker_run_instance pattern)
    local port
    port="$(instances_get_port "$name")"
    # ... build docker run command with credential injection ...
}
```

### Pattern 3: Auto-Backup Hook
**What:** Check CSM_AUTO_BACKUP before starting an instance
**When to use:** In `docker_start_instance()` before the build step

```bash
# In docker_start_instance(), after credentials_ensure_env_file:
credentials_load || true
if [[ "${CSM_AUTO_BACKUP:-}" == "1" ]]; then
    local status
    status="$(docker_status "$name")"
    if [[ "$status" == "running" || "$status" == "exited" ]]; then
        msg_info "Auto-backup: creating backup..."
        backup_create "$name"
    fi
fi
```

### Pattern 4: Backup Listing (Restore Selection)
**What:** Show numbered list of backups, newest first, with sizes
**When to use:** During restore flow before user selects which backup

```bash
backup_list() {
    local name="$1"
    local backup_root
    backup_root="$(common_backup_dir "$name")"

    # List directories sorted newest first
    local -a dirs=()
    while IFS= read -r -d '' dir; do
        dirs+=("$dir")
    done < <(find "$backup_root" -mindepth 1 -maxdepth 1 -type d -print0 | sort -z -r)

    if [[ ${#dirs[@]} -eq 0 ]]; then
        msg_warn "No backups found for '${name}'."
        return 1
    fi

    echo ""
    echo "Available backups for '${name}' (newest first):"
    local i
    for i in "${!dirs[@]}"; do
        local dirname
        dirname="$(basename "${dirs[$i]}")"
        local size
        size="$(du -sh "${dirs[$i]}" | cut -f1)"
        echo "  [$((i + 1))] ${dirname}  (${size})"
    done

    # Return dirs array via global for caller to use
    _BACKUP_LISTED_DIRS=("${dirs[@]}")
}
```

### Anti-Patterns to Avoid
- **Using `docker export` instead of `docker save`:** `docker export` creates a flat filesystem tarball, losing image metadata, layers, and CMD/ENTRYPOINT. `docker save` preserves the full image for `docker load`.
- **Removing workspace with `rm -rf "$workspace_dir"`:** This would delete the workspace directory itself, breaking the volume mount. Use `rm -rf "${workspace_dir:?}"/*` to clear contents only.
- **Archiving workspace from container path:** The workspace is a bind mount. Always archive from the host-side path (`common_workspace_dir`), not from inside the container.
- **Piping docker save through gzip without error checking:** If `docker save` fails mid-pipe, gzip will happily create a truncated archive. Use `set -o pipefail` (already set via `set -euo pipefail` in bin/csm) to catch this.
- **Forgetting to source backup.sh in bin/csm:** The new module must be added to the source chain in dependency order (after docker.sh, before menu.sh since menu dispatches to backup functions).

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Image archival | Custom filesystem copy | `docker save` + `docker load` | Preserves image layers, metadata, tags correctly |
| Compression | Custom compression logic | `gzip` via pipe (`docker save \| gzip`) | Streaming compression, no temp files needed |
| Workspace archival | Recursive file copy | `tar czf` | Handles permissions, symlinks, hidden files, empty dirs |
| JSON metadata | Manual string concatenation | `jq -n` with `--arg` | Proper JSON escaping, no injection risks |
| Instance selection | Custom prompt loop | Existing `menu_select_instance()` | Already handles single-instance auto-select |

**Key insight:** The PowerShell implementation is the spec. Every Docker command is platform-independent -- only the shell syntax and archive utilities differ.

## Common Pitfalls

### Pitfall 1: rm -rf with Empty Variable
**What goes wrong:** If `$workspace_dir` is empty, `rm -rf /` occurs
**Why it happens:** Variable expansion with unset variable in cleanup paths
**How to avoid:** Always use `${workspace_dir:?}` (Bash fails if empty/unset) and never `rm -rf "$var"` without the guard
**Warning signs:** ShellCheck SC2115 will flag `rm -rf "$var"/`

### Pitfall 2: docker commit on Stopped Container
**What goes wrong:** `docker commit` succeeds on stopped containers but captures the stopped state
**Why it happens:** Container may have been stopped before backup was initiated
**How to avoid:** This is actually fine for backup purposes -- the committed image includes all filesystem changes regardless of running state. For auto-backup, the container IS in a stopped/running state from the previous session. No special handling needed.

### Pitfall 3: Backup of Non-Existent Container
**What goes wrong:** `docker commit` fails if the container was never started or was removed
**Why it happens:** Instance is registered but container doesn't exist in Docker
**How to avoid:** Check `docker_status()` before attempting backup. If status is "not created", skip with a clear error message.

### Pitfall 4: Disk Space Exhaustion During Backup
**What goes wrong:** `docker save | gzip` or `tar czf` fails mid-write, leaving partial archive
**Why it happens:** Large containers can produce multi-GB images
**How to avoid:** Discretion item -- optionally check available space with `df`. For partial failures, clean up the incomplete backup directory entirely.

### Pitfall 5: Restore Starts Container Without Credential Injection
**What goes wrong:** Restored container runs without ANTHROPIC_API_KEY, GITHUB_TOKEN
**Why it happens:** PowerShell restore script uses raw `docker run` without credential flags
**How to avoid:** Bash restore MUST reuse the credential injection pattern from `docker_run_instance()` (load .env, build -e flags). The CONTEXT.md explicitly requires this.

### Pitfall 6: tar Extracts with Wrong Ownership
**What goes wrong:** Files in restored workspace owned by root instead of the user
**Why it happens:** `tar xzf` preserves ownership from archive, which may be a different UID
**How to avoid:** Use `tar xzf --no-same-owner` to extract with current user ownership. The Docker bind mount will map to the container's `claude` user via UID.

### Pitfall 7: Restoring into Running Container
**What goes wrong:** Workspace files locked/in-use while being overwritten
**Why it happens:** Container still running when restore begins workspace overwrite
**How to avoid:** Always stop and remove the container BEFORE touching workspace files. The restore flow does this (stop -> rm -> load image -> restore workspace -> run).

## Code Examples

### Reading CSM_AUTO_BACKUP from .env
The existing `credentials_load()` function already parses ALL key=value pairs from .env and exports them. After calling `credentials_load`, `CSM_AUTO_BACKUP` will be available as an environment variable if set.

```bash
# No special parsing needed -- credentials_load handles it
credentials_load || true
if [[ "${CSM_AUTO_BACKUP:-}" == "1" ]]; then
    # auto-backup is enabled
fi
```

### Streaming docker save through gzip (no temp file)
```bash
# Pipe directly -- avoids writing uncompressed image.tar to disk
docker save "$image_tag" | gzip > "${backup_dir}/image.tar.gz"

# Restore: pipe gunzip into docker load
gunzip -c "${backup_dir}/image.tar.gz" | docker load
```

### Calculating and displaying backup sizes
```bash
# Total directory size (human-readable)
du -sh "$backup_dir" | cut -f1    # e.g., "245M"

# Individual file sizes
stat --format="%s" "$file" 2>/dev/null || stat -f "%z" "$file"  # Linux vs macOS stat
```
Note: `stat` syntax differs between Linux and macOS. Use `du -sh` for portable size display, or detect platform with `$CSM_PLATFORM`.

### Restore docker run -- reuse existing security hardening
```bash
# Build the run command the same way docker_run_instance does
# but use the BACKUP image tag instead of the standard build tag
local cmd=(docker run -d)
cmd+=(--name "$container_name")
cmd+=(-p "127.0.0.1:${port}:22")
cmd+=(-v "${workspace_dir}:/home/claude/workspace")
cmd+=(-w /home/claude/workspace)
cmd+=(--memory=2g)
cmd+=(--cpus=2)
cmd+=(--security-opt=no-new-privileges)
cmd+=(--cap-drop=MKNOD --cap-drop=AUDIT_WRITE --cap-drop=SETFCAP)
cmd+=(--cap-drop=SETPCAP --cap-drop=NET_BIND_SERVICE)
cmd+=(--cap-drop=SYS_CHROOT --cap-drop=FSETID)
cmd+=(--restart unless-stopped)

# Inject current credentials
credentials_load || true
credentials_get_docker_env_flags
cmd+=("${CSM_DOCKER_ENV_FLAGS[@]}")

# Use backup image tag (not the standard build tag)
cmd+=("$image_tag")

"${cmd[@]}"
```

**Important:** The restore container run MUST include the same security hardening flags as `docker_run_instance()`. Factor this into a shared helper or duplicate the array construction. A shared helper (e.g., `docker_build_run_cmd()`) is cleaner but may be over-engineering for this phase.

### Menu integration pattern
```bash
# In menu_show_actions(), add after [R]:
echo "  [B] Backup an instance"
echo "  [E] Restore an instance"

# In menu_main() case statement, add:
b) menu_action_backup ;;
e) menu_action_restore ;;
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| `docker export` (flat tarball) | `docker save` (layered image) | Project design decision | Preserves full image for `docker load`; more space but more complete |
| Windows zip archives | tar.gz on Linux/macOS | This phase | Native tool, no zip dependency, better compression |
| Manual backup only | Auto-backup on startup toggle | This phase | Safety net for session state |

## Open Questions

1. **Shared docker run helper vs. duplication**
   - What we know: `docker_run_instance()` builds a complex command array with security flags and credential injection. Restore needs the same but with a different image tag.
   - What's unclear: Whether to extract a shared `_docker_build_run_cmd()` helper or duplicate the array in backup_restore.
   - Recommendation: Extract a minimal helper that returns the base command array, parameterized by image tag. This avoids security flag drift between create and restore paths.

2. **Backup of containers with "not created" status**
   - What we know: If instance is registered but container was never started, `docker commit` will fail.
   - Recommendation: Check docker_status first; skip with `msg_warn` if "not created". Auto-backup should silently skip (no container to back up yet).

3. **macOS stat vs Linux stat**
   - What we know: `stat --format` (GNU) vs `stat -f` (BSD/macOS) for file sizes.
   - Recommendation: Use `du -sh` for human-readable size display (portable). Only use `stat` if byte-precise sizes needed in metadata.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | BATS (Bash Automated Testing System) |
| Config file | none -- tests run via `bats tests/` |
| Quick run command | `bats tests/backup.bats` |
| Full suite command | `bats tests/` |

### Phase Requirements -> Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| BACK-01 | backup_create creates image.tar.gz, workspace.tar.gz, metadata.json | unit (mock docker) | `bats tests/backup.bats -f "backup_create"` | No -- Wave 0 |
| BACK-02 | Auto-backup triggered when CSM_AUTO_BACKUP=1 and container exists | unit | `bats tests/backup.bats -f "auto.backup"` | No -- Wave 0 |
| BACK-03 | Backup captures both image and workspace archives | unit | `bats tests/backup.bats -f "captures both"` | No -- Wave 0 |
| BACK-04 | backup_restore loads image, restores workspace, starts container | unit (mock docker) | `bats tests/backup.bats -f "backup_restore"` | No -- Wave 0 |

### Sampling Rate
- **Per task commit:** `bats tests/backup.bats`
- **Per wave merge:** `bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/backup.bats` -- covers BACK-01 through BACK-04
- [ ] Docker mocking strategy -- backup tests need docker commit/save/load mocked (use function override pattern already seen in other BATS tests)

## Sources

### Primary (HIGH confidence)
- `scripts/backup-claude.ps1` -- reference implementation for backup flow
- `scripts/restore-claude.ps1` -- reference implementation for restore flow
- `scripts/common.ps1` -- PowerShell helper functions showing Windows patterns
- `lib/docker.sh` -- existing Bash Docker operations and security hardening
- `lib/credentials.sh` -- .env parsing already supports arbitrary KEY=VALUE pairs
- `lib/menu.sh` -- existing menu dispatch pattern for integration
- `lib/common.sh` -- `common_backup_dir()` already defined

### Secondary (MEDIUM confidence)
- Docker CLI docs for `docker commit`, `docker save`, `docker load` -- stable APIs, well-documented

### Tertiary (LOW confidence)
- None -- all research based on existing codebase and stable Docker CLI

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH -- uses Docker CLI (stable) + standard Unix tools (tar, gzip, jq)
- Architecture: HIGH -- direct port of working Windows implementation with clear code reference
- Pitfalls: HIGH -- identified from code review of both PowerShell reference and Bash codebase patterns

**Research date:** 2026-03-13
**Valid until:** Indefinitely -- Docker CLI backup APIs are stable; project patterns established in Phase 1-2
