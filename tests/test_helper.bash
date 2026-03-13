#!/usr/bin/env bash
# BATS test helper — sets project root for all test files

CSM_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export CSM_ROOT

# Ensure ~/.local/bin is in PATH (jq, shellcheck installed there)
if [[ -d "$HOME/.local/bin" ]] && [[ ":$PATH:" != *":$HOME/.local/bin:"* ]]; then
    export PATH="$HOME/.local/bin:$PATH"
fi
