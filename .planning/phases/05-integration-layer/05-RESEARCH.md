# Phase 5: Integration Layer - Research

**Researched:** 2026-03-13
**Domain:** Docker MCP Toolkit connectivity, Claude Code MCP config, Claude Code remote-control
**Confidence:** MEDIUM (MCP Gateway port verified via multiple sources; remote-control subscription requirement is HIGH confidence; `docker mcp` Linux detection is MEDIUM)

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

- Auto-detect Docker Desktop vs Docker Engine and add `--add-host=host.docker.internal:host-gateway` on Linux Engine (Docker Desktop already provides it)
- Container always uses `host.docker.internal` as the MCP endpoint
- entrypoint.sh writes MCP server config into Claude Code's config directory on startup — container is MCP-ready immediately on SSH
- MCP auto-connect on by default for all new instances
- Per-instance MCP toggle stored in instances.json (`mcp_enabled: true` by default)
- Hardcode default MCP Toolkit port; user can override via `CSM_MCP_PORT` in `.env`
- If MCP Gateway unreachable at startup: entrypoint.sh prints a warning, container starts normally
- Support both Docker Desktop MCP and `docker mcp` CLI plugin transparently — auto-detect which is available
- If neither detected: warn on every container start and continue without MCP config
- Prompt at instance creation time: "Enable remote control? (y/N)" — default off
- Stored per-instance in instances.json (`remote_control: true/false`)
- Manager passes `CSM_REMOTE_CONTROL=1` as docker run `-e` flag
- entrypoint.sh checks `CSM_REMOTE_CONTROL` env var; if set, launches `claude remote-control` as background process via `su - claude`
- Combined "Integrations" README section covering both MCP Toolkit and Remote Control

### Claude's Discretion

