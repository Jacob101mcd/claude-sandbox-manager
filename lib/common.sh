#!/usr/bin/env bash
# lib/common.sh -- Shared constants, color output helpers, error handling
#
# This file is sourced by bin/csm. Do not execute directly.
# CSM_ROOT must be set by the entry point before sourcing this file.

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Color support
# ---------------------------------------------------------------------------
# Disable colors when stdout is not a terminal (piped, redirected, etc.)
if [[ -t 1 ]]; then
    _CLR_RESET=$'\033[0m'
    _CLR_RED=$'\033[0;31m'
    _CLR_GREEN=$'\033[0;32m'
    _CLR_YELLOW=$'\033[0;33m'
    _CLR_BLUE=$'\033[0;34m'
else
    _CLR_RESET=""
    _CLR_RED=""
    _CLR_GREEN=""
    _CLR_YELLOW=""
    _CLR_BLUE=""
fi

# ---------------------------------------------------------------------------
# Message helpers
# ---------------------------------------------------------------------------

msg_info()  { echo "${_CLR_BLUE}[*]${_CLR_RESET} $*" >&2; }
msg_ok()    { echo "${_CLR_GREEN}[OK]${_CLR_RESET} $*" >&2; }
msg_warn()  { echo "${_CLR_YELLOW}[!]${_CLR_RESET} $*" >&2; }
msg_error() { echo "${_CLR_RED}[X]${_CLR_RESET} $*" >&2; }

die() {
    msg_error "$@"
    exit 1
}

# ---------------------------------------------------------------------------
# Path helpers (mirror PowerShell equivalents)
# ---------------------------------------------------------------------------

common_container_name() {
    echo "claude-sandbox-$1"
}

common_ssh_alias() {
    if [[ "$1" == "default" ]]; then
        echo "claude-sandbox"
    else
        echo "claude-$1"
    fi
}

common_ssh_dir() {
    echo "${CSM_ROOT}/ssh/$1"
}

common_workspace_dir() {
    echo "${CSM_ROOT}/workspaces/$1"
}

common_backup_dir() {
    echo "${CSM_ROOT}/backups/$1"
}
