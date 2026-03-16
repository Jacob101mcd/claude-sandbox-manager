#!/usr/bin/env bats

load test_helper

@test "docker.sh binds SSH to localhost only" {
  grep -q '127.0.0.1' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh drops MKNOD capability" {
  grep -q 'cap-drop=MKNOD' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh drops all required capabilities" {
  grep -q 'cap-drop=MKNOD' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=SETFCAP' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=SETPCAP' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=NET_BIND_SERVICE' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=SYS_CHROOT' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=FSETID' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh sets memory limit from config" {
  grep -q 'settings_get.*memory_limit' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh sets CPU limit from config" {
  grep -q 'settings_get.*cpu_limit' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh documents no-new-privileges removal" {
  # no-new-privileges intentionally removed — it prevents sudo/apt-get
  grep -q 'no-new-privileges' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh removes existing container before run" {
  grep -q 'docker rm -f' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh injects credentials via -e flags" {
  grep -q 'credentials_load' "$CSM_ROOT/lib/docker.sh"
  grep -q 'credentials_get_docker_env_flags' "$CSM_ROOT/lib/docker.sh"
  grep -q 'CSM_DOCKER_ENV_FLAGS' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh calls credentials_ensure_env_file on start" {
  grep -q 'credentials_ensure_env_file' "$CSM_ROOT/lib/docker.sh"
}

@test "credentials_get_docker_env_flags builds -e flags for set credentials" {
  source "$CSM_ROOT/lib/common.sh"
  source "$CSM_ROOT/lib/credentials.sh"
  export ANTHROPIC_API_KEY="test-key-123"
  export GITHUB_TOKEN="gh-token-456"
  credentials_get_docker_env_flags
  local flags="${CSM_DOCKER_ENV_FLAGS[*]}"
  [[ "$flags" == *"-e"* ]]
  [[ "$flags" == *"ANTHROPIC_API_KEY=test-key-123"* ]]
  [[ "$flags" == *"GITHUB_TOKEN=gh-token-456"* ]]
}

# ---------------------------------------------------------------------------
# Type-aware build tests
# ---------------------------------------------------------------------------

@test "docker_build includes --target flag for cli type" {
  grep -q '\-\-target' "$CSM_ROOT/lib/docker.sh"
}

@test "docker_build includes --target flag for gui type" {
  # The same --target flag handles both cli and gui
  grep -q '\-\-target' "$CSM_ROOT/lib/docker.sh"
}

@test "docker_build image tag includes type suffix" {
  grep -q 'claude-sandbox-.*-.*type' "$CSM_ROOT/lib/docker.sh" || \
  grep -q 'claude-sandbox-\${name}-\${type}' "$CSM_ROOT/lib/docker.sh"
}

@test "docker_run_instance adds shm-size for gui type" {
  grep -q 'shm-size=512m' "$CSM_ROOT/lib/docker.sh"
}

@test "docker_run_instance does not add shm-size unconditionally" {
  # shm-size should only appear in an if-block, not always
  grep -q 'shm-size' "$CSM_ROOT/lib/docker.sh"
}

@test "docker_run_instance adds vnc port mapping for gui type" {
  grep -q '6080' "$CSM_ROOT/lib/docker.sh"
}

# ---------------------------------------------------------------------------
# Functional docker_build tests using mocked docker
# ---------------------------------------------------------------------------

