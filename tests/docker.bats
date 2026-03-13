#!/usr/bin/env bats

load test_helper

@test "docker.sh binds SSH to localhost only" {
  grep -q '127.0.0.1' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh drops MKNOD capability" {
  grep -q 'cap-drop=MKNOD' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh drops AUDIT_WRITE capability" {
  grep -q 'cap-drop=AUDIT_WRITE' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh drops all required capabilities" {
  grep -q 'cap-drop=MKNOD' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=AUDIT_WRITE' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=SETFCAP' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=SETPCAP' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=NET_BIND_SERVICE' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=SYS_CHROOT' "$CSM_ROOT/lib/docker.sh"
  grep -q 'cap-drop=FSETID' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh sets memory limit" {
  grep -q 'memory=2g' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh sets CPU limit" {
  grep -q 'cpus=2' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh sets no-new-privileges" {
  grep -q 'no-new-privileges' "$CSM_ROOT/lib/docker.sh"
}

@test "docker.sh removes existing container before run" {
  grep -q 'docker rm -f' "$CSM_ROOT/lib/docker.sh"
}