- Exact MCP config file format and location inside container (depends on Claude Code's config structure)
- How auto-detection of Docker Desktop vs Engine works (docker context, socket inspection, etc.)
- `claude remote-control` exact flags and startup sequence
- How to extract/display remote control connection URL from the process output
- MCP Toolkit port detection and override mechanism details
- Entrypoint startup ordering (MCP config, remote control, VNC, SSH)

### Deferred Ideas (OUT OF SCOPE)

None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| MCP-01 | Sandbox instances automatically connect to host Docker MCP Toolkit server on startup | MCP Gateway port (8811), `host.docker.internal` endpoint, `claude mcp add` CLI command written by entrypoint.sh |
| MCP-02 | README includes instructions for setting up Docker Desktop MCP Toolkit on the host | Docker Docs official setup flow documented |
| MCP-03 | MCP connection works without per-container MCP configuration | Gateway-level config aggregates all servers; container only needs one `claude mcp add` call |
| INST-02 | Claude Code remote control optionally configured on container startup | `claude remote-control` command verified; subscription requirement documented as warning |
</phase_requirements>

---

## Summary

Phase 5 wires two outbound integrations into sandbox containers: (1) automatic MCP Gateway connectivity so Claude Code inside the container can use the host's MCP servers without any per-container setup, and (2) an optional `claude remote-control` background process that lets users continue container sessions from a browser or mobile device.

The MCP half is straightforward: the Docker MCP Gateway (whether via Docker Desktop or the standalone `docker mcp` CLI plugin) listens on port 8811 (SSE transport) on the host. Inside a container, `host.docker.internal` resolves to the host, so `entrypoint.sh` can write a one-line `claude mcp add` call that configures Claude Code on first start. No per-container gateway config is needed.

The remote-control half has a critical platform constraint: `claude remote-control` requires a claude.ai subscription (Pro, Max, Team, or Enterprise) and **does not work with API keys**. The container must be authenticated with `/login` before remote control works. This means the feature is user-gated, not tool-gated — the toggle can be set freely, but it will silently do nothing if the user inside the container is authenticated only via ANTHROPIC_API_KEY. This must be documented prominently in the README.

**Primary recommendation:** Write a two-section entrypoint block: (1) MCP config block that always runs when `mcp_enabled` is true, writes `~/.claude.json` user-scoped MCP config via `claude mcp add-json`, checks host reachability with `curl --silent --max-time 2`, warns and continues if unreachable. (2) Remote control block that runs only when `CSM_REMOTE_CONTROL=1`, launches `claude remote-control --name "CSM: $HOSTNAME"` as a background daemon under the `claude` user, captures the session URL by tailing the process output, and prints it to the container start log.

---

## Standard Stack

### Core
| Library / Tool | Version | Purpose | Why Standard |
|----------------|---------|---------|--------------|
| Docker MCP Gateway | current | Aggregates MCP servers on host, serves SSE/HTTP endpoint | Official Docker tool; works with Docker Desktop and bare Docker Engine |
| `claude mcp add` CLI | Claude Code v2.1.51+ | Writes MCP server config into `~/.claude.json` non-interactively | Only supported mechanism to inject MCP config from a script |
| `claude remote-control` | Claude Code v2.1.51+ | Starts a Remote Control session server | Official Anthropic feature, not a third-party tool |

### Supporting
| Library / Tool | Version | Purpose | When to Use |
|----------------|---------|---------|-------------|
| `curl` | system | Check host reachability before writing MCP config | Lightweight probe, already in container base image |
| `jq` | system | Extend instances.json schema | Already used throughout the codebase |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `claude mcp add` CLI | Direct write to `~/.claude.json` | Direct write bypasses future schema changes; CLI is the supported path |
| SSE transport (port 8811) | HTTP streamable transport | HTTP streamable is the modern preferred transport but SSE is what Docker MCP Gateway exposes by default; use SSE for now |

**Installation:** No new host packages needed. Container already has curl, jq, bash.

---

## Architecture Patterns

### MCP Gateway Transport

The Docker MCP Gateway runs on the **host** and exposes an SSE endpoint. Default port is **8811**. The URL pattern is:

```
http://host.docker.internal:8811/sse
```

For HTTP streamable transport (if configured), the endpoint would be:
```
http://host.docker.internal:PORT/mcp
```

The Gateway is configured either:
- **Docker Desktop MCP Toolkit**: Auto-starts with Desktop, no separate daemon needed. Stores config in `~/.docker/mcp/`.
- **`docker mcp` CLI plugin**: Installed standalone on Linux Docker Engine. Gateway started with `docker mcp gateway run --transport sse --port 8811` as a background process. User must start this manually.

### Claude Code MCP Config File

Claude Code stores MCP server config in `~/.claude.json` (user scope, cross-project) or `.mcp.json` (project scope). For this use case, **user scope** is correct because the container has no project directory at startup.

Adding a server via CLI (preferred — survives schema changes):

```bash
# Source: https://code.claude.com/docs/en/mcp
su - claude -c "claude mcp add --transport sse docker-mcp http://host.docker.internal:8811/sse --scope user"
```

Adding via JSON (alternative — faster, no interactive):

```bash
su - claude -c "claude mcp add-json docker-mcp '{\"type\":\"sse\",\"url\":\"http://host.docker.internal:8811/sse\"}' --scope user"
```

The resulting `~/.claude.json` will contain:

```json
{
  "mcpServers": {
    "docker-mcp": {
      "type": "sse",
      "url": "http://host.docker.internal:8811/sse"
    }
  }
}
```

### Docker Desktop vs Engine Detection

Docker Desktop on Linux uses a context named `desktop-linux`. Docker Engine uses `default` with socket `unix:///var/run/docker.sock`. Detection from the **host manager** (not the container):

```bash
# Pattern: check active context name
_detect_docker_variant() {
    local ctx
    ctx="$(docker context show 2>/dev/null)"
    if [[ "$ctx" == "desktop-linux" ]]; then
        echo "desktop"
    else
        # Check if Desktop socket exists alongside Engine socket
        if docker context inspect desktop-linux &>/dev/null 2>&1; then
            echo "desktop"
        else
            echo "engine"
        fi
    fi
}
```

On macOS and Windows, Docker Desktop is essentially always present. The `--add-host` flag is needed only on Linux with Docker Engine.

### Entrypoint Startup Ordering

Based on existing pattern (VNC starts before SSH):

```
1. Write .csm-env (credentials)
2. Ensure .bashrc sources .csm-env
3. [MCP block] if mcp_enabled: probe host, write MCP config, warn if unreachable
4. [Remote control block] if CSM_REMOTE_CONTROL=1: launch background daemon
5. [GUI block] if vncserver present: configure VNC, start VNC + websockify
6. exec sshd -D
```

### Remote Control Background Process

`claude remote-control` is **not a daemon** — it stays running in the foreground, polling the Anthropic API outbound via HTTPS. It has no inbound port. Run it as a background process:

```bash
# Source: https://code.claude.com/docs/en/remote-control
su - claude -c "claude remote-control --name 'CSM: $(hostname)' > /tmp/remote-control.log 2>&1 &"
```

The session URL is written to stdout and can be scraped from the log:

```bash
sleep 2
local url
url="$(grep -oP 'https://[^\s]+claude\.ai[^\s]+' /tmp/remote-control.log 2>/dev/null | head -1)"
if [[ -n "$url" ]]; then
    msg_ok "Remote control session: $url"
fi
```

### Anti-Patterns to Avoid
- **Writing `~/.claude.json` directly**: Skip the CLI and write JSON manually — this breaks if Anthropic changes the schema. Use `claude mcp add` or `claude mcp add-json`.
- **Assuming `host.docker.internal` exists on Linux Engine**: On Linux Docker Engine (not Desktop), `host.docker.internal` only resolves if `--add-host=host.docker.internal:host-gateway` is passed at `docker run`. The manager must conditionally add this flag.
- **Expecting remote-control to work with API keys**: Remote control requires a claude.ai subscription login (`/login`), not an API key. Do not make it sound like it works out of the box.
- **Blocking sshd on remote-control startup**: Run the process in the background and continue. Never make sshd wait for remote-control to succeed.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| MCP server aggregation | Custom proxy | Docker MCP Gateway | Gateway handles auth, spawning, config, all MCP servers in one endpoint |
| MCP config injection | Write `~/.claude.json` manually | `claude mcp add-json` CLI | CLI handles scope, schema version, and atomic writes |
| Remote session routing | Build WebSocket relay | `claude remote-control` | Feature is built-in, uses Anthropic's infra, no ports to open |

---

## Common Pitfalls

### Pitfall 1: `host.docker.internal` Absent on Linux Engine
**What goes wrong:** `entrypoint.sh` writes MCP config pointing to `host.docker.internal:8811`, but DNS resolution fails inside the container. Claude Code cannot connect to the gateway and reports a connection error.
**Why it happens:** Docker Engine on Linux does not automatically inject `host.docker.internal`. Docker Desktop on macOS/Windows/Linux does.
**How to avoid:** `docker_run_instance()` must detect Linux Engine and add `--add-host=host.docker.internal:host-gateway` to the run command. The detection logic lives in the host-side `lib/docker.sh`, not in the container.
**Warning signs:** `curl: Could not resolve host: host.docker.internal` in the startup warning.

### Pitfall 2: Remote Control Requires claude.ai Login, Not API Key
**What goes wrong:** User enables remote control, entrypoint starts `claude remote-control`, but it exits immediately with an auth error because the container is only configured with `ANTHROPIC_API_KEY`.
**Why it happens:** `claude remote-control` requires a Pro/Max/Team/Enterprise claude.ai account authenticated via `/login`. API key auth is explicitly unsupported.
**How to avoid:** README must document this clearly. The `entrypoint.sh` block should check if remote control starts successfully (non-zero exit within 3 seconds) and emit a clear warning: "Remote control requires claude.ai account login (`/login`). API keys are not supported."
**Warning signs:** `claude remote-control` exits with code 1 and error message about authentication.

### Pitfall 3: MCP Gateway Not Running on Host
**What goes wrong:** Container starts, `entrypoint.sh` writes MCP config, but the Docker MCP Gateway is not running on the host. All MCP tool calls from Claude Code fail silently or with cryptic errors.
**Why it happens:** Docker Desktop MCP Toolkit may not be enabled, or on Linux Engine the user hasn't started `docker mcp gateway run`.
**How to avoid:** `entrypoint.sh` probes the endpoint before writing config: `curl --silent --max-time 2 http://host.docker.internal:8811/sse`. On failure, print a clear actionable warning ("MCP Gateway not reachable at host.docker.internal:8811 — install Docker Desktop MCP Toolkit or run `docker mcp gateway run`") and skip writing the MCP config. Container starts normally.
**Warning signs:** Curl probe fails, warning printed, no `~/.claude.json` MCP entry written.

### Pitfall 4: `claude mcp add-json` Is Non-Interactive But May Prompt
**What goes wrong:** `su - claude -c "claude mcp add-json ..."` inside `entrypoint.sh` hangs waiting for a trust prompt or workspace confirmation that never comes.
**Why it happens:** First-run Claude Code may prompt for workspace trust or account setup.
**How to avoid:** Use `--scope user` (not project scope) to avoid project-level prompts. Run as a non-interactive shell and redirect stdio: `su - claude -c "claude mcp add-json ... --scope user < /dev/null"`. If the command is unavailable (older Claude Code), fall back to writing `~/.claude.json` directly with `jq`.

### Pitfall 5: Existing MCP Config Overwritten on Every Start
**What goes wrong:** Every container start re-runs `claude mcp add-json`, resulting in duplicate entries or resetting user-added MCP servers.
**Why it happens:** `entrypoint.sh` runs unconditionally on every start.
**How to avoid:** Check if the `docker-mcp` server entry already exists before adding: `su - claude -c "claude mcp get docker-mcp --scope user" &>/dev/null || su - claude -c "claude mcp add-json ..."`. Add only if absent.

---

## Code Examples

### MCP Probe + Config Write (entrypoint.sh)

```bash
# Source: https://code.claude.com/docs/en/mcp + https://docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/
_mcp_port="${CSM_MCP_PORT:-8811}"
_mcp_url="http://host.docker.internal:${_mcp_port}/sse"

# Only configure if CSM_MCP_ENABLED is not explicitly 0
if [[ "${CSM_MCP_ENABLED:-1}" != "0" ]]; then
    # Probe gateway reachability (2-second timeout, no output)
    if curl --silent --max-time 2 --output /dev/null "${_mcp_url}"; then
        # Add only if not already registered (idempotent)
        if ! su - claude -c "claude mcp get docker-mcp --scope user" &>/dev/null; then
            su - claude -c "claude mcp add-json docker-mcp \
                '{\"type\":\"sse\",\"url\":\"${_mcp_url}\"}' --scope user < /dev/null" \
                && echo "[csm] MCP Gateway connected: ${_mcp_url}" \
                || echo "[csm] WARNING: Failed to write MCP config"
        fi
    else
        echo "[csm] WARNING: MCP Gateway not reachable at ${_mcp_url}"
        echo "[csm]   Install Docker Desktop MCP Toolkit or run: docker mcp gateway run --transport sse"
    fi
fi
```

### Remote Control Background Start (entrypoint.sh)

```bash
# Source: https://code.claude.com/docs/en/remote-control
if [[ "${CSM_REMOTE_CONTROL:-}" == "1" ]]; then
    RC_LOG="/tmp/csm-remote-control.log"
    su - claude -c "claude remote-control --name 'CSM: $(hostname)' > '${RC_LOG}' 2>&1 &"
    # Give it 3 seconds to either register or fail
    sleep 3
    if grep -q 'https://claude\.ai' "${RC_LOG}" 2>/dev/null; then
        local rc_url
        rc_url="$(grep -oP 'https://claude\.ai\S+' "${RC_LOG}" | head -1)"
        echo "[csm] Remote control session: ${rc_url}"
    else
        echo "[csm] WARNING: Remote control did not start. Requires claude.ai account login (/login)."
        echo "[csm]   API keys are not supported for remote control."
    fi
fi
```

### `--add-host` Flag in docker_run_instance (lib/docker.sh)

```bash
# Detect Linux Docker Engine (not Desktop) — add host.docker.internal mapping
if [[ "$(uname -s)" == "Linux" ]]; then
    local ctx
    ctx="$(docker context show 2>/dev/null || echo "default")"
    if [[ "$ctx" != "desktop-linux" ]] && ! docker context inspect desktop-linux &>/dev/null; then
        cmd+=(--add-host=host.docker.internal:host-gateway)
    fi
fi
```

### instances_add schema extension (lib/instances.sh)

```bash
# Extend JSON with mcp_enabled and remote_control fields
jq --arg name "$name" --argjson port "$port" --arg type "$type" \
   --argjson mcp_enabled true --argjson remote_control false \
   '.[$name] = { "port": $port, "type": $type, "mcp_enabled": $mcp_enabled, "remote_control": $remote_control }' \
   "$_INSTANCES_FILE" > "${_INSTANCES_FILE}.tmp" \
   && mv "${_INSTANCES_FILE}.tmp" "$_INSTANCES_FILE"
```

### Remote control prompt in menu_action_new (lib/menu.sh)

```bash
# Prompt after container type selection
local rc_answer
read -rp "Enable remote control (requires claude.ai account, not API key)? (y/N) " rc_answer
local remote_control=false
if [[ "$rc_answer" == "y" || "$rc_answer" == "Y" ]]; then
    remote_control=true
fi
instances_set_remote_control "$name" "$remote_control"
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| SSE transport (deprecated) | HTTP streamable | MCP spec evolution 2025 | Docker MCP Gateway still uses SSE; use SSE for now, watch for gateway update |
| Claude Desktop MCP config | Claude Code MCP config via CLI | Claude Code MCP support | `claude mcp add` is the correct CLI, not Claude Desktop paths |
| `npm -g install @anthropic-ai/claude-code` | Native installer | Phase 2 decision | Already done; remote-control requires v2.1.51+ |

**Deprecated/outdated:**
- SSE transport: Deprecated in MCP spec but still the active transport for Docker MCP Gateway. Use it for now. When the gateway supports HTTP streamable, the config can be updated to `type: http`.
- `~/.claude.json` direct edits: Supported but not recommended. Use `claude mcp add-json` CLI.

---

## Open Questions

1. **Does `claude mcp add-json` support `--scope user` without any interactive prompt?**
   - What we know: Official docs show `--scope user` flag exists and `add-json` is designed for scripting
   - What's unclear: Whether first-run Claude Code initialization prompts are triggered by `mcp add-json` in a non-interactive shell
   - Recommendation: Test in the container during Wave 0. If it prompts, fall back to writing `~/.claude.json` directly via `jq` with a clear comment explaining why.

2. **Does the Docker MCP Gateway SSE endpoint respond to a plain curl GET for the probe?**
   - What we know: The endpoint is `/sse`, which is an SSE stream; a plain GET may return a 200 with an open stream or may not respond within the timeout
   - What's unclear: Whether `curl --max-time 2` to an SSE endpoint will get a valid response or hang
   - Recommendation: Use `curl --head` (HEAD request) or `curl --max-time 2 -o /dev/null -w "%{http_code}"` and accept any 2xx/4xx (not a network timeout) as "reachable".

3. **`docker mcp` CLI plugin detection on Linux**
   - What we know: The plugin installs to `~/.docker/cli-plugins/docker-mcp`
   - What's unclear: Whether to detect it by binary existence or `docker mcp --version` exit code
   - Recommendation: Use `docker mcp gateway --help &>/dev/null` as the detection check; if it succeeds, `docker mcp` plugin is available.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | BATS (Bash Automated Testing System) |
| Config file | `tests/test_helper.bash` (sets CSM_ROOT) |
| Quick run command | `bats tests/instances.bats tests/docker.bats tests/menu.bats` |
| Full suite command | `bats tests/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| MCP-01 | `docker_run_instance` adds `--add-host` on Linux Engine | unit | `bats tests/docker.bats` | ✅ (extend) |
| MCP-01 | `docker_run_instance` injects `CSM_MCP_ENABLED` and `CSM_MCP_PORT` env flags | unit | `bats tests/docker.bats` | ✅ (extend) |
| MCP-01 | `instances_add` writes `mcp_enabled: true` by default | unit | `bats tests/instances.bats` | ✅ (extend) |
| MCP-02 | README contains "Integrations" section with MCP and Remote Control subsections | manual | `grep -q "Integrations" README.md` | ❌ Wave 0 |
| MCP-03 | entrypoint.sh MCP config block is idempotent (no duplicate on re-run) | unit (entrypoint) | `bats tests/entrypoint.bats` | ❌ Wave 0 |
| INST-02 | `docker_run_instance` passes `CSM_REMOTE_CONTROL=1` when `remote_control: true` | unit | `bats tests/docker.bats` | ✅ (extend) |
| INST-02 | `instances_add` writes `remote_control: false` by default | unit | `bats tests/instances.bats` | ✅ (extend) |
| INST-02 | `menu_action_new` prompts for remote control and stores answer | unit | `bats tests/menu.bats` | ✅ (extend) |

### Sampling Rate
- **Per task commit:** `bats tests/instances.bats tests/docker.bats`
- **Per wave merge:** `bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/entrypoint.bats` — covers MCP-03 (idempotent config write) and INST-02 (remote control startup) — NOTE: entrypoint.sh runs as root inside Docker; unit tests will mock `su`, `curl`, `claude` commands
- [ ] README integration check can be validated manually: `grep -q "Integrations" README.md && echo "ok"`

---

## Sources

### Primary (HIGH confidence)
- [code.claude.com/docs/en/remote-control](https://code.claude.com/docs/en/remote-control) — remote-control command, flags, subscription requirement, URL format, `--name` flag, no-inbound-ports architecture
- [code.claude.com/docs/en/mcp](https://code.claude.com/docs/en/mcp) — `claude mcp add-json`, `--scope user`, `--transport sse`, JSON config format for `~/.claude.json`

### Secondary (MEDIUM confidence)
- [docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/](https://docs.docker.com/ai/mcp-catalog-and-toolkit/mcp-gateway/) — Gateway overview, Docker Desktop vs Engine distinction
- [github.com/docker/mcp-gateway](https://github.com/docker/mcp-gateway) — `docker mcp` CLI plugin, `docker mcp gateway run --transport sse --port 8811`
- [ajeetraina.com/running-docker-mcp-gateway-in-a-docker-container/](https://www.ajeetraina.com/running-docker-mcp-gateway-in-a-docker-container/) — Port 8811 default, Docker Compose example, endpoint URL format `http://gateway:8811/mcp`

### Tertiary (LOW confidence)
- Multiple WebSearch results confirming port 8811 as SSE default — cross-verified by two independent sources

---

## Metadata

**Confidence breakdown:**
- MCP Gateway port (8811): MEDIUM — confirmed by multiple secondary sources; no official Docker docs state it explicitly as "default"
- MCP config format (`claude mcp add-json`): HIGH — verified against official Claude Code docs
- `host.docker.internal` absence on Linux Engine: HIGH — well-documented Docker behavior
- Remote control subscription requirement: HIGH — explicitly stated in official docs
- `docker mcp` detection pattern: MEDIUM — derived from binary location convention, not official detection docs
- Entrypoint ordering: HIGH — follows existing established pattern from Phase 4

**Research date:** 2026-03-13
**Valid until:** 2026-04-13 (MCP Gateway is fast-moving; verify port and transport before implementation)