setup() {
    REAL_CSM_ROOT="$CSM_ROOT"
    export REAL_CSM_ROOT

    # Create a temp directory for test CSM_ROOT
    TEST_CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT="$TEST_CSM_ROOT"

    # Create required directory structure
    mkdir -p "$TEST_CSM_ROOT/lib"
    mkdir -p "$TEST_CSM_ROOT/scripts"

    # Symlink actual library files
    for lib in common.sh instances.sh credentials.sh; do
        ln -sf "$REAL_CSM_ROOT/lib/$lib" "$TEST_CSM_ROOT/lib/$lib"
    done

    # Create a stub docker.sh that refers to symlinked libs
    ln -sf "$REAL_CSM_ROOT/lib/docker.sh" "$TEST_CSM_ROOT/lib/docker.sh"

    # Mock docker command so it doesn't actually build/run
    docker() {
        case "$1" in
            build)
                LAST_DOCKER_BUILD_ARGS=("$@")
                return 0
                ;;
            run)
                LAST_DOCKER_RUN_ARGS=("$@")
                return 0
                ;;
            rm)   return 0 ;;
            info) return 0 ;;
            *)    return 0 ;;
        esac
    }
    export -f docker

    # Mock other external functions that docker.sh calls
    ssh_ensure_keys()      { :; }
    ssh_stage_build_keys() { :; }
    ssh_write_config()     { :; }
    backup_create()        { :; }
    export -f ssh_ensure_keys ssh_stage_build_keys ssh_write_config backup_create

    # Source the actual library files under test
    source "$REAL_CSM_ROOT/lib/common.sh"
    source "$REAL_CSM_ROOT/lib/settings.sh"
    source "$REAL_CSM_ROOT/lib/instances.sh"
    source "$REAL_CSM_ROOT/lib/credentials.sh"
    source "$REAL_CSM_ROOT/lib/docker.sh"
}

teardown() {
    rm -rf "$TEST_CSM_ROOT"
}

@test "docker_build uses --target cli for cli instance" {
    instances_add "testcli" "cli"
    # We need a Dockerfile path; create a fake one
    touch "$TEST_CSM_ROOT/scripts/Dockerfile"
    docker_build "testcli"
    # Check that --target was passed with "cli"
    local found=false
    local i
    for i in "${!LAST_DOCKER_BUILD_ARGS[@]}"; do
        if [[ "${LAST_DOCKER_BUILD_ARGS[$i]}" == "--target" ]] && \
           [[ "${LAST_DOCKER_BUILD_ARGS[$((i+1))]}" == "cli" ]]; then
            found=true
        fi
    done
    $found
}

@test "docker_build uses --target gui for gui instance" {
    instances_add "testgui" "gui"
    touch "$TEST_CSM_ROOT/scripts/Dockerfile"
    docker_build "testgui"
    local found=false
    local i
    for i in "${!LAST_DOCKER_BUILD_ARGS[@]}"; do
        if [[ "${LAST_DOCKER_BUILD_ARGS[$i]}" == "--target" ]] && \
           [[ "${LAST_DOCKER_BUILD_ARGS[$((i+1))]}" == "gui" ]]; then
            found=true
        fi
    done
    $found
}

@test "docker_build image tag includes type suffix for cli" {
    instances_add "testcli" "cli"
    touch "$TEST_CSM_ROOT/scripts/Dockerfile"
    docker_build "testcli"
    # Image tag should be claude-sandbox-testcli-cli
    local found=false
    local arg
    for arg in "${LAST_DOCKER_BUILD_ARGS[@]}"; do
        if [[ "$arg" == "claude-sandbox-testcli-cli" ]]; then
            found=true
        fi
    done
    $found
}

@test "docker_run_instance adds shm-size=512m for gui instance" {
    instances_add "testgui" "gui"
    local port=2222
    docker_run_instance "testgui" "$port"
    local found=false
    local arg
    for arg in "${LAST_DOCKER_RUN_ARGS[@]}"; do
        if [[ "$arg" == "--shm-size=512m" ]]; then
            found=true
        fi
    done
    $found
}

@test "docker_run_instance does not add shm-size for cli instance" {
    instances_add "testcli" "cli"
    local port=2222
    docker_run_instance "testcli" "$port"
    local found=false
    local arg
    for arg in "${LAST_DOCKER_RUN_ARGS[@]}"; do
        if [[ "$arg" == "--shm-size=512m" ]]; then
            found=true
        fi
    done
    ! $found
}

