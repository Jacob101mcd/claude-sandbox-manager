#!/usr/bin/env bats

load test_helper

# ---------------------------------------------------------------------------
# Task 05-02-01 (MCP-03): MCP Gateway auto-configuration block
# ---------------------------------------------------------------------------

@test "entrypoint activates MCP block when CSM_MCP_ENABLED equals 1" {
    grep -q 'CSM_MCP_ENABLED.*==.*"1"' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint skips MCP block when CSM_MCP_ENABLED is not set (defaults to 0)" {
    # The guard must default to 0 so the block is skipped when var is absent
    grep -q 'CSM_MCP_ENABLED:-0' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint uses curl to probe MCP gateway reachability" {
    grep -q 'curl' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint curl probe uses max-time for timeout" {
    grep -q 'max-time' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint calls claude mcp add-json to write MCP config" {
    grep -q 'claude mcp add-json' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint checks idempotency with claude mcp get before writing config" {
    grep -q 'claude mcp get' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint idempotency check prevents duplicate config on re-run" {
    # The mcp get check must gate the mcp add-json call (negated condition)
    grep -qF '! su - claude -c "claude mcp get' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint prints warning when MCP gateway is unreachable" {
    grep -q 'WARNING.*MCP Gateway not reachable' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint MCP log messages use csm prefix" {
    # All MCP block messages must carry the [csm] prefix
    grep -q '\[csm\].*MCP' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint MCP warning carries csm prefix" {
    grep -q '\[csm\].*WARNING.*MCP' "$CSM_ROOT/scripts/entrypoint.sh"
}

# ---------------------------------------------------------------------------
# Task 05-02-02 (INST-02): Remote control startup block
# ---------------------------------------------------------------------------

@test "entrypoint activates remote control block when CSM_REMOTE_CONTROL equals 1" {
    grep -q 'CSM_REMOTE_CONTROL.*==.*"1"' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint skips remote control block when CSM_REMOTE_CONTROL is not set" {
    # The guard must use a safe default so the block is skipped when var is absent
    grep -q 'CSM_REMOTE_CONTROL:-' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint launches claude remote-control as background process" {
    grep -q 'claude remote-control' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint remote-control process runs in background" {
    grep -qP 'claude remote-control.*&' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint writes remote-control output to csm-remote-control.log" {
    grep -q 'csm-remote-control.log' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint remote-control log file is under /tmp" {
    grep -q '/tmp/csm-remote-control.log' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint prints warning about claude.ai login when remote control fails" {
    grep -qi 'WARNING.*[Rr]emote control' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint remote control warning mentions claude.ai login" {
    grep -q 'claude.ai' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint remote control log messages use csm prefix" {
    grep -q '\[csm\].*[Rr]emote' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint remote control warning carries csm prefix" {
    grep -q '\[csm\].*WARNING.*[Rr]emote' "$CSM_ROOT/scripts/entrypoint.sh"
}

# ---------------------------------------------------------------------------
# Structural ordering: MCP and RC blocks appear before GUI/sshd blocks
# ---------------------------------------------------------------------------

@test "entrypoint MCP block appears before sshd exec" {
    # Line number of MCP block must be less than line number of exec sshd
    mcp_line=$(grep -n 'CSM_MCP_ENABLED' "$CSM_ROOT/scripts/entrypoint.sh" | head -1 | cut -d: -f1)
    sshd_line=$(grep -n 'exec.*sshd' "$CSM_ROOT/scripts/entrypoint.sh" | head -1 | cut -d: -f1)
    [ "$mcp_line" -lt "$sshd_line" ]
}

@test "entrypoint remote control block appears before sshd exec" {
    rc_line=$(grep -n 'CSM_REMOTE_CONTROL' "$CSM_ROOT/scripts/entrypoint.sh" | head -1 | cut -d: -f1)
    sshd_line=$(grep -n 'exec.*sshd' "$CSM_ROOT/scripts/entrypoint.sh" | head -1 | cut -d: -f1)
    [ "$rc_line" -lt "$sshd_line" ]
}

@test "entrypoint contains at least four csm-prefixed log lines" {
    count=$(grep -c '\[csm\]' "$CSM_ROOT/scripts/entrypoint.sh")
    [ "$count" -ge 4 ]
}
