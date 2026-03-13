#!/usr/bin/env bash
# lib/platform.sh -- OS detection and platform-specific variable setup
#
# This file is sourced by bin/csm after common.sh.
# Provides: platform_detect, platform_check_dependencies, CSM_PLATFORM

# ---------------------------------------------------------------------------
# Platform detection
# ---------------------------------------------------------------------------

platform_detect() {
    local os
    os="$(uname -s)"

    case "$os" in
        Linux)  CSM_PLATFORM="linux"  ;;
        Darwin) CSM_PLATFORM="macos"  ;;
        *)      die "Unsupported operating system: $os" ;;
    esac
    export CSM_PLATFORM

    # Require Bash 4+ (macOS ships 3.2; users need Homebrew Bash)
    if (( BASH_VERSINFO[0] < 4 )); then
        die "Bash 4.0 or later is required (found ${BASH_VERSION}). On macOS, install via: brew install bash"
    fi
}

# ---------------------------------------------------------------------------
# Dependency checks
# ---------------------------------------------------------------------------

platform_check_dependencies() {
    command -v docker     >/dev/null 2>&1 || die "docker is not installed or not in PATH"
    command -v jq         >/dev/null 2>&1 || die "jq is not installed or not in PATH"
    command -v ssh-keygen >/dev/null 2>&1 || die "ssh-keygen is not installed or not in PATH"

    docker info &>/dev/null || die "Docker is not running. Please start the Docker daemon."
}
