#!/usr/bin/env bash
# lib/docker.sh -- Docker container operations with security hardening
#
# This file is sourced by bin/csm after common.sh, instances.sh, and ssh.sh.
# Handles building, running, stopping, and removing sandbox containers.
#
# Provides: docker_check_running, docker_build, docker_run_instance,
#           docker_stop, docker_remove, docker_status, docker_start_instance

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# ---------------------------------------------------------------------------
# docker_check_running -- Verify Docker daemon is accessible
# ---------------------------------------------------------------------------
docker_check_running() {
    if ! docker info &>/dev/null; then
        die "Docker is not running. Please start Docker and try again."
    fi
}

# ---------------------------------------------------------------------------
# docker_build -- Build the sandbox Docker image for an instance
# Args: $1 = instance name
# ---------------------------------------------------------------------------
docker_build() {
    local name="$1"
    local image_tag="claude-sandbox-${name}"

    msg_info "Building Docker image ${image_tag}..."
    if ! docker build -t "$image_tag" -f "${CSM_ROOT}/scripts/Dockerfile" "$CSM_ROOT"; then
        die "Docker build failed for ${image_tag}"
    fi
    msg_ok "Docker image built: ${image_tag}"
}

# ---------------------------------------------------------------------------
# docker_run_instance -- Start a container with full security hardening
# Args: $1 = instance name, $2 = SSH port
# ---------------------------------------------------------------------------
docker_run_instance() {
    local name="$1"
    local port="$2"
    local container_name
    container_name="$(common_container_name "$name")"
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"

    # Ensure workspace directory exists
    mkdir -p "$workspace_dir"

    # Remove existing container first (BUG-01: prevent orphaned containers)
    docker rm -f "$container_name" 2>/dev/null || true

    # Build docker run command using array (best practice for complex commands)
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

    # Inject credentials as -e flags (from .env via credentials module)
    credentials_load || true
    credentials_get_docker_env_flags
    cmd+=("${CSM_DOCKER_ENV_FLAGS[@]}")

    cmd+=("claude-sandbox-${name}")

    msg_info "Starting container ${container_name} on port ${port}..."
    if ! "${cmd[@]}"; then
        die "Failed to start container ${container_name}"
    fi
    msg_ok "Container ${container_name} running on port ${port}"
}

# ---------------------------------------------------------------------------
# docker_stop -- Stop a running container
# Args: $1 = instance name
# ---------------------------------------------------------------------------
docker_stop() {
    local name="$1"
    docker stop "$(common_container_name "$name")" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# docker_remove -- Stop and remove a container
# Args: $1 = instance name
# ---------------------------------------------------------------------------
docker_remove() {
    local name="$1"
    docker stop "$(common_container_name "$name")" 2>/dev/null || true
    docker rm "$(common_container_name "$name")" 2>/dev/null || true
}

# ---------------------------------------------------------------------------
# docker_status -- Get the current status of a container
# Args: $1 = instance name
# Returns: status string (stdout) e.g. "running", "exited", "not created"
# ---------------------------------------------------------------------------
docker_status() {
    local name="$1"
    docker inspect --format '{{.State.Status}}' "$(common_container_name "$name")" 2>/dev/null || echo "not created"
}

# ---------------------------------------------------------------------------
# docker_start_instance -- Full orchestration: keys -> build -> run -> config
# Args: $1 = instance name
# Returns: allocated port (stdout, last line)
# ---------------------------------------------------------------------------
docker_start_instance() {
    local name="$1"

    # Ensure .env template exists on first use
    credentials_ensure_env_file

    # Auto-backup: capture last-known-good state before starting
    credentials_load || true
    if [[ "${CSM_AUTO_BACKUP:-}" == "1" ]]; then
        local status
        status="$(docker_status "$name")"
        if [[ "$status" == "running" || "$status" == "exited" ]]; then
            msg_info "Auto-backup: creating backup..."
            backup_create "$name"
        fi
    fi

    docker_check_running

    # 1. Ensure SSH keys exist
    ssh_ensure_keys "$name"

    # 2. Stage keys for Docker build
    ssh_stage_build_keys "$name"

    # 3. Get or allocate port
    local port
    port="$(instances_get_port "$name")"
    if [[ -z "$port" ]]; then
        port="$(instances_add "$name")"
    fi

    # 4. Build the Docker image
    docker_build "$name"

    # 5. Run the container with security hardening
    docker_run_instance "$name" "$port"

    # 6. Write SSH config for easy access
    ssh_write_config "$name" "$port"

    msg_ok "Instance '${name}' ready on port ${port}"
    echo "$port"
}
