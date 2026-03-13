---
phase: 05-integration-layer
verified: 2026-03-13T23:30:00Z
status: passed
score: 11/11 must-haves verified
re_verification: false
---

# Phase 5: Integration Layer Verification Report

**Phase Goal:** All sandbox instances automatically connect to the host Docker Desktop MCP Toolkit server on startup, and Claude Code remote control is available as an optional toggle
**Verified:** 2026-03-13T23:30:00Z
**Status:** passed
**Re-verification:** No — initial verification

---

## Goal Achievement

### Observable Truths

Plan 01 truths:

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 1 | `docker_run_instance` adds `--add-host=host.docker.internal:host-gateway` on Linux Engine | VERIFIED | `lib/docker.sh` lines 101-108: uname check + `_docker_detect_variant` + `cmd+=(--add-host=...)` |
| 2 | `docker_run_instance` passes `CSM_MCP_ENABLED` and `CSM_MCP_PORT` env vars to container | VERIFIED | `lib/credentials.sh` lines 104-107 appends `-e CSM_MCP_ENABLED=1` and `-e CSM_MCP_PORT=...`; `lib/docker.sh` line 112 passes instance name so flags are injected |
| 3 | `docker_run_instance` passes `CSM_REMOTE_CONTROL=1` when remote_control is true for the instance | VERIFIED | `lib/credentials.sh` lines 110-113: reads `remote_control` from registry, appends `-e CSM_REMOTE_CONTROL=1` when true |
| 4 | `instances_add` stores `mcp_enabled` (default true) and `remote_control` (default false) per instance | VERIFIED | `lib/instances.sh` lines 52-62: both cli and gui branches use `--argjson mcp_enabled true --argjson remote_control false` |
| 5 | `menu_action_new` prompts user for remote control toggle after container type selection | VERIFIED | `lib/menu.sh` lines 209-214: prompt after `instances_add`, calls `instances_set_remote_control "$name" true` on y/Y |

Plan 02 truths:

| # | Truth | Status | Evidence |
|---|-------|--------|----------|
| 6 | A newly started container with `mcp_enabled` probes `host.docker.internal:8811` and writes MCP config if reachable | VERIFIED | `scripts/entrypoint.sh` lines 23-43: curl probe + `claude mcp add-json` call |
| 7 | MCP config writing is idempotent — re-running entrypoint does not create duplicate entries | VERIFIED | `scripts/entrypoint.sh` line 32: `claude mcp get docker-mcp --scope user` check wraps the `add-json` call |
| 8 | If MCP Gateway is unreachable, container starts normally with a warning printed | VERIFIED | `scripts/entrypoint.sh` lines 40-42: WARNING printed, no exit/die call |
| 9 | A container with `CSM_REMOTE_CONTROL=1` launches `claude remote-control` as a background process | VERIFIED | `scripts/entrypoint.sh` lines 46-57: `su - claude -c "claude remote-control ... &"` |
| 10 | If remote-control fails to start, container continues with a warning about requiring claude.ai login | VERIFIED | `scripts/entrypoint.sh` lines 55-57: WARNING printed without halting sshd startup |
| 11 | README contains Integrations section with MCP Toolkit and Remote Control subsections | VERIFIED | `README.md` lines 136-173: `## Integrations`, `### MCP Toolkit (Docker)`, `### Remote Control` |

**Score:** 11/11 truths verified

---

### Required Artifacts

| Artifact | Expected | Status | Details |
|----------|----------|--------|---------|
| `lib/docker.sh` | Linux Engine --add-host detection + MCP/RC env flag injection | VERIFIED | `_docker_detect_variant` helper at lines 17-23; `--add-host` conditional at lines 101-108; `credentials_get_docker_env_flags "$name"` at line 112 |
| `lib/instances.sh` | Extended instance schema with `mcp_enabled` and `remote_control` fields | VERIFIED | `instances_add` writes both fields (lines 52-62); getters `instances_get_mcp_enabled`, `instances_get_remote_control` (lines 218-237); setters `instances_set_mcp_enabled`, `instances_set_remote_control` (lines 243-275) |
| `lib/menu.sh` | Remote control prompt in creation flow | VERIFIED | `menu_action_new` prompts at lines 209-214 with default N and inline account-type note |
| `lib/credentials.sh` | Extended env flags for MCP and remote control vars | VERIFIED | `credentials_get_docker_env_flags` accepts optional instance name (line 88); injects `CSM_MCP_ENABLED`, `CSM_MCP_PORT`, `CSM_REMOTE_CONTROL` conditionally (lines 101-113) |
| `scripts/entrypoint.sh` | MCP config block + remote control startup block | VERIFIED | MCP block lines 23-43; RC block lines 45-58; both between bashrc sourcing and GUI/sshd blocks |
| `README.md` | Integrations section documenting MCP and Remote Control setup | VERIFIED | Lines 136-173: prerequisites, gateway setup, port override, subscription warning, log location |

---

### Key Link Verification

Plan 01 key links:

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `lib/menu.sh` | `lib/instances.sh` | `instances_add` stores remote_control flag from menu prompt | WIRED | `menu.sh:213` calls `instances_set_remote_control "$name" true` after prompt |
| `lib/docker.sh` | `lib/instances.sh` | `docker_run_instance` reads `mcp_enabled` and `remote_control` from registry | WIRED | `credentials.sh:103,110` calls `instances_get_mcp_enabled` and `instances_get_remote_control`; `docker.sh:112` passes instance name to trigger this path |
| `lib/docker.sh` | `lib/credentials.sh` | `credentials_get_docker_env_flags` injects MCP/RC env vars | WIRED | `docker.sh:112` calls `credentials_get_docker_env_flags "$name"`; `docker.sh:113` spreads `CSM_DOCKER_ENV_FLAGS` into cmd array |

