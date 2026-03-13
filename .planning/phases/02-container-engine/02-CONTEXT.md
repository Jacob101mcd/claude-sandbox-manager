# Phase 2: Container Engine - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

End-to-end container lifecycle (create/start/stop/SSH/remove) on Linux and macOS with minimal CLI container variant. ANTHROPIC_API_KEY and GitHub credentials automatically available inside containers via runtime injection. Claude Code installed via native installer (not NPM). The manager itself remains CLI-only — "GUI variant" (Phase 4) refers to a container type with a desktop environment, not a GUI for the manager.

</domain>

<decisions>
## Implementation Decisions

### Credential storage
- All credentials stored in `.env` file in project root (standard KEY=value format)
- `.env` file must be .gitignored
- Single file for all credentials: ANTHROPIC_API_KEY, GITHUB_TOKEN, and any future keys

### Credential injection
- Credentials injected into containers via `docker run -e` flags at runtime
- Never baked into Docker image layers (CRED-04)
- If ANTHROPIC_API_KEY is missing from .env: warn but continue (container starts, Claude Code won't work)
- If GITHUB_TOKEN is missing from .env: warn but continue (gh CLI won't authenticate)

### Claude Code installation
- Native installer via `curl | sh` during docker build (baked into image)
- Always install latest version — no version pinning
- Run installer as claude user inside Dockerfile
- Node.js/NPM kept in image (needed for GSD framework and development tasks)

### GitHub CLI
- gh CLI installed during docker build via GitHub's official apt repo
- Authentication via GITHUB_TOKEN environment variable (gh CLI reads it natively — no explicit auth step needed)
- No gh auth setup-git or additional configuration required

### Container type selection
- Interactive numbered menu when creating new instance: [1] Minimal CLI, [2] GUI Desktop (Phase 4)
- Menu shown even when only one type is available (Phase 2 has only CLI)
- Container type stored in .instances.json per instance: `{ port: 2222, type: "cli" }`
- Instance list in main menu shows type next to name and status

### Claude's Discretion
- Exact .env parsing implementation in Bash
- Dockerfile layer ordering and optimization
- Error message wording for missing credentials
- How to handle .env file creation (auto-create template vs manual)
- Native installer URL and invocation details

</decisions>

<specifics>
## Specific Ideas

- Credential pattern should be consistent: same .env file, same warn-and-continue behavior for all optional credentials
- The manager is always CLI-only — no GUI for the manager itself, ever
- Container type menu should feel consistent with the existing interactive menu from Phase 1

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/docker.sh`: `docker_run_instance()` already has security flags array — extend with `-e` flags for credentials
- `lib/instances.sh`: `instances_add()` stores `{ port }` — extend to include `type` field
- `lib/menu.sh`: Interactive menu pattern (single-character dispatch) — reuse for container type selection
- `lib/common.sh`: Shared utilities (msg_info, msg_ok, die) for consistent UX

### Established Patterns
- Atomic jq writes via tmp file + mv (instances.sh) — use same pattern for registry changes
- Docker run command built as Bash array for safe argument handling
- Build staging dir cleaned and recreated each build for deterministic state
- Color output auto-disabled when stdout is not a terminal

### Integration Points
- `scripts/Dockerfile`: Needs modification — replace NPM install with native installer, add gh CLI
- `docker_run_instance()`: Add -e flags for credential injection from .env
- `instances_add()`: Extend JSON schema to include container type
- `menu.sh`: Add container type selection sub-menu to creation flow

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 02-container-engine*
*Context gathered: 2026-03-13*
