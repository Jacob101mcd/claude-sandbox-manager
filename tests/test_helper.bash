#!/usr/bin/env bash
# BATS test helper — sets project root for all test files

CSM_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
export CSM_ROOT
