# Phase 5: Integration Layer - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

All sandbox instances automatically connect to the host Docker MCP Toolkit server on startup, and Claude Code remote control is available as an optional per-instance toggle. Covers both Docker Desktop MCP and Docker Engine `docker mcp` CLI plugin. Includes a combined "Integrations" README section for MCP + remote control setup.

</domain>

<decisions>
## Implementation Decisions

### MCP Gateway connectivity
- Auto-detect Docker Desktop vs Docker Engine and add `--add-host=host.docker.internal:host-gateway` on Linux Engine (Docker Desktop already provides it)
- Container always uses `host.docker.internal` as the MCP endpoint
- entrypoint.sh writes MCP server config into Claude Code's config directory on startup — container is MCP-ready immediately on SSH
- MCP auto-connect on by default for all new instances
- Per-instance MCP toggle stored in instances.json (`mcp_enabled: true` by default)
- Hardcode default MCP Toolkit port; user can override via `CSM_MCP_PORT` in `.env`
- If MCP Gateway unreachable at startup: entrypoint.sh prints a warning, container starts normally

### MCP platform support
- Support both Docker Desktop MCP and `docker mcp` CLI plugin transparently — auto-detect which is available
- If neither detected: warn on every container start ("MCP Toolkit not detected — install Docker Desktop MCP or docker mcp CLI plugin") and continue without MCP config
- Researcher must investigate how `docker mcp` CLI plugin works on Linux Docker Engine and how the gateway configuration differs from Docker Desktop

### Remote control toggle
- Prompt at instance creation time: "Enable remote control? (y/N)" — default off
- Stored per-instance in instances.json (`remote_control: true/false`)
- Available for both CLI and GUI container types
- Manager passes `CSM_REMOTE_CONTROL=1` as docker run `-e` flag (read from instances.json by `docker_run_instance()`)
- entrypoint.sh checks `CSM_REMOTE_CONTROL` env var; if set, launches `claude remote-control` as background process via `su - claude`
- After instance starts with remote control enabled: print connection URL/info to user (like GUI instances show noVNC URL)

### Documentation
- Combined "Integrations" README section covering both MCP Toolkit and Remote Control as subsections
- MCP subsection: prerequisites, 3-5 step setup instructions, verification step to confirm containers can reach gateway
- Remote Control subsection: how to enable at creation, what it does, link to official docs (code.claude.com/docs/en/remote-control)
- Resource limits documentation deferred to Phase 6

### Claude's Discretion
- Exact MCP config file format and location inside container (depends on Claude Code's config structure)
- How auto-detection of Docker Desktop vs Engine works (docker context, socket inspection, etc.)
- `claude remote-control` exact flags and startup sequence
- How to extract/display remote control connection URL from the process output
- MCP Toolkit port detection and override mechanism details
- Entrypoint startup ordering (MCP config, remote control, VNC, SSH)

</decisions>

<specifics>
## Specific Ideas

- Remote control must run `claude remote-control` as a command — it's a process, not just a config setting
- MCP Toolkit is available as both Docker Desktop integration AND `docker mcp` CLI plugin for Docker Engine — support both transparently
- Warning pattern: warn on every container start if MCP not available (not just once at manager startup)
- Follow established patterns: env var injection via `-e` flags, entrypoint.sh detects features and configures, per-instance settings in instances.json

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `docker_run_instance()` in lib/docker.sh: Bash array for docker run flags — add `--add-host`, `-e CSM_REMOTE_CONTROL`, and MCP-related flags
- `instances_add()` / instances.json: stores `{ port, type, vnc_port }` — extend with `mcp_enabled`, `remote_control` fields
- `credentials_get_docker_env_flags()` in lib/credentials.sh: pattern for building `-e` flags from config — extend for MCP/remote control vars
- `scripts/entrypoint.sh`: already handles GUI variant detection (checks for vncserver binary) and credential injection to `.csm-env` — extend with MCP config writing and remote control startup
- `lib/menu.sh`: interactive prompts (y/N pattern) — reuse for remote control prompt at creation time
- `lib/common.sh`: msg_info, msg_ok, msg_warn for consistent output — use for MCP/remote control status messages

### Established Patterns
- Docker run command built as Bash array — extend with conditional flags for MCP and remote control
- Entrypoint feature detection: checks for binary presence (`command -v vncserver`) to detect GUI variant — similar pattern for MCP detection
- Environment variable signaling: credentials injected via `-e` flags, read by entrypoint.sh — same pattern for CSM_REMOTE_CONTROL
- Per-instance config in instances.json with atomic jq writes via tmp file + mv
- Warn-and-continue for missing optional features (credentials pattern from Phase 2)

### Integration Points
- `docker_run_instance()`: Add `--add-host` flag (conditionally), `-e CSM_REMOTE_CONTROL=1` (when enabled), MCP-related env vars
- `instances_add()`: Extend JSON schema for `mcp_enabled` and `remote_control` fields
- `scripts/entrypoint.sh`: Add MCP config writing section and remote control startup section
- `lib/menu.sh`: Add remote control prompt to instance creation flow (after container type selection)
- `README.md`: New "Integrations" section with MCP Toolkit and Remote Control subsections

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 05-integration-layer*
*Context gathered: 2026-03-13*
