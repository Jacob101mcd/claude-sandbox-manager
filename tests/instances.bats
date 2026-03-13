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