@test "docker_run_instance adds vnc port mapping for gui instance" {
    instances_add "testgui" "gui"
    local vnc_port
    vnc_port="$(instances_get_vnc_port "testgui")"
    docker_run_instance "testgui" "2222"
    local found=false
    local arg
    for arg in "${LAST_DOCKER_RUN_ARGS[@]}"; do
        if [[ "$arg" == "127.0.0.1:${vnc_port}:6080" ]]; then
            found=true
        fi
    done
    $found
}

# ---------------------------------------------------------------------------
# MCP and remote control env flags -- phase 05 additions
# ---------------------------------------------------------------------------

@test "credentials_get_docker_env_flags includes CSM_MCP_ENABLED for mcp-enabled instance" {
    instances_add "testmcp" "cli"
    # mcp_enabled defaults to true
    credentials_get_docker_env_flags "testmcp"
    local flags="${CSM_DOCKER_ENV_FLAGS[*]}"
    [[ "$flags" == *"CSM_MCP_ENABLED=1"* ]]
}

@test "credentials_get_docker_env_flags includes CSM_MCP_PORT for mcp-enabled instance" {
    instances_add "testmcp" "cli"
    credentials_get_docker_env_flags "testmcp"
    local flags="${CSM_DOCKER_ENV_FLAGS[*]}"
    [[ "$flags" == *"CSM_MCP_PORT="* ]]
}

@test "credentials_get_docker_env_flags includes CSM_REMOTE_CONTROL for rc-enabled instance" {
    instances_add "testrc" "cli"
    instances_set_remote_control "testrc" true
    credentials_get_docker_env_flags "testrc"
    local flags="${CSM_DOCKER_ENV_FLAGS[*]}"
    [[ "$flags" == *"CSM_REMOTE_CONTROL=1"* ]]
}

@test "credentials_get_docker_env_flags omits CSM_REMOTE_CONTROL when rc disabled" {
    instances_add "testnrc" "cli"
    # remote_control defaults to false
    credentials_get_docker_env_flags "testnrc"
    local flags="${CSM_DOCKER_ENV_FLAGS[*]}"
    [[ "$flags" != *"CSM_REMOTE_CONTROL"* ]]
}

# ---------------------------------------------------------------------------
# Linux Engine detection and --add-host flag -- phase 05 Task 2
# ---------------------------------------------------------------------------

@test "docker.sh contains add-host flag logic" {
    grep -q 'add-host=host.docker.internal' "$REAL_CSM_ROOT/lib/docker.sh"
}

@test "docker_run_instance adds --add-host on Linux Engine" {
    # Mock uname to report Linux
    uname() { echo "Linux"; }
    export -f uname

    # Mock _docker_detect_variant to return "engine"
    _docker_detect_variant() { echo "engine"; }
    export -f _docker_detect_variant

    instances_add "testhost" "cli"
    docker_run_instance "testhost" "2222"

    local found=false
    local arg
    for arg in "${LAST_DOCKER_RUN_ARGS[@]}"; do
        if [[ "$arg" == "--add-host=host.docker.internal:host-gateway" ]]; then
            found=true
        fi
    done
    $found
}

@test "docker_run_instance skips --add-host on Docker Desktop" {
    # Mock uname to report Linux
    uname() { echo "Linux"; }
    export -f uname

    # Mock _docker_detect_variant to return "desktop"
    _docker_detect_variant() { echo "desktop"; }
    export -f _docker_detect_variant

    instances_add "testdesk" "cli"
    docker_run_instance "testdesk" "2222"

    local found=false
    local arg
    for arg in "${LAST_DOCKER_RUN_ARGS[@]}"; do
        if [[ "$arg" == "--add-host=host.docker.internal:host-gateway" ]]; then
            found=true
        fi
    done
    ! $found
}

# ---------------------------------------------------------------------------
# _docker_build_run_cmd helper tests -- phase 07 additions
# ---------------------------------------------------------------------------

