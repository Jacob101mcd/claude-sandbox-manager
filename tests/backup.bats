#!/usr/bin/env bats
# tests/backup.bats -- Unit tests for lib/backup.sh

load test_helper

# ---------------------------------------------------------------------------
# Setup / teardown
# ---------------------------------------------------------------------------

setup() {
    # Use a temp directory as CSM_ROOT for test isolation
    TEST_CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT="$TEST_CSM_ROOT"

    # Create required directories
    mkdir -p "$TEST_CSM_ROOT/workspaces/myinstance"
    mkdir -p "$TEST_CSM_ROOT/backups"
    touch "$TEST_CSM_ROOT/workspaces/myinstance/test_file.txt"

    # Mock docker command: record calls, simulate behavior
    docker() {
        echo "docker $*" >> "$TEST_CSM_ROOT/_docker_calls"
        case "$1" in
            commit)
                # docker commit <container> <tag> -- returns fake image id
                echo "sha256:fakeimageid123"
                ;;
            save)
                # docker save <tag> -- emit fake tar data to stdout
                echo "FAKE_IMAGE_DATA"
                ;;
            stop)
                # docker stop <container>
                return 0
                ;;
            rm)
                # docker rm <container>
                return 0
                ;;
            load)
                # docker load reads from stdin
                cat > /dev/null
                echo "Loaded image: fake-image:latest"
                ;;
            *)
                return 0
                ;;
        esac
    }
    export -f docker

    # Mock docker_status: default to "running"
    docker_status() {
        echo "running"
    }
    export -f docker_status

    # Mock docker_run_instance
    docker_run_instance() {
        echo "mock_docker_run_instance $*" >> "$TEST_CSM_ROOT/_docker_calls"
        return 0
    }
    export -f docker_run_instance

    # Mock gzip (it is used implicitly via piping; override gzip if needed)
    # We pipe docker save | gzip -- since docker save is mocked above, gzip
    # will receive "FAKE_IMAGE_DATA" and produce compressed output normally.

    # Override tar to record calls and simulate behavior
    tar() {
        echo "tar $*" >> "$TEST_CSM_ROOT/_docker_calls"
        local mode="$1"
        case "$mode" in
            czf)
                # tar czf <output> -C <dir> . -- create a fake archive
                local outfile="$2"
                echo "FAKE_WORKSPACE_TAR" > "$outfile"
                ;;
            xzf)
                # tar xzf <input> --no-same-owner -C <dir> -- just succeed
                return 0
                ;;
        esac
    }
    export -f tar

    # Mock jq to record calls but run real jq for tests needing actual JSON
    # We do NOT mock jq since tests need real JSON parsing;
    # real jq is installed via ~/.local/bin

    # Mock instances_get_port
    instances_get_port() {
        echo "2222"
    }
    export -f instances_get_port

    # Mock instances_get_type
    instances_get_type() {
        echo "cli"
    }
    export -f instances_get_type

    # Mock credentials_load
    credentials_load() {
        export ANTHROPIC_API_KEY="sk-ant-test"
        return 0
    }
    export -f credentials_load

    # Mock credentials_get_docker_env_flags
    credentials_get_docker_env_flags() {
        CSM_DOCKER_ENV_FLAGS=("-e" "ANTHROPIC_API_KEY=sk-ant-test")
    }
    export -f credentials_get_docker_env_flags

    # Source modules (common.sh defines CSM_ROOT guard -- must source after setting CSM_ROOT)
    source "$BATS_TEST_DIRNAME/../lib/common.sh"
    source "$BATS_TEST_DIRNAME/../lib/backup.sh"
}

teardown() {
    rm -rf "$TEST_CSM_ROOT"
}

# ---------------------------------------------------------------------------
# backup_create tests
# ---------------------------------------------------------------------------

@test "backup_create creates timestamped directory under backups/{name}/" {
    run backup_create "myinstance"

    [ "$status" -eq 0 ]

    # There should be exactly one directory under backups/myinstance/
    local backup_count
    backup_count="$(find "$TEST_CSM_ROOT/backups/myinstance" -mindepth 1 -maxdepth 1 -type d | wc -l)"
    [ "$backup_count" -eq 1 ]
}

