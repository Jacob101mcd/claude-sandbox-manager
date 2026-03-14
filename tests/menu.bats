#!/usr/bin/env bats
# tests/menu.bats -- Tests for lib/menu.sh (container type selection)

load test_helper

setup() {
    REAL_CSM_ROOT="$CSM_ROOT"
    CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT
    source "$REAL_CSM_ROOT/lib/common.sh"
    source "$REAL_CSM_ROOT/lib/settings.sh"
    source "$REAL_CSM_ROOT/lib/instances.sh"
    source "$REAL_CSM_ROOT/lib/menu.sh"
}

teardown() {
    rm -rf "$CSM_ROOT"
}

# ---------------------------------------------------------------------------
# menu_select_container_type
# ---------------------------------------------------------------------------

@test "menu_select_container_type returns cli when input is 1" {
    result="$(echo "1" | menu_select_container_type)"
    # Last line of output should be "cli"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}

@test "menu_select_container_type returns cli when input is empty (default)" {
    result="$(echo "" | menu_select_container_type)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}

@test "menu_select_container_type returns gui for option 2" {
    result="$(echo "2" | menu_select_container_type)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "gui" ]]
}

@test "menu_select_container_type returns cli when input is invalid" {
    result="$(echo "9" | menu_select_container_type)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}

@test "menu_select_container_type does not show coming soon" {
    result="$(echo "2" | menu_select_container_type)"
    [[ "$result" != *"coming soon"* ]]
}

# ---------------------------------------------------------------------------
# Remote control prompt -- phase 05 Task 2
# ---------------------------------------------------------------------------

@test "menu.sh contains remote control prompt" {
    grep -q 'remote control' "$REAL_CSM_ROOT/lib/menu.sh"
}

@test "menu.sh contains instances_set_remote_control call" {
    grep -q 'instances_set_remote_control' "$REAL_CSM_ROOT/lib/menu.sh"
}

# ---------------------------------------------------------------------------
# menu_select_container_type -- auto-skip when default is set
# ---------------------------------------------------------------------------

@test "menu_select_container_type auto-skips when default is cli" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'cli' 'string'
    result="$(menu_select_container_type 2>/dev/null)"
    [[ "$result" == "cli" ]]
}

@test "menu_select_container_type auto-skips when default is gui" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'gui' 'string'
    result="$(menu_select_container_type 2>/dev/null)"
    [[ "$result" == "gui" ]]
}

@test "menu_select_container_type shows auto-skip message on stderr" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'gui' 'string'
    stderr_output="$(menu_select_container_type 2>&1 >/dev/null)"
    [[ "$stderr_output" == *"Using default: GUI Desktop"* ]]
}

@test "menu_select_container_type shows prompt when container_type is null" {
    settings_ensure_config_file
    # container_type is null by default — interactive path runs
    result="$(echo "1" | menu_select_container_type)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}
