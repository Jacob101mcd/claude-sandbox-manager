#!/usr/bin/env bash
# lib/credentials.sh -- .env file parsing and credential management
#
# This file is sourced by bin/csm. Do not execute directly.
# CSM_ROOT must be set by the entry point before sourcing this file.
#
# Provides: credentials_ensure_env_file, credentials_load, credentials_get_docker_env_flags

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# Known credential variable names
_CREDENTIALS_KNOWN_KEYS=(ANTHROPIC_API_KEY GITHUB_TOKEN)

# ---------------------------------------------------------------------------
# credentials_ensure_env_file -- Create a template .env if none exists
# ---------------------------------------------------------------------------
credentials_ensure_env_file() {
    local env_file="${CSM_ROOT}/.env"

    if [[ -f "$env_file" ]]; then
        return 0
    fi

    cat > "$env_file" <<'TEMPLATE'
# Claude Sandbox Manager -- Credentials
#
# Fill in the values below. This file is gitignored and never baked into images.
# Lines starting with # are comments. Blank lines are ignored.

# Required: Anthropic API key for Claude Code
ANTHROPIC_API_KEY=

# Optional: GitHub personal access token for gh CLI inside the container
GITHUB_TOKEN=
TEMPLATE

    msg_warn "Created template .env file at ${env_file} -- please add your credentials"
}

# ---------------------------------------------------------------------------
# credentials_load -- Parse .env file and export variables
# Returns: 0 on success, 1 if .env file does not exist
# ---------------------------------------------------------------------------
credentials_load() {
    local env_file="${CSM_ROOT}/.env"

    if [[ ! -f "$env_file" ]]; then
        return 1
    fi

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Skip blank lines
        [[ -z "$line" ]] && continue

        # Skip comment lines
        [[ "$line" =~ ^[[:space:]]*# ]] && continue

        # Extract KEY=VALUE (only split on first =)
        local key="${line%%=*}"
        local value="${line#*=}"

        # Skip lines without =
        [[ "$key" == "$line" ]] && continue

        # Strip leading/trailing whitespace from key
        key="$(echo "$key" | xargs)"

        # Strip surrounding quotes from value (single or double)
        if [[ "$value" =~ ^\"(.*)\"$ ]]; then
            value="${BASH_REMATCH[1]}"
        elif [[ "$value" =~ ^\'(.*)\'$ ]]; then
            value="${BASH_REMATCH[1]}"
        fi

        export "$key=$value"
    done < "$env_file"

    return 0
}

# ---------------------------------------------------------------------------
# credentials_get_docker_env_flags -- Build docker -e flags for set credentials
# Args: $1 = instance name (optional) -- when provided, injects MCP/RC flags
# Populates global array CSM_DOCKER_ENV_FLAGS
# ---------------------------------------------------------------------------
credentials_get_docker_env_flags() {
    local instance_name="${1:-}"
    CSM_DOCKER_ENV_FLAGS=()

    local key
    for key in "${_CREDENTIALS_KNOWN_KEYS[@]}"; do
        if [[ -n "${!key:-}" ]]; then
            CSM_DOCKER_ENV_FLAGS+=("-e" "${key}=${!key}")
        else
            msg_warn "Credential ${key} is not set -- it will not be passed to the container"
        fi
    done

    # Integration flags: MCP and remote control env vars (requires instance context)
    if [[ -n "$instance_name" ]]; then
        local mcp_enabled
        mcp_enabled="$(instances_get_mcp_enabled "$instance_name")"
        if [[ "$mcp_enabled" == "true" ]]; then
            local mcp_port
            mcp_port="$(settings_get '.integrations.mcp_port')"
            CSM_DOCKER_ENV_FLAGS+=("-e" "CSM_MCP_ENABLED=1")
            CSM_DOCKER_ENV_FLAGS+=("-e" "CSM_MCP_PORT=${mcp_port:-8811}")
        fi

        local remote_control
        remote_control="$(instances_get_remote_control "$instance_name")"
        if [[ "$remote_control" == "true" ]]; then
            CSM_DOCKER_ENV_FLAGS+=("-e" "CSM_REMOTE_CONTROL=1")
        fi
    fi
}