@test "backup_create produces metadata.json with required fields" {
    run backup_create "myinstance"

    [ "$status" -eq 0 ]

    # Find the backup directory
    local backup_dir
    backup_dir="$(find "$TEST_CSM_ROOT/backups/myinstance" -mindepth 1 -maxdepth 1 -type d | head -1)"

    [ -f "${backup_dir}/metadata.json" ]

    # Check required fields exist and are non-null
    local imagetag instance port type timestamp
    imagetag="$(jq -r '.imagetag' "${backup_dir}/metadata.json")"
    instance="$(jq -r '.instance' "${backup_dir}/metadata.json")"
    port="$(jq -r '.port' "${backup_dir}/metadata.json")"
    type="$(jq -r '.type' "${backup_dir}/metadata.json")"
    timestamp="$(jq -r '.timestamp' "${backup_dir}/metadata.json")"

    [ -n "$imagetag" ] && [ "$imagetag" != "null" ]
    [ "$instance" = "myinstance" ]
    [ "$port" = "2222" ]
    [ "$type" = "cli" ]
    [ -n "$timestamp" ] && [ "$timestamp" != "null" ]
}

@test "backup_create calls docker commit and docker save in correct order" {
    run backup_create "myinstance"

    [ "$status" -eq 0 ]

    # Check docker commit was called
    grep -q "docker commit" "$TEST_CSM_ROOT/_docker_calls"
    # Check docker save was called
    grep -q "docker save" "$TEST_CSM_ROOT/_docker_calls"

    # Verify order: commit line number < save line number
    local commit_line save_line
    commit_line="$(grep -n "docker commit" "$TEST_CSM_ROOT/_docker_calls" | head -1 | cut -d: -f1)"
    save_line="$(grep -n "docker save" "$TEST_CSM_ROOT/_docker_calls" | head -1 | cut -d: -f1)"
    [ "$commit_line" -lt "$save_line" ]
}

@test "backup_create produces image.tar.gz and workspace.tar.gz in backup directory" {
    run backup_create "myinstance"

    [ "$status" -eq 0 ]

    local backup_dir
    backup_dir="$(find "$TEST_CSM_ROOT/backups/myinstance" -mindepth 1 -maxdepth 1 -type d | head -1)"

    [ -f "${backup_dir}/image.tar.gz" ]
    [ -f "${backup_dir}/workspace.tar.gz" ]
}

@test "backup_create calls tar czf for workspace archive" {
    run backup_create "myinstance"

    [ "$status" -eq 0 ]

    grep -q "tar czf" "$TEST_CSM_ROOT/_docker_calls"
}

@test "backup_create reports completion with ok message" {
    run backup_create "myinstance"

    [ "$status" -eq 0 ]

    # Output should contain OK message (stripped of color codes)
    echo "$output" | grep -qi "backup"
}

@test "backup_create skips with warning when container status is not created" {
    # Override docker_status to return "not created"
    docker_status() {
        echo "not created"
    }
    export -f docker_status

    run backup_create "myinstance"

    # Should return non-zero (1)
    [ "$status" -ne 0 ]

    # Should NOT create any backup directory
    local backup_count
    backup_count="$(find "$TEST_CSM_ROOT/backups" -mindepth 2 -maxdepth 2 -type d 2>/dev/null | wc -l)"
    [ "$backup_count" -eq 0 ]
}

# ---------------------------------------------------------------------------
# backup_list tests
# ---------------------------------------------------------------------------

@test "backup_list returns 1 with warning when no backups exist" {
    run backup_list "myinstance"

    [ "$status" -eq 1 ]
    echo "$output" | grep -qi "no backup\|no.*backup\|backup.*found" || \
        echo "$output" | grep -qi "warn\|\[!\]"
}

@test "backup_list lists directories newest-first when multiple exist" {
    # Create fake backup directories with different timestamps
    mkdir -p "$TEST_CSM_ROOT/backups/myinstance/20240101-1200"
    mkdir -p "$TEST_CSM_ROOT/backups/myinstance/20240201-1200"
    mkdir -p "$TEST_CSM_ROOT/backups/myinstance/20240301-1200"

    run backup_list "myinstance"

    [ "$status" -eq 0 ]

    # The output should contain all three directories
    echo "$output" | grep -q "20240301"
    echo "$output" | grep -q "20240201"
    echo "$output" | grep -q "20240101"

    # 20240301 should appear before 20240101 (newest first)
    local pos_newest pos_oldest
    pos_newest="$(echo "$output" | grep -n "20240301" | head -1 | cut -d: -f1)"
    pos_oldest="$(echo "$output" | grep -n "20240101" | head -1 | cut -d: -f1)"
    [ "$pos_newest" -lt "$pos_oldest" ]
}

@test "backup_list populates _BACKUP_LISTED_DIRS array" {
    mkdir -p "$TEST_CSM_ROOT/backups/myinstance/20240301-1200"
    mkdir -p "$TEST_CSM_ROOT/backups/myinstance/20240201-1200"

    backup_list "myinstance"

    # _BACKUP_LISTED_DIRS should have 2 entries
    [ "${#_BACKUP_LISTED_DIRS[@]}" -eq 2 ]
}

