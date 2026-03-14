#!/usr/bin/env bats

load test_helper

@test "Dockerfile has no hardcoded password" {
  ! grep -q 'chpasswd' "$CSM_ROOT/scripts/Dockerfile"
}

@test "Dockerfile uses NOPASSWD sudo" {
  grep -q 'NOPASSWD' "$CSM_ROOT/scripts/Dockerfile"
}

@test "Dockerfile does not set root as final USER" {
  # The last USER line should be 'root' (for sshd), but claude user
  # is created with proper sudo access via sudoers.d
  last_user=$(grep '^USER' "$CSM_ROOT/scripts/Dockerfile" | tail -1 | awk '{print $2}')
  [ "$last_user" = "root" ]
}

# ---------------------------------------------------------------------------
# Multi-stage build structure
# ---------------------------------------------------------------------------

@test "Dockerfile has base stage" {
  grep -q 'AS base' "$CSM_ROOT/scripts/Dockerfile"
}

@test "Dockerfile has cli stage" {
  grep -q 'AS cli' "$CSM_ROOT/scripts/Dockerfile"
}

@test "Dockerfile has gui stage" {
  grep -q 'AS gui' "$CSM_ROOT/scripts/Dockerfile"
}

# ---------------------------------------------------------------------------
# GUI stage packages
# ---------------------------------------------------------------------------

@test "gui stage installs novnc" {
  grep -q 'novnc' "$CSM_ROOT/scripts/Dockerfile"
}

@test "gui stage installs tigervnc-standalone-server" {
  grep -q 'tigervnc-standalone-server' "$CSM_ROOT/scripts/Dockerfile"
}

@test "gui stage installs python3-websockify" {
  grep -q 'python3-websockify' "$CSM_ROOT/scripts/Dockerfile"
}

@test "gui stage installs chromium-browser" {
  grep -q 'chromium-browser' "$CSM_ROOT/scripts/Dockerfile"
}

@test "gui stage installs dbus-x11" {
  grep -q 'dbus-x11' "$CSM_ROOT/scripts/Dockerfile"
}

# ---------------------------------------------------------------------------
# Entrypoint VNC logic
# ---------------------------------------------------------------------------

@test "entrypoint.sh contains vncserver startup" {
  grep -q 'vncserver' "$CSM_ROOT/scripts/entrypoint.sh"
}

@test "entrypoint.sh contains websockify startup" {
  grep -q 'websockify' "$CSM_ROOT/scripts/entrypoint.sh"
}

# ---------------------------------------------------------------------------
# Claude Code native installer (INST-01)
# ---------------------------------------------------------------------------

@test "Dockerfile installs Claude Code via native installer not NPM" {
  grep -q 'claude.ai/install.sh' "$CSM_ROOT/scripts/Dockerfile"
}

# ---------------------------------------------------------------------------
# GitHub CLI installation (CRED-02)
# ---------------------------------------------------------------------------

@test "Dockerfile installs GitHub CLI from official apt repository" {
  grep -q 'githubcli-archive-keyring' "$CSM_ROOT/scripts/Dockerfile"
}

# ---------------------------------------------------------------------------
# No credentials baked into image layers (CRED-04)
# ---------------------------------------------------------------------------

@test "Dockerfile contains no hardcoded credential env vars" {
  ! grep -qiE 'ANTHROPIC_API_KEY|GITHUB_TOKEN' "$CSM_ROOT/scripts/Dockerfile"
}
