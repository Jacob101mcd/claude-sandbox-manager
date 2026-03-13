#!/usr/bin/env bats

load test_helper

@test "lib/docker.sh binds SSH to localhost" {
  [[ -f "$CSM_ROOT/lib/docker.sh" ]] || skip "lib/docker.sh not yet created"
  grep -q '127.0.0.1' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh drops capabilities" {
  [[ -f "$CSM_ROOT/lib/docker.sh" ]] || skip "lib/docker.sh not yet created"
  grep -q 'cap-drop' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets memory limit" {
  [[ -f "$CSM_ROOT/lib/docker.sh" ]] || skip "lib/docker.sh not yet created"
  grep -q 'memory=2g' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets CPU limit" {
  [[ -f "$CSM_ROOT/lib/docker.sh" ]] || skip "lib/docker.sh not yet created"
  grep -q 'cpus=2' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets no-new-privileges" {
  [[ -f "$CSM_ROOT/lib/docker.sh" ]] || skip "lib/docker.sh not yet created"
  grep -q 'no-new-privileges' "$CSM_ROOT/lib/docker.sh"
}