# ---------------------------------------------------------------------------
# backup_restore tests
# ---------------------------------------------------------------------------

@test "backup_restore reads image tag from metadata.json" {
    # Create a fake backup directory
    local backup_dir="$TEST_CSM_ROOT/backups/myinstance/20240301-1200"
    mkdir -p "$backup_dir"

    # Write metadata with a known image tag
    jq -n \
        --arg imagetag "claude-sandbox-myinstance-backup-20240301-1200" \
        --arg instance "myinstance" \
        --argjson port 2222 \
        --arg type "cli" \
        --arg timestamp "20240301-1200" \
        '{imagetag: $imagetag, instance: $instance, port: $port, type: $type, timestamp: $timestamp}' \
        > "${backup_dir}/metadata.json"

    # Create fake archives
    echo "FAKE" > "${backup_dir}/image.tar.gz"
    echo "FAKE" > "${backup_dir}/workspace.tar.gz"

    run backup_restore "myinstance" "$backup_dir"

    [ "$status" -eq 0 ]

    # docker load should have been called
    grep -q "docker load" "$TEST_CSM_ROOT/_docker_calls"
}

@test "backup_restore calls docker stop and docker rm before loading image" {
    local backup_dir="$TEST_CSM_ROOT/backups/myinstance/20240301-1200"
    mkdir -p "$backup_dir"

    jq -n \
        --arg imagetag "claude-sandbox-myinstance-backup-20240301-1200" \
        --arg instance "myinstance" \
        --argjson port 2222 \
        --arg type "cli" \
        --arg timestamp "20240301-1200" \
        '{imagetag: $imagetag, instance: $instance, port: $port, type: $type, timestamp: $timestamp}' \
        > "${backup_dir}/metadata.json"

    echo "FAKE" > "${backup_dir}/image.tar.gz"
    echo "FAKE" > "${backup_dir}/workspace.tar.gz"

    run backup_restore "myinstance" "$backup_dir"

    [ "$status" -eq 0 ]

    # stop and rm should both be called
    grep -q "docker stop" "$TEST_CSM_ROOT/_docker_calls"
    grep -q "docker rm" "$TEST_CSM_ROOT/_docker_calls"

    # stop should appear before load
    local stop_line load_line
    stop_line="$(grep -n "docker stop" "$TEST_CSM_ROOT/_docker_calls" | head -1 | cut -d: -f1)"
    load_line="$(grep -n "docker load" "$TEST_CSM_ROOT/_docker_calls" | head -1 | cut -d: -f1)"
    [ "$stop_line" -lt "$load_line" ]
}

@test "backup_restore calls tar xzf with --no-same-owner" {
    local backup_dir="$TEST_CSM_ROOT/backups/myinstance/20240301-1200"
    mkdir -p "$backup_dir"

    jq -n \
        --arg imagetag "claude-sandbox-myinstance-backup-20240301-1200" \
        --arg instance "myinstance" \
        --argjson port 2222 \
        --arg type "cli" \
        --arg timestamp "20240301-1200" \
        '{imagetag: $imagetag, instance: $instance, port: $port, type: $type, timestamp: $timestamp}' \
        > "${backup_dir}/metadata.json"

    echo "FAKE" > "${backup_dir}/image.tar.gz"
    echo "FAKE" > "${backup_dir}/workspace.tar.gz"

    run backup_restore "myinstance" "$backup_dir"

    [ "$status" -eq 0 ]

    grep -q "tar xzf" "$TEST_CSM_ROOT/_docker_calls"
    grep -q -- "--no-same-owner" "$TEST_CSM_ROOT/_docker_calls"
}

@test "backup_restore starts container after extracting workspace" {
    local backup_dir="$TEST_CSM_ROOT/backups/myinstance/20240301-1200"
    mkdir -p "$backup_dir"

    jq -n \
        --arg imagetag "claude-sandbox-myinstance-backup-20240301-1200" \
        --arg instance "myinstance" \
        --argjson port 2222 \
        --arg type "cli" \
        --arg timestamp "20240301-1200" \
        '{imagetag: $imagetag, instance: $instance, port: $port, type: $type, timestamp: $timestamp}' \
        > "${backup_dir}/metadata.json"

    echo "FAKE" > "${backup_dir}/image.tar.gz"
    echo "FAKE" > "${backup_dir}/workspace.tar.gz"

    run backup_restore "myinstance" "$backup_dir"

    [ "$status" -eq 0 ]

    # docker run should be called (for starting container from backup image)
    grep -q "docker run" "$TEST_CSM_ROOT/_docker_calls"
}
