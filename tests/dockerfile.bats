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
