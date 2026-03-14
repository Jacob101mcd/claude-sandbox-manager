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

# ---------------------------------------------------------------------------
# PLAT-02: Interactive menu dispatch functions exist in lib/menu.sh
# ---------------------------------------------------------------------------

@test "menu_main function is defined after sourcing menu.sh" {
    declare -f menu_main > /dev/null
}

@test "menu_show_header function is defined after sourcing menu.sh" {
    declare -f menu_show_header > /dev/null
}

@test "menu_show_actions function is defined after sourcing menu.sh" {
    declare -f menu_show_actions > /dev/null
}

@test "menu_show_actions output contains S T N R Q dispatch keys" {
    output="$(menu_show_actions)"
    [[ "$output" == *"[S]"* ]]
    [[ "$output" == *"[T]"* ]]
    [[ "$output" == *"[N]"* ]]
    [[ "$output" == *"[R]"* ]]
    [[ "$output" == *"[Q]"* ]]
}

@test "menu_show_header output contains Claude Sandbox Manager banner" {
    output="$(menu_show_header)"
    [[ "$output" == *"Claude Sandbox Manager"* ]]
}

@test "menu_main dispatches Q to exit" {
    grep -q 'q) exit 0' "$REAL_CSM_ROOT/lib/menu.sh"
}

@test "menu_main dispatches s to start action" {
    grep -q 's) menu_action_start' "$REAL_CSM_ROOT/lib/menu.sh"
}

@test "menu_main dispatches t to stop action" {
    grep -q 't) menu_action_stop' "$REAL_CSM_ROOT/lib/menu.sh"
}

@test "menu_main dispatches n to new action" {
    grep -q 'n) menu_action_new' "$REAL_CSM_ROOT/lib/menu.sh"
}

@test "menu_main dispatches r to remove action" {
    grep -q 'r) menu_action_remove' "$REAL_CSM_ROOT/lib/menu.sh"
}

# ---------------------------------------------------------------------------
# BACK-01/BACK-04: Backup and restore menu dispatch keys
# ---------------------------------------------------------------------------

@test "menu_show_actions output contains B and E dispatch keys" {
    output="$(menu_show_actions)"
    [[ "$output" == *"[B]"* ]]
    [[ "$output" == *"[E]"* ]]
}

@test "menu_main dispatches b to backup action" {
    grep -q 'b) menu_action_backup' "$REAL_CSM_ROOT/lib/menu.sh"
}

@test "menu_main dispatches e to restore action" {
    grep -q 'e) menu_action_restore' "$REAL_CSM_ROOT/lib/menu.sh"
}