Plan 02 key links:

| From | To | Via | Status | Details |
|------|----|-----|--------|---------|
| `scripts/entrypoint.sh` | `claude mcp add-json` | writes MCP server config into `~/.claude.json` via CLI | WIRED | `entrypoint.sh:33` calls `su - claude -c "claude mcp add-json docker-mcp ..."` |
| `scripts/entrypoint.sh` | `claude remote-control` | launches background process when `CSM_REMOTE_CONTROL=1` | WIRED | `entrypoint.sh:48` calls `su - claude -c "claude remote-control ... &"` |
| `lib/docker.sh` | `scripts/entrypoint.sh` | env vars `CSM_MCP_ENABLED`, `CSM_MCP_PORT`, `CSM_REMOTE_CONTROL` injected by docker run | WIRED | Injection chain: `credentials.sh` builds flags -> `docker.sh:113` spreads into `docker run` cmd -> entrypoint consumes at lines 27 and 46 |

---

### Requirements Coverage

| Requirement | Source Plan | Description | Status | Evidence |
|-------------|------------|-------------|--------|----------|
| MCP-01 | 05-01, 05-02 | Sandbox instances automatically connect to host Docker MCP Toolkit server on startup | SATISFIED | `credentials.sh` injects `CSM_MCP_ENABLED=1`; `entrypoint.sh` probes gateway and writes MCP config via `claude mcp add-json` |
| MCP-02 | 05-02 | README includes instructions for setting up Docker Desktop MCP Toolkit on the host | SATISFIED | `README.md` lines 143-161: prerequisites list, gateway run command, verification step |
| MCP-03 | 05-01, 05-02 | MCP connection works without per-container MCP configuration | SATISFIED | Entrypoint auto-configures on startup using env vars; user never runs MCP commands manually |
| INST-02 | 05-01 | Claude Code remote control optionally configured on container startup | SATISFIED | Menu prompts for toggle; `instances_set_remote_control` stores choice; `entrypoint.sh` launches `claude remote-control` when `CSM_REMOTE_CONTROL=1` |

No orphaned requirements — all four requirement IDs declared across plans (MCP-01, MCP-02, MCP-03, INST-02) are accounted for with verified implementation evidence. REQUIREMENTS.md traceability table confirms all four mapped to Phase 5.

---

### Anti-Patterns Found

No blockers or warnings detected. Scan of all six modified files (`lib/docker.sh`, `lib/instances.sh`, `lib/menu.sh`, `lib/credentials.sh`, `scripts/entrypoint.sh`, `README.md`) found zero TODO/FIXME/PLACEHOLDER comments and no stub return patterns.

Notable implementation decisions confirmed in code:
- `jq has()` used instead of `//` for boolean backward compat (`instances.sh` lines 223, 236) — prevents `false // default` evaluating as the default
- Underscore-prefixed variables in `entrypoint.sh` (`_mcp_port`, `_mcp_url`, `_rc_log`, `_rc_url`) — avoids namespace pollution at top-level script scope (no `local` available outside functions)
- `credentials_get_docker_env_flags` backward compat: when called without instance name, integration flag injection is skipped entirely (line 101)

---

### Human Verification Required

The following behaviors cannot be verified programmatically:

#### 1. End-to-end MCP auto-connection on container start

**Test:** Start a new instance on a machine with Docker Desktop MCP Toolkit enabled. SSH into the container after startup.
**Expected:** `claude mcp list --scope user` shows `docker-mcp` registered pointing to `http://host.docker.internal:8811/sse`.
**Why human:** Requires live Docker Desktop + MCP Gateway running; curl probe behavior is environment-dependent.

#### 2. MCP gateway unreachable path

**Test:** Start an instance on a machine where no MCP gateway is running. Observe container startup logs.
**Expected:** Container starts normally; logs show `[csm] WARNING: MCP Gateway not reachable at http://host.docker.internal:8811/sse` followed by install instructions. SSH access still works.
**Why human:** Requires controlled network environment to ensure gateway is absent.

#### 3. Remote control session URL extraction

**Test:** Create an instance with remote control enabled, authenticate via `/login` inside the container, then restart it. Observe startup logs.
**Expected:** `[csm] Remote control session: https://claude.ai/...` URL printed in container startup logs.
**Why human:** Requires claude.ai subscription account and live authentication state.

#### 4. Linux Engine `--add-host` resolution

**Test:** On a Linux machine running Docker Engine (not Docker Desktop), start an instance and SSH in. Run `ping host.docker.internal` or `curl http://host.docker.internal:8811`.
**Expected:** `host.docker.internal` resolves to the host machine IP via the injected route.
**Why human:** Requires Linux Docker Engine environment; WSL2/macOS behavior differs.

---

### Gaps Summary

No gaps. All 11 observable truths verified, all 6 required artifacts pass all three levels (exists, substantive, wired), all 6 key links confirmed wired, all 4 requirement IDs satisfied with direct implementation evidence. All 4 task commits (5fcf9be, b03e751, ef7beea, 0efc8a9) verified in git log.

---

_Verified: 2026-03-13T23:30:00Z_
_Verifier: Claude (gsd-verifier)_
