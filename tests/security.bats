#!/usr/bin/env bats

load test_helper

@test "lib/docker.sh binds SSH to localhost" {
  grep -q '127.0.0.1' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh drops capabilities" {
  grep -q 'cap-drop' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets memory limit from config" {
  grep -q 'settings_get.*memory_limit' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh sets CPU limit from config" {
  grep -q 'settings_get.*cpu_limit' "$CSM_ROOT/lib/docker.sh"
}

@test "lib/docker.sh documents no-new-privileges removal" {
  # no-new-privileges intentionally removed — it prevents sudo/apt-get
  grep -q 'no-new-privileges' "$CSM_ROOT/lib/docker.sh"
}
