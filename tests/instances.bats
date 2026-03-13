#!/usr/bin/env bats
# tests/instances.bats -- Tests for lib/instances.sh (instance registry CRUD + orphan detection)

load test_helper

# Use a temp directory for CSM_ROOT to avoid polluting real state
setup() {
    REAL_CSM_ROOT="$CSM_ROOT"
    CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT
    source "$REAL_CSM_ROOT/lib/common.sh"
    source "$REAL_CSM_ROOT/lib/instances.sh"
}

teardown() {
    rm -rf "$CSM_ROOT"
}

# ---------------------------------------------------------------------------
# instances_get_all
# ---------------------------------------------------------------------------

@test "instances_get_all returns empty object when no registry exists" {
    result="$(instances_get_all)"
    [[ "$result" == "{}" ]]
}

# ---------------------------------------------------------------------------
# instances_add
# ---------------------------------------------------------------------------

@test "instances_add creates entry in registry" {
    instances_add "test"
    result="$(jq -r '.test.port' "$CSM_ROOT/.instances.json")"
    [[ "$result" =~ ^[0-9]+$ ]]
}

@test "instances_add returns allocated port" {
    port="$(instances_add "test")"
    [[ "$port" =~ ^[0-9]+$ ]]
}

# ---------------------------------------------------------------------------
# instances_get_port
# ---------------------------------------------------------------------------

@test "instances_get_port returns correct port after add" {
    port="$(instances_add "test")"
    result="$(instances_get_port "test")"
    [[ "$result" == "$port" ]]
}

@test "instances_get_port returns empty for nonexistent instance" {
    result="$(instances_get_port "nonexistent")"
    [[ -z "$result" || "$result" == "null" ]]
}

# ---------------------------------------------------------------------------
# instances_remove
# ---------------------------------------------------------------------------

@test "instances_remove deletes entry from registry" {
    instances_add "test"
    instances_remove "test"
    result="$(instances_get_all)"
    [[ "$result" == "{}" ]]
}

# ---------------------------------------------------------------------------
# instances_next_free_port
# ---------------------------------------------------------------------------

@test "instances_next_free_port starts at 2222 with empty registry" {
    port="$(instances_next_free_port)"
    [[ "$port" == "2222" ]]
}

@test "instances_next_free_port skips ports already in registry" {
    instances_add "first"
    port="$(instances_next_free_port)"
    # Should be 2223 since 2222 is taken
    [[ "$port" == "2223" ]]
}

# ---------------------------------------------------------------------------
# instances_add -- type field
# ---------------------------------------------------------------------------

@test "instances_add stores type field in JSON" {
    instances_add "test" "cli"
    result="$(jq -r '.test.type' "$CSM_ROOT/.instances.json")"
    [[ "$result" == "cli" ]]
}

@test "instances_add defaults to cli when no type parameter given" {
    instances_add "test"
    result="$(jq -r '.test.type' "$CSM_ROOT/.instances.json")"
    [[ "$result" == "cli" ]]
}

# ---------------------------------------------------------------------------
# instances_get_type
# ---------------------------------------------------------------------------

@test "instances_get_type returns stored type" {
    instances_add "test" "cli"
    result="$(instances_get_type "test")"
    [[ "$result" == "cli" ]]
}

@test "instances_get_type returns cli for entries without type field (backward compat)" {
    _instances_ensure_file
    # Write a legacy entry without type field
    echo '{"legacy": {"port": 2222}}' > "$CSM_ROOT/.instances.json"
    result="$(instances_get_type "legacy")"
    [[ "$result" == "cli" ]]
}

# ---------------------------------------------------------------------------
# instances_detect_orphans (requires docker -- skip if unavailable)
# ---------------------------------------------------------------------------

@test "instances_detect_orphans returns empty when no containers exist" {
    if ! command -v docker &>/dev/null || ! docker info &>/dev/null; then
        skip "Docker not available"
    fi
    result="$(instances_detect_orphans)"
    # No orphans expected in test env (no claude-sandbox containers running)
    [[ -z "$result" ]]
}

# ---------------------------------------------------------------------------
# instances_add gui type -- vnc_port allocation
# ---------------------------------------------------------------------------

@test "instances_add gui type stores vnc_port in registry" {
    instances_add "mygui" "gui"
    result="$(jq -r '.mygui.vnc_port' "$CSM_ROOT/.instances.json")"
    [[ "$result" =~ ^[0-9]+$ ]]
}

@test "instances_add cli type does not store vnc_port" {
    instances_add "mycli" "cli"
    result="$(jq -r '.mycli.vnc_port // empty' "$CSM_ROOT/.instances.json")"
    [[ -z "$result" ]]
}

# ---------------------------------------------------------------------------
# instances_get_vnc_port
# ---------------------------------------------------------------------------

@test "instances_get_vnc_port returns port for gui instance" {
    instances_add "mygui" "gui"
    result="$(instances_get_vnc_port "mygui")"
    [[ "$result" =~ ^[0-9]+$ ]]
}

@test "instances_get_vnc_port returns empty for cli instance" {
    instances_add "mycli" "cli"
    result="$(instances_get_vnc_port "mycli")"
    [[ -z "$result" ]]
}

# ---------------------------------------------------------------------------
# instances_next_free_vnc_port
# ---------------------------------------------------------------------------

@test "instances_next_free_vnc_port returns 6080 when no gui instances" {
    port="$(instances_next_free_vnc_port)"
    [[ "$port" == "6080" ]]
}

@test "instances_next_free_vnc_port skips allocated ports" {
    instances_add "first" "gui"
    port="$(instances_next_free_vnc_port)"
    # Should be 6081 since 6080 is taken
    [[ "$port" == "6081" ]]
}
