#!/usr/bin/env bash
# lib/ssh.sh -- SSH key lifecycle management
#
# This file is sourced by bin/csm after common.sh.
# Handles key generation, build staging, and SSH config management.
#
# Provides: ssh_ensure_keys, ssh_stage_build_keys, ssh_write_config, ssh_remove_config

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# ---------------------------------------------------------------------------
# ssh_ensure_keys -- Generate ed25519 keypair and host key for an instance
# Args: $1 = instance name
# ---------------------------------------------------------------------------
ssh_ensure_keys() {
    local name="$1"
    local ssh_dir
    ssh_dir="$(common_ssh_dir "$name")"

    mkdir -p "$ssh_dir"

    # Generate client keypair if missing
    if [[ ! -f "${ssh_dir}/id_claude" ]]; then
        msg_info "Generating SSH keypair for ${name}..."
        ssh-keygen -t ed25519 -f "${ssh_dir}/id_claude" -N "" -C "claude-sandbox-${name}" -q
        chmod 600 "${ssh_dir}/id_claude"
        chmod 644 "${ssh_dir}/id_claude.pub"
        msg_ok "SSH keypair created"
    fi

    # Generate host key if missing
    if [[ ! -f "${ssh_dir}/ssh_host_ed25519_key" ]]; then
        msg_info "Generating SSH host key for ${name}..."
        ssh-keygen -t ed25519 -f "${ssh_dir}/ssh_host_ed25519_key" -N "" -C "host-${name}" -q
        chmod 600 "${ssh_dir}/ssh_host_ed25519_key"
        chmod 644 "${ssh_dir}/ssh_host_ed25519_key.pub"
        msg_ok "SSH host key created"
    fi
}

# ---------------------------------------------------------------------------
# ssh_stage_build_keys -- Copy SSH keys to _build_ssh/ for Docker build
# Args: $1 = instance name
# ---------------------------------------------------------------------------
ssh_stage_build_keys() {
    local name="$1"
    local ssh_dir
    ssh_dir="$(common_ssh_dir "$name")"
    local build_dir="${CSM_ROOT}/_build_ssh"

    # Clean and recreate staging directory
    rm -rf "$build_dir"
    mkdir -p "$build_dir"

    # Copy all keys to staging directory
    cp "${ssh_dir}/"* "$build_dir/"
}

# ---------------------------------------------------------------------------
# ssh_write_config -- Write SSH config block for an instance
# Args: $1 = instance name, $2 = SSH port
# ---------------------------------------------------------------------------
ssh_write_config() {
    local name="$1"
    local port="$2"
    local alias
    alias="$(common_ssh_alias "$name")"
    local ssh_dir
    ssh_dir="$(common_ssh_dir "$name")"

    # Ensure ~/.ssh directory exists
    mkdir -p "$HOME/.ssh"
    chmod 700 "$HOME/.ssh"

    # Create config file if it doesn't exist
    touch "$HOME/.ssh/config"
    chmod 600 "$HOME/.ssh/config"

    # Remove any existing block for this alias first
    ssh_remove_config "$name"

    # Append new config block
    {
        echo ""
        echo "Host ${alias}"
        echo "  HostName localhost"
        echo "  Port ${port}"
        echo "  User claude"
        echo "  IdentityFile ${ssh_dir}/id_claude"
        echo "  IdentitiesOnly yes"
        echo "  StrictHostKeyChecking no"
        echo "  UserKnownHostsFile /dev/null"
    } >> "$HOME/.ssh/config"
}

# ---------------------------------------------------------------------------
# ssh_remove_config -- Remove SSH config block for an instance
# Args: $1 = instance name
# ---------------------------------------------------------------------------
ssh_remove_config() {
    local name="$1"
    local alias
    alias="$(common_ssh_alias "$name")"
    local config_file="$HOME/.ssh/config"

    [[ -f "$config_file" ]] || return 0

    # Parse config line by line, skip the block matching our alias
    local in_block=false
    local tmpfile
    tmpfile="$(mktemp)"

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Detect start of our Host block
        if [[ "$line" =~ ^Host[[:space:]]+${alias}$ ]]; then
            in_block=true
            continue
        fi

        # Detect start of a different Host block (ends our skip)
        if $in_block && [[ "$line" =~ ^Host[[:space:]] ]]; then
            in_block=false
        fi

        # Skip lines inside our block
        if $in_block; then
            continue
        fi

        echo "$line" >> "$tmpfile"
    done < "$config_file"

    mv "$tmpfile" "$config_file"
    chmod 600 "$config_file"
}
