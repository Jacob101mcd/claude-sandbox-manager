#!/usr/bin/env bats
# tests/menu.bats -- Tests for lib/menu.sh (container type selection)

load test_helper

setup() {
    REAL_CSM_ROOT="$CSM_ROOT"
    CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT
    source "$REAL_CSM_ROOT/lib/common.sh"
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

@test "menu_select_container_type returns cli when input is 2 (GUI not available)" {
    result="$(echo "2" | menu_select_container_type)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}

@test "menu_select_container_type returns cli when input is invalid" {
    result="$(echo "9" | menu_select_container_type)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}
