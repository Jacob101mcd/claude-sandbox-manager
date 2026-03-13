#!/usr/bin/env bats
# tests/platform.bats -- Tests for lib/common.sh and lib/platform.sh

load test_helper

setup() {
    source "$CSM_ROOT/lib/common.sh"
    source "$CSM_ROOT/lib/platform.sh"
}

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

@test "platform_detect sets CSM_PLATFORM to linux" {
    platform_detect
    [[ "$CSM_PLATFORM" == "linux" ]]
}

# ---------------------------------------------------------------------------
# common_container_name
# ---------------------------------------------------------------------------

@test "common_container_name formats correctly" {
    result="$(common_container_name "test")"
    [[ "$result" == "claude-sandbox-test" ]]
}

@test "common_container_name handles default" {
    result="$(common_container_name "default")"
    [[ "$result" == "claude-sandbox-default" ]]
}

# ---------------------------------------------------------------------------
# common_ssh_alias
# ---------------------------------------------------------------------------

@test "common_ssh_alias returns claude-sandbox for default" {
    result="$(common_ssh_alias "default")"
    [[ "$result" == "claude-sandbox" ]]
}

@test "common_ssh_alias returns claude-NAME for named instance" {
    result="$(common_ssh_alias "mybox")"
    [[ "$result" == "claude-mybox" ]]
}

# ---------------------------------------------------------------------------
# Path helpers
# ---------------------------------------------------------------------------

@test "common_ssh_dir returns correct path" {
    result="$(common_ssh_dir "test")"
    [[ "$result" == "${CSM_ROOT}/ssh/test" ]]
}

@test "common_workspace_dir returns correct path" {
    result="$(common_workspace_dir "test")"
    [[ "$result" == "${CSM_ROOT}/workspaces/test" ]]
}

@test "common_backup_dir returns correct path" {
    result="$(common_backup_dir "test")"
    [[ "$result" == "${CSM_ROOT}/backups/test" ]]
}
