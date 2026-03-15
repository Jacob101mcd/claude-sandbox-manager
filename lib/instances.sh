#!/usr/bin/env bash
# lib/instances.sh -- Instance registry CRUD, port allocation, orphan detection
#
# This file is sourced by bin/csm after common.sh.
# Manages .instances.json in CSM_ROOT using jq with atomic write patterns.
#
# Provides: instances_get_all, instances_add, instances_remove,
#           instances_get_port, instances_next_free_port,
#           instances_get_vnc_port, instances_next_free_vnc_port,
#           instances_detect_orphans, instances_list_with_status,
#           instances_get_mcp_enabled, instances_get_remote_control,
#           instances_set_mcp_enabled, instances_set_remote_control

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
# Args: $1 = instance name, $2 = container type (default: "cli")
# Returns: allocated port number (stdout)
# ---------------------------------------------------------------------------
instances_add() {
    local name="$1"
    local type="${2:-cli}"
    local port

    _instances_ensure_file

    port="$(instances_next_free_port)"

    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_next_free_vnc_port)"
        jq --arg name "$name" --argjson port "$port" --arg type "$type" --argjson vnc_port "$vnc_port" \
            --argjson mcp_enabled true --argjson remote_control false \
            '.[$name] = { "port": $port, "type": $type, "vnc_port": $vnc_port, "mcp_enabled": $mcp_enabled, "remote_control": $remote_control }' \
            "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
            && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
    else
        jq --arg name "$name" --argjson port "$port" --arg type "$type" \
            --argjson mcp_enabled true --argjson remote_control false \
            '.[$name] = { "port": $port, "type": $type, "mcp_enabled": $mcp_enabled, "remote_control": $remote_control }' \
            "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
            && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
    fi

    echo "$port"
}

# ---------------------------------------------------------------------------
# instances_get_type -- Look up the container type for a named instance
# Args: $1 = instance name
# Returns: type string (stdout), defaults to "cli" for backward compat
# ---------------------------------------------------------------------------
instances_get_type() {
    local name="$1"

    _instances_ensure_file

    local raw type
    raw="$(jq -r --arg name "$name" '.[$name].type // "cli"' "$_INSTANCES_FILE")"
    # Strip whitespace and validate; fall back to "cli" for any corrupted value
    type="$(printf '%s' "$raw" | tr -d '[:space:]' | grep -oE '(gui|cli)$')" || true
    echo "${type:-cli}"
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
# instances_next_free_vnc_port -- Find next available VNC/noVNC port starting at 6080
# Checks both the registry and actual system port usage (via ss)
# Returns: port number (stdout)
# ---------------------------------------------------------------------------
instances_next_free_vnc_port() {
    local port=6080

    _instances_ensure_file

    # Collect vnc_ports already allocated in the registry
    local registry_vnc_ports
    registry_vnc_ports="$(jq -r '.[].vnc_port // empty' "$_INSTANCES_FILE" 2>/dev/null)"

    while true; do
        # Check if port is in registry
        local in_registry=false
        local rp
        for rp in $registry_vnc_ports; do
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
# instances_get_vnc_port -- Look up the noVNC port for a named GUI instance
# Args: $1 = instance name
# Returns: vnc_port number (stdout), or empty if not set (CLI instances)
# ---------------------------------------------------------------------------
instances_get_vnc_port() {
    local name="$1"

    _instances_ensure_file

    jq -r --arg name "$name" '.[$name].vnc_port // empty' "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_set_vnc_port -- Set/update the VNC port for a named instance
# Args: $1 = instance name, $2 = vnc_port
# ---------------------------------------------------------------------------
instances_set_vnc_port() {
    local name="$1"
    local vnc_port="$2"

    _instances_ensure_file

    jq --arg name "$name" --argjson vnc_port "$vnc_port" \
        '.[$name].vnc_port = $vnc_port' \
        "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
        && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_get_mcp_enabled -- Look up the mcp_enabled flag for a named instance
# Args: $1 = instance name
# Returns: "true" or "false" (stdout); defaults to "true" for backward compat
# ---------------------------------------------------------------------------
instances_get_mcp_enabled() {
    local name="$1"

    _instances_ensure_file

    jq -r --arg name "$name" 'if (.[$name] | has("mcp_enabled")) then (.[$name].mcp_enabled | tostring) else "true" end' "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_get_remote_control -- Look up the remote_control flag for a named instance
# Args: $1 = instance name
# Returns: "true" or "false" (stdout); defaults to "false" for backward compat
# ---------------------------------------------------------------------------
instances_get_remote_control() {
    local name="$1"

    _instances_ensure_file

    jq -r --arg name "$name" 'if (.[$name] | has("remote_control")) then (.[$name].remote_control | tostring) else "false" end' "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_set_mcp_enabled -- Update the mcp_enabled flag for an instance
# Args: $1 = instance name, $2 = true|false
# ---------------------------------------------------------------------------
instances_set_mcp_enabled() {
    local name="$1"
    local value="$2"

    _instances_ensure_file

    local bool_val
    if [[ "$value" == "true" ]]; then bool_val="true"; else bool_val="false"; fi

    jq --arg name "$name" --argjson val "$bool_val" \
        '.[$name].mcp_enabled = $val' \
        "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
        && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
}

# ---------------------------------------------------------------------------
# instances_set_remote_control -- Update the remote_control flag for an instance
# Args: $1 = instance name, $2 = true|false
# ---------------------------------------------------------------------------
instances_set_remote_control() {
    local name="$1"
    local value="$2"

    _instances_ensure_file

    local bool_val
    if [[ "$value" == "true" ]]; then bool_val="true"; else bool_val="false"; fi

    jq --arg name "$name" --argjson val "$bool_val" \
        '.[$name].remote_control = $val' \
        "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
        && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
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

        local type
        type="$(instances_get_type "$name")"

        local status
        status="$(docker inspect --format '{{.State.Status}}' "$container_name" 2>/dev/null)" || status="not found"

        if [[ "$type" == "gui" ]]; then
            local vnc_port
            vnc_port="$(instances_get_vnc_port "$name")"
            msg_info "$name [$type] (ssh:$port vnc:$vnc_port) - $status"
        else
            msg_info "$name [$type] (port $port) - $status"
        fi
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
