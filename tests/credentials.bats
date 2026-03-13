#!/usr/bin/env bats
# tests/credentials.bats -- Unit tests for lib/credentials.sh

load test_helper

# Source required modules
setup() {
    # Use a temp directory as CSM_ROOT for test isolation
    TEST_CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT="$TEST_CSM_ROOT"

    # Source common.sh for msg_warn etc.
    source "$BATS_TEST_DIRNAME/../lib/common.sh"
    source "$BATS_TEST_DIRNAME/../lib/credentials.sh"
}

teardown() {
    rm -rf "$TEST_CSM_ROOT"
}

# ---------------------------------------------------------------------------
# Test 1: credentials_load reads ANTHROPIC_API_KEY from .env file
# ---------------------------------------------------------------------------
@test "credentials_load reads ANTHROPIC_API_KEY from .env file and exports it" {
    echo 'ANTHROPIC_API_KEY=sk-ant-test123' > "$TEST_CSM_ROOT/.env"
    unset ANTHROPIC_API_KEY

    credentials_load

    [ "$ANTHROPIC_API_KEY" = "sk-ant-test123" ]
}

# ---------------------------------------------------------------------------
# Test 2: credentials_load reads GITHUB_TOKEN from .env file
# ---------------------------------------------------------------------------
@test "credentials_load reads GITHUB_TOKEN from .env file and exports it" {
    echo 'GITHUB_TOKEN=ghp_abc456' > "$TEST_CSM_ROOT/.env"
    unset GITHUB_TOKEN

    credentials_load

    [ "$GITHUB_TOKEN" = "ghp_abc456" ]
}

# ---------------------------------------------------------------------------
# Test 3: credentials_load skips comments and blank lines
# ---------------------------------------------------------------------------
@test "credentials_load skips comment lines and blank lines" {
    cat > "$TEST_CSM_ROOT/.env" <<'EOF'
# This is a comment
ANTHROPIC_API_KEY=sk-ant-valid

# Another comment
GITHUB_TOKEN=ghp_valid
EOF
    unset ANTHROPIC_API_KEY
    unset GITHUB_TOKEN

    credentials_load

    [ "$ANTHROPIC_API_KEY" = "sk-ant-valid" ]
    [ "$GITHUB_TOKEN" = "ghp_valid" ]
}

# ---------------------------------------------------------------------------
# Test 4: credentials_load handles quoted values
# ---------------------------------------------------------------------------
@test "credentials_load strips single and double quotes from values" {
    cat > "$TEST_CSM_ROOT/.env" <<'EOF'
ANTHROPIC_API_KEY="sk-ant-quoted"
GITHUB_TOKEN='ghp_single_quoted'
EOF
    unset ANTHROPIC_API_KEY
    unset GITHUB_TOKEN

    credentials_load

    [ "$ANTHROPIC_API_KEY" = "sk-ant-quoted" ]
    [ "$GITHUB_TOKEN" = "ghp_single_quoted" ]
}

# ---------------------------------------------------------------------------
# Test 5: credentials_ensure_env_file creates template if none exists
# ---------------------------------------------------------------------------
@test "credentials_ensure_env_file creates template .env if none exists" {
    [ ! -f "$TEST_CSM_ROOT/.env" ]

    run credentials_ensure_env_file

    [ -f "$TEST_CSM_ROOT/.env" ]
    grep -q "ANTHROPIC_API_KEY=" "$TEST_CSM_ROOT/.env"
    grep -q "GITHUB_TOKEN=" "$TEST_CSM_ROOT/.env"
}

# ---------------------------------------------------------------------------
# Test 6: credentials_ensure_env_file does NOT overwrite existing .env
# ---------------------------------------------------------------------------
@test "credentials_ensure_env_file does NOT overwrite existing .env" {
    echo 'ANTHROPIC_API_KEY=keep-me' > "$TEST_CSM_ROOT/.env"

    credentials_ensure_env_file

    grep -q "keep-me" "$TEST_CSM_ROOT/.env"
}

# ---------------------------------------------------------------------------
# Test 7: credentials_load with missing .env returns 1
# ---------------------------------------------------------------------------
@test "credentials_load with missing .env returns 1" {
    rm -f "$TEST_CSM_ROOT/.env"

    run credentials_load

    [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Test 8: credentials_get_docker_env_flags returns -e flags for set credentials
# ---------------------------------------------------------------------------
@test "credentials_get_docker_env_flags returns -e flags for set credentials" {
    export ANTHROPIC_API_KEY="sk-ant-test"
    export GITHUB_TOKEN="ghp_test"
    CSM_DOCKER_ENV_FLAGS=()

    credentials_get_docker_env_flags

    # Should have 4 elements: -e KEY=val -e KEY=val
    [ "${#CSM_DOCKER_ENV_FLAGS[@]}" -eq 4 ]
    [ "${CSM_DOCKER_ENV_FLAGS[0]}" = "-e" ]
    [ "${CSM_DOCKER_ENV_FLAGS[1]}" = "ANTHROPIC_API_KEY=sk-ant-test" ]
    [ "${CSM_DOCKER_ENV_FLAGS[2]}" = "-e" ]
    [ "${CSM_DOCKER_ENV_FLAGS[3]}" = "GITHUB_TOKEN=ghp_test" ]
}

# ---------------------------------------------------------------------------
# Test 9: credentials_get_docker_env_flags returns empty when no creds set
# ---------------------------------------------------------------------------
@test "credentials_get_docker_env_flags returns empty array when no credentials set" {
    unset ANTHROPIC_API_KEY
    unset GITHUB_TOKEN
    CSM_DOCKER_ENV_FLAGS=()

    credentials_get_docker_env_flags

    [ "${#CSM_DOCKER_ENV_FLAGS[@]}" -eq 0 ]
}