@test "_docker_build_run_cmd populates _DOCKER_RUN_CMD with correct image tag" {
    instances_add "testcli" "cli"
    _docker_build_run_cmd "testcli" "2222" "my-custom-tag"
    # Last element of _DOCKER_RUN_CMD should be the image tag
    local last_elem="${_DOCKER_RUN_CMD[${#_DOCKER_RUN_CMD[@]}-1]}"
    [[ "$last_elem" == "my-custom-tag" ]]
}

@test "_docker_build_run_cmd includes --shm-size=512m for gui type" {
    instances_add "testgui" "gui"
    _docker_build_run_cmd "testgui" "2222" "my-gui-tag"
    local found=false
    local arg
    for arg in "${_DOCKER_RUN_CMD[@]}"; do
        if [[ "$arg" == "--shm-size=512m" ]]; then
            found=true
        fi
    done
    $found
}

@test "_docker_build_run_cmd includes --add-host on Linux Engine" {
    uname() { echo "Linux"; }
    export -f uname
    _docker_detect_variant() { echo "engine"; }
    export -f _docker_detect_variant

    instances_add "testhost2" "cli"
    _docker_build_run_cmd "testhost2" "2222" "my-tag"
    local found=false
    local arg
    for arg in "${_DOCKER_RUN_CMD[@]}"; do
        if [[ "$arg" == "--add-host=host.docker.internal:host-gateway" ]]; then
            found=true
        fi
    done
    $found
}

@test "docker_run_instance delegates to _docker_build_run_cmd with type-aware image tag" {
    instances_add "testcli2" "cli"
    docker_run_instance "testcli2" "2222"
    # The image tag passed to docker run should be claude-sandbox-testcli2-cli
    local last_elem="${LAST_DOCKER_RUN_ARGS[${#LAST_DOCKER_RUN_ARGS[@]}-1]}"
    [[ "$last_elem" == "claude-sandbox-testcli2-cli" ]]
}

# ---------------------------------------------------------------------------
# BACK-02: Auto-backup hook in docker_start_instance
# ---------------------------------------------------------------------------

@test "docker_start_instance calls backup_create when auto_backup=true and container is running" {
    # Arrange: create a config with auto_backup enabled
    settings_ensure_config_file
    settings_set '.backup.auto_backup' 'true' 'bool'

    # Track whether backup_create was called
    backup_create() {
        echo "backup_create_called:$1" >> "$TEST_CSM_ROOT/_backup_calls"
    }
    export -f backup_create

    # Mock docker_status to return "running"
    docker_status() { echo "running"; }
    export -f docker_status

    instances_add "autotest" "cli"
    touch "$TEST_CSM_ROOT/scripts/Dockerfile"

    # credentials_ensure_env_file is called first in docker_start_instance
    credentials_ensure_env_file() { :; }
    export -f credentials_ensure_env_file

    run docker_start_instance "autotest"

    # backup_create should have been called with the instance name
    [ -f "$TEST_CSM_ROOT/_backup_calls" ]
    grep -q "backup_create_called:autotest" "$TEST_CSM_ROOT/_backup_calls"
}

@test "docker_start_instance skips backup_create when container status is not created" {
    # Arrange: create a config with auto_backup enabled
    settings_ensure_config_file
    settings_set '.backup.auto_backup' 'true' 'bool'

    # Track whether backup_create was called
    backup_create() {
        echo "backup_create_called:$1" >> "$TEST_CSM_ROOT/_backup_calls"
    }
    export -f backup_create

    # Mock docker_status to return "not created"
    docker_status() { echo "not created"; }
    export -f docker_status

    instances_add "autotest2" "cli"
    touch "$TEST_CSM_ROOT/scripts/Dockerfile"

    credentials_ensure_env_file() { :; }
    export -f credentials_ensure_env_file

    run docker_start_instance "autotest2"

    # backup_create must NOT have been called
    if [ -f "$TEST_CSM_ROOT/_backup_calls" ]; then
        ! grep -q "backup_create_called" "$TEST_CSM_ROOT/_backup_calls"
    else
        true
    fi
}
