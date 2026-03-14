#!/usr/bin/env bats
# tests/ssh.bats -- Tests for lib/ssh.sh (SSH key lifecycle management)
# Covers QUAL-03: SSH keys generated as ed25519 with correct permissions,
# ssh_write_config creates correct Host blocks, ssh_remove_config removes them.

load test_helper

setup() {
    REAL_CSM_ROOT="$CSM_ROOT"
    CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT

    # Create a temporary HOME to avoid touching the real ~/.ssh/config
    REAL_HOME="$HOME"
    export HOME="$(mktemp -d)"

    source "$REAL_CSM_ROOT/lib/common.sh"
    source "$REAL_CSM_ROOT/lib/ssh.sh"
}

teardown() {
    rm -rf "$CSM_ROOT"
    rm -rf "$HOME"
    export HOME="$REAL_HOME"
}

# ---------------------------------------------------------------------------
# ssh_ensure_keys -- key generation
# ---------------------------------------------------------------------------

@test "ssh_ensure_keys creates the ssh directory for the instance" {
    ssh_ensure_keys "testbox"
    [[ -d "${CSM_ROOT}/ssh/testbox" ]]
}

@test "ssh_ensure_keys generates an ed25519 client keypair" {
    ssh_ensure_keys "testbox"
    [[ -f "${CSM_ROOT}/ssh/testbox/id_claude" ]]
    [[ -f "${CSM_ROOT}/ssh/testbox/id_claude.pub" ]]
}

@test "ssh_ensure_keys generates an ed25519 host key" {
    ssh_ensure_keys "testbox"
    [[ -f "${CSM_ROOT}/ssh/testbox/ssh_host_ed25519_key" ]]
    [[ -f "${CSM_ROOT}/ssh/testbox/ssh_host_ed25519_key.pub" ]]
}

@test "ssh_ensure_keys sets private key permissions to 600" {
    ssh_ensure_keys "testbox"
    perms="$(stat -c '%a' "${CSM_ROOT}/ssh/testbox/id_claude")"
    [[ "$perms" == "600" ]]
}

@test "ssh_ensure_keys does not regenerate keys that already exist" {
    ssh_ensure_keys "testbox"
    local mtime_before
    mtime_before="$(stat -c '%Y' "${CSM_ROOT}/ssh/testbox/id_claude")"
    sleep 1
    ssh_ensure_keys "testbox"
    local mtime_after
    mtime_after="$(stat -c '%Y' "${CSM_ROOT}/ssh/testbox/id_claude")"
    [[ "$mtime_before" == "$mtime_after" ]]
}

# ---------------------------------------------------------------------------
# ssh_stage_build_keys -- staging directory
# ---------------------------------------------------------------------------

@test "ssh_stage_build_keys creates _build_ssh directory with copies of keys" {
    ssh_ensure_keys "testbox"
    ssh_stage_build_keys "testbox"
    [[ -d "${CSM_ROOT}/_build_ssh" ]]
    [[ -f "${CSM_ROOT}/_build_ssh/id_claude" ]]
}

@test "ssh_stage_build_keys recreates a clean staging directory on each call" {
    ssh_ensure_keys "testbox"
    ssh_stage_build_keys "testbox"
    # Plant a stale file in staging
    touch "${CSM_ROOT}/_build_ssh/stale_file"
    ssh_stage_build_keys "testbox"
    # Stale file should be gone after re-stage
    [[ ! -f "${CSM_ROOT}/_build_ssh/stale_file" ]]
}

# ---------------------------------------------------------------------------
# ssh_write_config -- SSH config block management
# ---------------------------------------------------------------------------

@test "ssh_write_config creates the ~/.ssh/config file if missing" {
    ssh_ensure_keys "testbox"
    ssh_write_config "testbox" "2222"
    [[ -f "$HOME/.ssh/config" ]]
}

@test "ssh_write_config writes correct Host alias for named instance" {
    ssh_ensure_keys "testbox"
    ssh_write_config "testbox" "2222"
    grep -q "^Host claude-testbox$" "$HOME/.ssh/config"
}

@test "ssh_write_config writes correct Host alias for default instance" {
    ssh_ensure_keys "default"
    ssh_write_config "default" "2222"
    grep -q "^Host claude-sandbox$" "$HOME/.ssh/config"
}

@test "ssh_write_config writes correct port number" {
    ssh_ensure_keys "testbox"
    ssh_write_config "testbox" "2345"
    grep -q "Port 2345" "$HOME/.ssh/config"
}

@test "ssh_write_config writes IdentityFile pointing to instance ssh dir" {
    ssh_ensure_keys "testbox"
    ssh_write_config "testbox" "2222"
    grep -q "IdentityFile.*ssh/testbox/id_claude" "$HOME/.ssh/config"
}

@test "ssh_write_config sets StrictHostKeyChecking no" {
    ssh_ensure_keys "testbox"
    ssh_write_config "testbox" "2222"
    grep -q "StrictHostKeyChecking no" "$HOME/.ssh/config"
}

# ---------------------------------------------------------------------------
# ssh_remove_config -- SSH config block removal
# ---------------------------------------------------------------------------

@test "ssh_remove_config removes the Host block for the named instance" {
    ssh_ensure_keys "testbox"
    ssh_write_config "testbox" "2222"
    ssh_remove_config "testbox"
    ! grep -q "^Host claude-testbox$" "$HOME/.ssh/config"
}

@test "ssh_remove_config does not remove other Host blocks" {
    ssh_ensure_keys "testbox"
    ssh_ensure_keys "other"
    ssh_write_config "testbox" "2222"
    ssh_write_config "other" "2223"
    ssh_remove_config "testbox"
    grep -q "^Host claude-other$" "$HOME/.ssh/config"
}

@test "ssh_remove_config is safe to call when no config file exists" {
    # Should not fail even if ~/.ssh/config is absent
    run ssh_remove_config "nonexistent"
    [[ "$status" -eq 0 ]]
}
