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
# _docker_detect_variant -- Detect whether running Docker Desktop or Engine
# Returns: "desktop" or "engine" (stdout)
# ---------------------------------------------------------------------------
_docker_detect_variant() {
    local ctx
    ctx="$(docker context show 2>/dev/null || echo "default")"
    if [[ "$ctx" == "desktop-linux" ]]; then echo "desktop"; return; fi
    if docker context inspect desktop-linux &>/dev/null 2>&1; then echo "desktop"; return; fi
    echo "engine"
}

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
    local type
    type="$(instances_get_type "$name")"
    local target="${type}"
    local image_tag="claude-sandbox-${name}-${type}"

    msg_info "Building Docker image ${image_tag} (target: ${target})..."
    if ! docker build -t "$image_tag" --target "$target" -f "${CSM_ROOT}/scripts/Dockerfile" "$CSM_ROOT"; then
        die "Docker build failed for ${image_tag}"
    fi
    msg_ok "Docker image built: ${image_tag}"
}

# ---------------------------------------------------------------------------
# _docker_build_run_cmd -- Build the full docker run command array
# Args: $1 = instance name, $2 = SSH port, $3 = image tag
# Populates: _DOCKER_RUN_CMD global array with full docker run command
# ---------------------------------------------------------------------------
_docker_build_run_cmd() {
    local name="$1"
    local port="$2"
    local image_tag="$3"
    local container_name
    container_name="$(common_container_name "$name")"
    local workspace_dir
    workspace_dir="$(common_workspace_dir "$name")"

    # Read instance type for type-aware configuration
    local type
    type="$(instances_get_type "$name")"

    _DOCKER_RUN_CMD=(docker run -d)
    _DOCKER_RUN_CMD+=(--name "$container_name")
    _DOCKER_RUN_CMD+=(-p "127.0.0.1:${port}:22")                # SEC-02: bind SSH to localhost only
    _DOCKER_RUN_CMD+=(-v "${workspace_dir}:/home/claude/workspace")
    _DOCKER_RUN_CMD+=(-w /home/claude/workspace)
    local mem_limit cpu_limit
    mem_limit="$(settings_get '.defaults.memory_limit')"
    cpu_limit="$(settings_get '.defaults.cpu_limit')"
    _DOCKER_RUN_CMD+=(--memory="${mem_limit:-2g}")                # SEC-04: memory limit (from config)
    _DOCKER_RUN_CMD+=(--cpus="${cpu_limit:-2}")                   # SEC-04: CPU limit (from config)
    _DOCKER_RUN_CMD+=(--security-opt=no-new-privileges)           # SEC-04: no privilege escalation
    _DOCKER_RUN_CMD+=(--cap-drop=MKNOD)                          # SEC-03: drop unnecessary capabilities
    _DOCKER_RUN_CMD+=(--cap-drop=SETFCAP)                        # SEC-03: (AUDIT_WRITE and SYS_CHROOT
    _DOCKER_RUN_CMD+=(--cap-drop=SETPCAP)                        # SEC-03:  intentionally retained --
    _DOCKER_RUN_CMD+=(--cap-drop=NET_BIND_SERVICE)               # SEC-03:  sshd needs them for PTY
    _DOCKER_RUN_CMD+=(--cap-drop=FSETID)                         # SEC-03:  alloc and privsep chroot)
    _DOCKER_RUN_CMD+=(--restart unless-stopped)

    # GUI-specific flags: shared memory and noVNC port mapping
    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        _DOCKER_RUN_CMD+=(-p "127.0.0.1:${vnc_port}:6080")      # noVNC WebSocket port
        _DOCKER_RUN_CMD+=(--shm-size=512m)                       # Shared memory for browser/GPU
    fi

    # MCP: ensure host.docker.internal resolves on Linux Engine
    if [[ "$(uname -s)" == "Linux" ]]; then
        local docker_variant
        docker_variant="$(_docker_detect_variant)"
        if [[ "$docker_variant" == "engine" ]]; then
            _DOCKER_RUN_CMD+=(--add-host=host.docker.internal:host-gateway)
        fi
    fi

    # Inject credentials as -e flags (from .env via credentials module)
    credentials_load || true
    credentials_get_docker_env_flags "$name"
    _DOCKER_RUN_CMD+=("${CSM_DOCKER_ENV_FLAGS[@]}")

    _DOCKER_RUN_CMD+=("$image_tag")
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

    # Read instance type for image tag construction
    local type
    type="$(instances_get_type "$name")"
    local image_tag="claude-sandbox-${name}-${type}"

    # Ensure workspace directory exists
    mkdir -p "$workspace_dir"

    # Remove existing container first (BUG-01: prevent orphaned containers)
    docker rm -f "$container_name" 2>/dev/null || true

    # Build docker run command using shared helper
    _docker_build_run_cmd "$name" "$port" "$image_tag"

    msg_info "Starting container ${container_name} on port ${port}..."
    if ! "${_DOCKER_RUN_CMD[@]}"; then
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
    if [[ "$(settings_get_bool '.backup.auto_backup')" == "true" ]]; then
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
