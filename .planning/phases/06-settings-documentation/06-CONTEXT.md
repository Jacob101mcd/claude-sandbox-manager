# Phase 6: Settings + Documentation - Context

**Gathered:** 2026-03-13
**Status:** Ready for planning

<domain>
## Phase Boundary

Interactive settings CLI menu, JSON config file, full README refresh (cross-platform, narrative sections, updated content), security risk analysis document, LICENSE file, and input validation improvements — completing the user-facing product. No new container features or manager capabilities.

</domain>

<decisions>
## Implementation Decisions

### Config file design
- Separate `csm-config.json` in project root (not extending .env)
- .env stays for secrets only (ANTHROPIC_API_KEY, GITHUB_TOKEN)
- Config file stores all user preferences — clean separation
- Auto-created with sensible defaults on first `csm` start (like .env template)
- Gitignored alongside .env
- Config file is source of truth — old .env CSM_ vars ignored after migration
- CSM_AUTO_BACKUP migrates from .env to config file as `backup.auto_backup`
- CSM_MCP_PORT migrates from .env to config file as `integrations.mcp_port`

### Config file schema
- Grouped by category with nested objects:
```json
{
  "defaults": {
    "container_type": "cli",
    "memory_limit": "2g",
    "cpu_limit": 2
  },
  "backup": {
    "auto_backup": false
  },
  "integrations": {
    "mcp_port": 8811
  }
}
```
- Resource limits (memory, CPU) are configurable — currently hardcoded in docker.sh
- Resource limit changes apply globally to all instances on next start

### Settings menu UX
- New [P] Preferences item in main menu (after [E] Restore, before [Q] Quit)
- Toggle-style inline interaction: each setting shows current value and toggles/cycles on selection
- Changes save immediately to csm-config.json (no confirm step)
- Basic validation on free-text inputs:
  - Port: must be a number 1024-65535
  - Memory: must match Docker format (e.g., 2g, 512m)
  - CPUs: must be a positive number
- [B] Back option returns to main menu

### Settings module
- New `lib/settings.sh` module (consistent with lib/backup.sh, lib/credentials.sh pattern)
- Handles config file read/write and settings menu rendering
- Menu dispatch in lib/menu.sh calls into settings.sh functions

### Instance name validation
- 4-10 characters, lowercase a-z, digits 0-9, and hyphens only
- Cannot start or end with a hyphen
- Clear error message on invalid input (replace silent sanitization in menu_action_new)

### README refresh
- Title: "Claude Sandbox Manager" (matches new repo name)
- Repo URL: github.com/Jacob101mcd/claude-sandbox-manager.git
- Badges at top: platform (Linux/macOS/Windows), license (Apache 2.0), Docker
- Section order: Badges → Description → Why I built this → Who is this for → Prerequisites → Quick Start (Linux/macOS + Windows subsections) → Multi-Instance Support → Configuration → Integrations → Security → What's Included → SSH Details → Notes
- "Why I built this": first-person, personal + practical tone, safety + productivity motivation ("wanted to let Claude Code loose without worrying about my machine")
- "Who is this for": developers exploring AI coding, people cautious about running agents on their machine, teams wanting reproducible environments
- Platform sections: Linux/macOS instructions first (bin/csm), Windows section second (claude-manager.bat)
- Brief Configuration section documenting [P] Preferences and available settings
- Container contents updated to reflect: native Claude Code installer, GitHub CLI, two variants (CLI + GUI with Xfce/noVNC/Chromium)
- Target length: ~250-350 lines (moderate expansion from current ~180)

### License
- Apache 2.0 license
- Create LICENSE file in project root with standard Apache 2.0 text
- Referenced in README badge and Notes section

### Security documentation
- Separate SECURITY.md in project root for full risk analysis
- README gets brief Security section with emoji status indicator table + link to SECURITY.md
- Risk table format: Risk | Severity | Mitigation | Status
- Covers: container escape, credential exposure, network access, resource abuse, AI permissions (--dangerously-skip-permissions)
- Acknowledges --dangerously-skip-permissions trade-off: container isolation is what makes it acceptable
- Brief mention of Docker Desktop (VM isolation) vs Docker Engine (host kernel) security difference
- Hardening tips section: rotate API keys, review logs, keep Docker updated
- Honest + practical tone — not alarmist, not dismissive
- No responsible disclosure section (GitHub issues sufficient)
- README security summary uses emoji risk indicators (🟢 Hardened, 🟡 User responsibility)

### Claude's Discretion
- Exact badge styling and shields.io URLs
- "Why I built this" and "Who is this for" exact wording
- SECURITY.md risk table completeness (additional risks beyond the ones discussed)
- Hardening tips selection and wording
- Settings menu exact rendering (spacing, colors, checkmark display)
- Config file migration logic (how to handle users with old CSM_ vars in .env)
- Instance name validation error message wording

</decisions>

<specifics>
## Specific Ideas

- Settings menu should feel consistent with the existing interactive menu — same single-character dispatch, same visual style
- README should be a proper open-source project README now — badges, narrative, cross-platform docs
- Security documentation should be transparent: "here's what we do, here's what we don't do, here's what's your responsibility"
- Config file groups settings by category for readability, matching how the settings menu presents them

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `lib/credentials.sh`: .env parsing pattern — config file reading can follow similar structure but using jq for JSON
- `lib/menu.sh`: `menu_show_actions()` and single-char dispatch in `menu_main()` — extend with [P] action
- `lib/menu.sh`: `menu_action_new()` — update with proper name validation (currently silently sanitizes)
- `lib/common.sh`: `msg_info`, `msg_ok`, `msg_warn`, `msg_error` — reuse for settings feedback
- `lib/docker.sh`: Hardcoded `--memory=2g` and `--cpus=2` — replace with config file values

### Established Patterns
- Atomic jq writes via tmp file + mv (instances.sh) — use same pattern for config file writes
- Module guard: `[[ -n "${CSM_ROOT:-}" ]]` at top of each lib/*.sh
- Color output auto-disabled when stdout is not a terminal
- `credentials_ensure_env_file()` pattern for auto-creating template files — reuse for config file

### Integration Points
- `lib/menu.sh`: Add [P] to `menu_show_actions()` and dispatch in `menu_main()`
- `lib/docker.sh`: `docker_run_instance()` reads resource limits from config instead of hardcoded values
- `lib/docker.sh`: `docker_start_instance()` reads auto_backup from config instead of CSM_AUTO_BACKUP env var
- `lib/credentials.sh`: `credentials_get_docker_env_flags()` reads MCP port from config instead of CSM_MCP_PORT env var
- `bin/csm`: Source lib/settings.sh, call settings_ensure_config_file() during startup
- `README.md`: Full rewrite
- `SECURITY.md`: New file
- `LICENSE`: New file

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 06-settings-documentation*
*Context gathered: 2026-03-13*
