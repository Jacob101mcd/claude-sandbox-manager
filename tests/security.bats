#!/usr/bin/env bats

load test_helper

@test "lib/docker.sh binds SSH to localhost" {
  grep -q '127.0.0.1' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh drops capabilities" {
  grep -q 'cap-drop' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets memory limit" {
  grep -q 'memory=2g' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets CPU limit" {
  grep -q 'cpus=2' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets no-new-privileges" {
  grep -q 'no-new-privileges' "$CSM_ROOT/lib/docker.sh"
}
