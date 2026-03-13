#!/usr/bin/env bash
# lib/backup.sh -- Backup, restore, and listing logic for sandbox instances
#
# This file is sourced by bin/csm after common.sh, instances.sh, credentials.sh, and docker.sh.
# CSM_ROOT must be set by the entry point before sourcing this file.
#
# Provides: backup_create, backup_restore, backup_list

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# Global array populated by backup_list for caller use
_BACKUP_LISTED_DIRS=()

# ---------------------------------------------------------------------------
# backup_create -- Create a full backup of an instance
# Args: $1 = instance name
# Produces: image.tar.gz, workspace.tar.gz, metadata.json in timestamped dir
# ---------------------------------------------------------------------------
backup_create() {
    local name="$1"
    local container_name
    container_name="$(common_container_name "$name")"

    # Check container exists before trying to back it up
    local status
    status="$(docker_status "$name")"
    if [[ "$status" == "not created" ]]; then
        msg_warn "Instance '${name}' has no container to back up (not created)"
        return 1
    fi

    # Generate timestamp and create backup directory
    local timestamp
    timestamp="$(date +%Y%m%d-%H%M)"
    local backup_root
    backup_root="$(common_backup_dir "$name")"
    local backup_dir="${backup_root}/${timestamp}"

    mkdir -p "$backup_dir"

    # Step 1: Commit the container to create a new image layer
    local image_tag="${container_name}-backup-${timestamp}"
    msg_info "Committing container ${container_name}..."
    docker commit "$container_name" "$image_tag"

    # Step 2: Save the committed image as a gzipped tar
    msg_info "Saving image to ${backup_dir}/image.tar.gz..."
    docker save "$image_tag" | gzip > "${backup_dir}/image.tar.gz"

    # Step 3: Archive the workspace volume
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"
    msg_info "Archiving workspace to ${backup_dir}/workspace.tar.gz..."
    tar czf "${backup_dir}/workspace.tar.gz" -C "$workspace_dir" .

    # Step 4: Write metadata JSON
    local port type
    port="$(instances_get_port "$name")"
    type="$(instances_get_type "$name")"

    jq -n \
        --arg imagetag "$image_tag" \
        --arg instance "$name" \
        --argjson port "${port:-0}" \
        --arg type "$type" \
        --arg timestamp "$timestamp" \
        '{imagetag: $imagetag, instance: $instance, port: $port, type: $type, timestamp: $timestamp}' \
        > "${backup_dir}/metadata.json.tmp" \
        && mv "${backup_dir}/metadata.json.tmp" "${backup_dir}/metadata.json"

    # Report completion with size
    local size
    size="$(du -sh "$backup_dir" | cut -f1)"
    msg_ok "Backup complete: ${backup_dir} (${size})"
}

# ---------------------------------------------------------------------------
# backup_list -- List available backups for an instance, newest-first
# Args: $1 = instance name
# Populates: _BACKUP_LISTED_DIRS global array
# Returns: 0 on success, 1 if no backups found
# ---------------------------------------------------------------------------
backup_list() {
    local name="$1"
    local backup_root
    backup_root="$(common_backup_dir "$name")"

    _BACKUP_LISTED_DIRS=()

    if [[ ! -d "$backup_root" ]]; then
        msg_warn "No backups found for instance '${name}'"
        return 1
    fi

    # Collect backup directories sorted reverse (newest first by name)
    local dirs=()
    while IFS= read -r dir; do
        dirs+=("$dir")
    done < <(find "$backup_root" -mindepth 1 -maxdepth 1 -type d | sort -r)

    if [[ "${#dirs[@]}" -eq 0 ]]; then
        msg_warn "No backups found for instance '${name}'"
        return 1
    fi

    # Display numbered list with sizes
    local i=1
    local dir size
    for dir in "${dirs[@]}"; do
        size="$(du -sh "$dir" 2>/dev/null | cut -f1)"
        printf "  %d) %s (%s)\n" "$i" "$(basename "$dir")" "${size:-?}"
        _BACKUP_LISTED_DIRS+=("$dir")
        (( i++ ))
    done

    return 0
}

# ---------------------------------------------------------------------------
# backup_restore -- Restore an instance from a backup directory
# Args: $1 = instance name, $2 = path to backup directory
#
# NOTE: The docker run command below must stay in sync with docker_run_instance
# in lib/docker.sh. It duplicates those flags so the restore uses the backup
# image tag instead of the default "claude-sandbox-{name}" tag.
# ---------------------------------------------------------------------------
backup_restore() {
    local name="$1"
    local backup_dir="$2"
    local container_name
    container_name="$(common_container_name "$name")"
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"

    # Read image tag from metadata
    local image_tag
    image_tag="$(jq -r '.imagetag' "${backup_dir}/metadata.json")"

    msg_info "Restoring instance '${name}' from backup..."

    # Step 1: Stop and remove existing container
    msg_info "Stopping existing container..."
    docker stop "$container_name" 2>/dev/null || true
    docker rm "$container_name" 2>/dev/null || true

    # Step 2: Load backup image
    msg_info "Loading backup image..."
    gunzip -c "${backup_dir}/image.tar.gz" | docker load

    # Step 3: Clear and restore workspace
    msg_info "Restoring workspace..."
    mkdir -p "$workspace_dir"
    rm -rf "${workspace_dir:?}"/*
    tar xzf "${backup_dir}/workspace.tar.gz" --no-same-owner -C "$workspace_dir"

    # Step 4: Get port for this instance
    local port
    port="$(instances_get_port "$name")"

    # Step 5: Build docker run command (mirrors docker_run_instance in docker.sh)
    # NOTE: Keep these flags in sync with docker_run_instance in lib/docker.sh
    local cmd=(docker run -d)
    cmd+=(--name "$container_name")
    cmd+=(-p "127.0.0.1:${port}:22")                # SEC-02: bind SSH to localhost only
    cmd+=(-v "${workspace_dir}:/home/claude/workspace")
    cmd+=(-w /home/claude/workspace)
    cmd+=(--memory=2g)                                # SEC-04: memory limit
    cmd+=(--cpus=2)                                   # SEC-04: CPU limit
    cmd+=(--security-opt=no-new-privileges)           # SEC-04: no privilege escalation
    cmd+=(--cap-drop=MKNOD)                           # SEC-03: drop capabilities
    cmd+=(--cap-drop=AUDIT_WRITE)                     # SEC-03
    cmd+=(--cap-drop=SETFCAP)                         # SEC-03
    cmd+=(--cap-drop=SETPCAP)                         # SEC-03
    cmd+=(--cap-drop=NET_BIND_SERVICE)                # SEC-03
    cmd+=(--cap-drop=SYS_CHROOT)                      # SEC-03
    cmd+=(--cap-drop=FSETID)                          # SEC-03
    cmd+=(--restart unless-stopped)

    # Inject credentials from current .env into restored container
    credentials_load || true
    credentials_get_docker_env_flags
    cmd+=("${CSM_DOCKER_ENV_FLAGS[@]}")

    # Use backup image tag (not the default build image)
    cmd+=("$image_tag")

    msg_info "Starting restored container on port ${port}..."
    if ! "${cmd[@]}"; then
        msg_error "Failed to start container from backup image"
        return 1
    fi

    msg_ok "Restore complete. Instance '${name}' running from backup."
}
