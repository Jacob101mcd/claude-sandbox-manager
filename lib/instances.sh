#!/usr/bin/env bash
# lib/instances.sh -- Instance registry CRUD, port allocation, orphan detection
#
# This file is sourced by bin/csm after common.sh.
# Manages .instances.json in CSM_ROOT using jq with atomic write patterns.
#
# Provides: instances_get_all, instances_add, instances_remove,
#           instances_get_port, instances_next_free_port,
#           instances_detect_orphans, instances_list_with_status

# Registry file path
_INSTANCES_FILE="${CSM_ROOT}/.instances.json"

# ---------------------------------------------------------------------------
# Internal: ensure registry file exists
# ---------------------------------------------------------------------------
_instances_ensure_file() {
    if [[ ! -f "$_INSTANCES_FILE" ]]; then
        echo '{}' > "$_INSTANCES_FILE"
    fi
}

# ---------------------------------------------------------------------------
# instances_get_all -- Read full registry as JSON object
# Returns: JSON object (stdout), '{}' if empty/missing
# ---------------------------------------------------------------------------
instances_get_all() {
    _instances_ensure_file
    jq '.' "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_add -- Register a new instance with an allocated port
# Args: $1 = instance name
# Returns: allocated port number (stdout)
# ---------------------------------------------------------------------------
instances_add() {
    local name="$1"
    local port

    _instances_ensure_file

    port="$(instances_next_free_port)"

    jq --arg name "$name" --argjson port "$port" \
        '.[$name] = { "port": $port }' \
        "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
        && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"

    echo "$port"
}

# ---------------------------------------------------------------------------
# instances_remove -- Remove an instance from the registry
# Args: $1 = instance name
# ---------------------------------------------------------------------------
instances_remove() {
    local name="$1"

    _instances_ensure_file

    jq --arg name "$name" 'del(.[$name])' \
        "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
        && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_get_port -- Look up the SSH port for a named instance
# Args: $1 = instance name
# Returns: port number (stdout), or "null" if not found
# ---------------------------------------------------------------------------
instances_get_port() {
    local name="$1"

    _instances_ensure_file

    local port
    port="$(jq -r --arg name "$name" '.[$name].port // empty' "$_INSTANCES_FILE")"
    echo "$port"
}

# ---------------------------------------------------------------------------
# instances_next_free_port -- Find next available port starting at 2222
# Checks both the registry and actual system port usage (via ss)
# Returns: port number (stdout)
# ---------------------------------------------------------------------------
instances_next_free_port() {
    local port=2222

    _instances_ensure_file

    # Collect ports already allocated in the registry
    local registry_ports
    registry_ports="$(jq -r '.[].port' "$_INSTANCES_FILE" 2>/dev/null)"

    while true; do
        # Check if port is in registry
        local in_registry=false
        local rp
        for rp in $registry_ports; do
            if [[ "$rp" == "$port" ]]; then
                in_registry=true
                break
            fi
        done

        if $in_registry; then
            (( port++ ))
            continue
        fi

        # Check if port is in actual use on the system
        if command -v ss &>/dev/null; then
            if ss -tln 2>/dev/null | grep -q ":${port} "; then
                (( port++ ))
                continue
            fi
        fi

        break
    done

    echo "$port"
}

# ---------------------------------------------------------------------------
# instances_detect_orphans -- Find Docker containers not in the registry
# Compares docker ps against registry keys. Prints orphan container names.
# Returns: one container name per line (stdout), empty if none
# ---------------------------------------------------------------------------
instances_detect_orphans() {
    _instances_ensure_file

    # Get running + stopped containers matching our naming convention
    local docker_containers
    docker_containers="$(docker ps -a --filter "name=claude-sandbox-" --format '{{.Names}}' 2>/dev/null)" || return 0

    if [[ -z "$docker_containers" ]]; then
        return 0
    fi

    # Get registered instance names (as container names)
    local registered_names
    registered_names="$(jq -r 'keys[]' "$_INSTANCES_FILE" 2>/dev/null)"

    local container
    while IFS= read -r container; do
        # Extract instance name from container name (strip "claude-sandbox-" prefix)
        local instance_name="${container#claude-sandbox-}"

        # Check if this instance is registered
        local found=false
        local reg
        for reg in $registered_names; do
            if [[ "$reg" == "$instance_name" ]]; then
                found=true
                break
            fi
        done

        if ! $found; then
            echo "$container"
        fi
    done <<< "$docker_containers"
}

# ---------------------------------------------------------------------------
# instances_list_with_status -- List all instances with Docker status
# Includes both registered instances and orphans
# Returns: formatted status lines (stdout)
# ---------------------------------------------------------------------------
instances_list_with_status() {
    _instances_ensure_file

    local registered_names
    registered_names="$(jq -r 'keys[]' "$_INSTANCES_FILE" 2>/dev/null)"

    # List registered instances with their Docker status
    local name
    for name in $registered_names; do
        local port
        port="$(instances_get_port "$name")"
        local container_name
        container_name="$(common_container_name "$name")"

        local status
        status="$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null)" || status="not found"

        msg_info "$name (port $port) - $status"
    done

    # List orphans
    local orphans
    orphans="$(instances_detect_orphans)"
    if [[ -n "$orphans" ]]; then
        local orphan
        while IFS= read -r orphan; do
            msg_warn "$orphan [orphan]"
        done <<< "$orphans"
    fi
}
