# Phase 6: Settings + Documentation - Research

**Researched:** 2026-03-13
**Domain:** Bash config file management, interactive CLI menus, OSS documentation, security documentation
**Confidence:** HIGH

---

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions

**Config file design:**
- Separate `csm-config.json` in project root (not extending .env)
- .env stays for secrets only (ANTHROPIC_API_KEY, GITHUB_TOKEN)
- Config file stores all user preferences — clean separation
- Auto-created with sensible defaults on first `csm` start (like .env template)
- Gitignored alongside .env
- Config file is source of truth — old .env CSM_ vars ignored after migration
- CSM_AUTO_BACKUP migrates from .env to config file as `backup.auto_backup`
- CSM_MCP_PORT migrates from .env to config file as `integrations.mcp_port`

**Config file schema (exact):**
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

**Settings menu UX:**
- New [P] Preferences item in main menu (after [E] Restore, before [Q] Quit)
- Toggle-style inline interaction: each setting shows current value and toggles/cycles on selection
- Changes save immediately to csm-config.json (no confirm step)
- Basic validation on free-text inputs:
  - Port: must be a number 1024-65535
  - Memory: must match Docker format (e.g., 2g, 512m)
  - CPUs: must be a positive number
- [B] Back option returns to main menu

**Settings module:**
- New `lib/settings.sh` module (consistent with lib/backup.sh, lib/credentials.sh pattern)
- Handles config file read/write and settings menu rendering
- Menu dispatch in lib/menu.sh calls into settings.sh functions

**Instance name validation:**
- 4-10 characters, lowercase a-z, digits 0-9, and hyphens only
- Cannot start or end with a hyphen
- Clear error message on invalid input (replace silent sanitization in menu_action_new)

**README refresh:**
- Title: "Claude Sandbox Manager"
- Repo URL: github.com/Jacob101mcd/claude-sandbox-manager.git
- Badges at top: platform (Linux/macOS/Windows), license (Apache 2.0), Docker
- Section order: Badges → Description → Why I built this → Who is this for → Prerequisites → Quick Start (Linux/macOS + Windows subsections) → Multi-Instance Support → Configuration → Integrations → Security → What's Included → SSH Details → Notes
- Platform sections: Linux/macOS instructions first (bin/csm), Windows section second (claude-manager.bat)
- Brief Configuration section documenting [P] Preferences and available settings
- Container contents updated: native Claude Code installer, GitHub CLI, two variants (CLI + GUI with Xfce/noVNC/Chromium)
- Target length: ~250-350 lines

**License:**
- Apache 2.0 license
- Create LICENSE file in project root with standard Apache 2.0 text
- Referenced in README badge and Notes section

**Security documentation:**
- Separate SECURITY.md in project root for full risk analysis
- README gets brief Security section with emoji status indicator table + link to SECURITY.md
- Risk table format: Risk | Severity | Mitigation | Status
- Covers: container escape, credential exposure, network access, resource abuse, AI permissions (--dangerously-skip-permissions)
- Acknowledges --dangerously-skip-permissions trade-off: container isolation makes it acceptable
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

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

---

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SETT-01 | JSON config file in project root stores all user preferences | jq atomic write pattern from instances.sh; `credentials_ensure_env_file()` pattern for auto-creation |
| SETT-02 | CLI menu allows browsing and modifying settings interactively | Existing single-char dispatch in `menu_main()`; settings sub-menu extends same pattern |
| SETT-03 | Settings include: auto-backup toggle, default container type, default packages | Locked schema covers auto_backup, container_type; resource limits are in "defaults" group |
| SETT-04 | Sensible defaults work out of the box with zero configuration | Auto-create config file on startup with defaults; docker.sh reads from config with fallback |
| SEC-05 | Security risk analysis documented with mitigations | SECURITY.md with risk table (container escape, credential exposure, network, resource abuse, --dangerously-skip-permissions) |
| SEC-06 | Appropriate disclaimers added to README | README Security section with emoji table + link to SECURITY.md |
| DOC-01 | README includes "Why I built this" section | First-person narrative section in README |
| DOC-02 | README includes "Who is this for" section | Target audience section in README |
| DOC-03 | README includes security disclaimers and risk acknowledgments | Security section in README + SECURITY.md |
</phase_requirements>

---

## Summary

Phase 6 closes out the Claude Sandbox Manager v1 with three independent but related work streams: (1) a JSON config file and interactive settings menu, (2) a full README rewrite as a proper open-source project README, and (3) security documentation.

The technical work is almost entirely Bash with jq. Every pattern needed already exists in the codebase: `credentials_ensure_env_file()` for auto-creating files with defaults, atomic jq writes via tmp+mv from `instances.sh`, and the single-character dispatch loop from `menu_main()`. The settings module (`lib/settings.sh`) follows the exact same structure as all other lib modules. Integration points are surgical: three callers in `docker.sh` and `credentials.sh` need to read from the config file instead of hardcoded values or env vars.

The documentation work is authoring, not code: README rewrite (~250-350 lines), SECURITY.md (risk table + mitigations), and LICENSE file (Apache 2.0 standard text). The README completely replaces the current Windows-only document; the current ~180-line README is outdated and Windows-centric.

**Primary recommendation:** Implement in three clean tasks — (1) `lib/settings.sh` + config integration across callers, (2) README rewrite + LICENSE, (3) SECURITY.md. All three are independent and can be planned as separate waves or sequential tasks.

---

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jq | >=1.6 (already installed) | JSON read/write for config file | Already used throughout codebase for `.instances.json` |
| bash | >=4.0 | Settings module, menu extension | Entire codebase is Bash |
| BATS | local install (already present) | Test framework | Already in use for all other modules |

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| ShellCheck | local install (already present) | Linting new settings.sh | Applied to all lib/*.sh files |

### No New Dependencies
This phase introduces zero new runtime dependencies. All tooling is already in the project.

**Installation:**
```bash
# Nothing to install — all dependencies already present
```

---

## Architecture Patterns

### Settings Module Structure

Follow the exact pattern of `lib/backup.sh` and `lib/credentials.sh`:

```
lib/settings.sh
  settings_ensure_config_file()   -- auto-create with defaults (mirrors credentials_ensure_env_file)
  settings_load()                  -- read config into global vars (mirrors credentials_load)
  settings_get()                   -- read a single dotted-path value from config
  settings_set()                   -- write a single value, atomic via tmp+mv
  settings_menu()                  -- interactive preferences sub-menu (called from menu.sh)
```

### Config File Auto-Creation Pattern

Follow `credentials_ensure_env_file()` exactly:

```bash
# Source: lib/credentials.sh (existing pattern)
settings_ensure_config_file() {
    local config_file="${CSM_ROOT}/csm-config.json"
    if [[ -f "$config_file" ]]; then return 0; fi

    cat > "$config_file" <<'JSON'
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
JSON
    msg_warn "Created csm-config.json with defaults at ${config_file}"
}
```

### Atomic JSON Write Pattern

Follow `instances.sh` exactly — never write directly, always use tmp+mv:

```bash
# Source: lib/instances.sh (existing pattern)
settings_set() {
    local key="$1"   # jq path like .backup.auto_backup
    local value="$2" # raw jq value (use --argjson for booleans/numbers, --arg for strings)
    local config_file="${CSM_ROOT}/csm-config.json"

    jq "${key} = ${value}" "$config_file" \
        > "${config_file}.tmp" \
        && mv "${config_file}.tmp" "$config_file"
}
```

**Critical:** Use `--argjson` for boolean and numeric values to preserve JSON types; use `--arg` for strings. The existing codebase already handles this correctly in `instances.sh` — the same discipline applies here.

### Boolean Field Detection Pattern

The existing codebase uses `has()` (not `//`) to detect boolean fields, because `// default` treats `false` as absent. Follow this:

```bash
# Source: lib/instances.sh (Phase 05 decision)
# WRONG: .backup.auto_backup // false   -- treats false as absent!
# RIGHT: use has() for boolean fields
jq 'if has("backup") and (.backup | has("auto_backup")) then .backup.auto_backup else false end'
```

### Settings Menu Pattern

The settings menu is a sub-loop within the existing `menu_main()` dispatch. It follows the same single-character dispatch style:

```bash
# Pattern mirrors menu_main() in lib/menu.sh
settings_menu() {
    while true; do
        _settings_show_preferences_menu
        local choice
        read -rp $'\nPreference: ' choice
        case "${choice,,}" in
            1) _settings_toggle_auto_backup ;;
            2) _settings_cycle_container_type ;;
            3) _settings_set_memory_limit ;;
            4) _settings_set_cpu_limit ;;
            5) _settings_set_mcp_port ;;
            b) return 0 ;;
            *) msg_error "Invalid choice." ;;
        esac
    done
}
```

The menu shows current values inline — each line displays the setting name and its current value before the user selects it.

### Integration Points (Surgical Changes)

**docker.sh** — replace two hardcoded values:
```bash
# BEFORE (lib/docker.sh lines 81-82):
cmd+=(--memory=2g)
cmd+=(--cpus=2)

# AFTER:
local mem_limit cpu_limit
mem_limit="$(settings_get .defaults.memory_limit)"
cpu_limit="$(settings_get .defaults.cpu_limit)"
cmd+=(--memory="${mem_limit:-2g}")
cmd+=(--cpus="${cpu_limit:-2}")
```

**docker.sh** — replace CSM_AUTO_BACKUP env var read (line 166):
```bash
# BEFORE:
if [[ "${CSM_AUTO_BACKUP:-}" == "1" ]]; then

# AFTER:
if [[ "$(settings_get_bool .backup.auto_backup)" == "true" ]]; then
```

**credentials.sh** — replace CSM_MCP_PORT env var (line 106):
```bash
# BEFORE:
CSM_DOCKER_ENV_FLAGS+=("-e" "CSM_MCP_PORT=${CSM_MCP_PORT:-8811}")

# AFTER:
local mcp_port
mcp_port="$(settings_get .integrations.mcp_port)"
CSM_DOCKER_ENV_FLAGS+=("-e" "CSM_MCP_PORT=${mcp_port:-8811}")
```

**bin/csm** — source settings.sh and call ensure on startup:
```bash
# Add after existing source lines:
source "$CSM_ROOT/lib/settings.sh"   # Add before credentials.sh
# Add in startup checks block:
settings_ensure_config_file
```

**lib/menu.sh** — two changes:
1. Add `[P] Preferences` between `[E]` and `[Q]` in `menu_show_actions()`
2. Add `p) settings_menu ;;` in the dispatch case

### Instance Name Validation

Replace silent sanitization in `menu_action_new()` (line 187-188 of menu.sh):

```bash
# BEFORE (silent sanitization):
name="$(echo "$input" | tr -cd 'a-z0-9-')"

# AFTER (strict validation with clear error):
# Rule: 4-10 chars, lowercase a-z/0-9/hyphen, no leading/trailing hyphen
if ! [[ "$input" =~ ^[a-z0-9][a-z0-9-]{2,8}[a-z0-9]$ ]]; then
    msg_error "Invalid name. Use 4-10 characters: lowercase letters, digits, hyphens. Cannot start or end with a hyphen."
    return
fi
name="$input"
```

**Regex explanation:** `^[a-z0-9]` (first char, no hyphen) + `[a-z0-9-]{2,8}` (2-8 middle chars) + `[a-z0-9]$` (last char, no hyphen) = 4-10 chars total, no leading/trailing hyphen.

Note: Single-character names like "x" won't match (too short). The minimum 4-character constraint is intentional per the locked decision.

### Module Source Order

`lib/settings.sh` must be sourced early because `credentials.sh` and `docker.sh` depend on config values. Source order in `bin/csm`:

```bash
source "$CSM_ROOT/lib/common.sh"
source "$CSM_ROOT/lib/settings.sh"    # NEW: before credentials.sh
source "$CSM_ROOT/lib/credentials.sh"
source "$CSM_ROOT/lib/platform.sh"
source "$CSM_ROOT/lib/instances.sh"
source "$CSM_ROOT/lib/ssh.sh"
source "$CSM_ROOT/lib/docker.sh"
source "$CSM_ROOT/lib/backup.sh"
source "$CSM_ROOT/lib/menu.sh"
```

### Recommended Project Structure (additions only)

```
project-root/
├── lib/
│   └── settings.sh          # NEW: config file management + preferences menu
├── csm-config.json          # NEW: auto-created, gitignored
├── LICENSE                  # NEW: Apache 2.0
├── SECURITY.md              # NEW: full security risk analysis
└── README.md                # REWRITE: cross-platform, narrative, current
```

### Anti-Patterns to Avoid

- **Direct JSON file write (no tmp+mv):** Crash during write = corrupt config. Always use tmp+mv atomic pattern.
- **Reading boolean with `//` fallback:** `false // default_value` treats `false` as absent. Use `has()` for boolean field checks (established project decision from Phase 5).
- **Sourcing settings.sh after credentials.sh:** credentials.sh reads MCP port from config; settings.sh must be sourced first.
- **Hardcoding config file path inside functions:** Use `${CSM_ROOT}/csm-config.json` consistently (not a relative path).
- **Not stripping module guard:** Every lib/*.sh must begin with `[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set." >&2; exit 1; }`.

---

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| JSON read/write | Custom parser | jq (already installed) | Handles escaping, nesting, type safety |
| Atomic file writes | Direct redirect | tmp file + mv (established project pattern) | Prevents corrupt config on crash |
| Apache 2.0 license text | Custom text | Official OSI-approved text verbatim | Legal accuracy; badge verifiers expect standard text |
| shields.io badge URLs | Custom badge service | shields.io static badges | Industry standard, zero infrastructure |

**Key insight:** The JSON config file complexity is entirely handled by jq. The only custom code needed is the Bash wrapper functions that call jq with the right arguments.

---

## Common Pitfalls

### Pitfall 1: Boolean JSON Values Lose Type
**What goes wrong:** Writing `auto_backup="false"` as a string with `--arg` makes it `"false"` (string) not `false` (boolean) in JSON. Readers using `jq '.backup.auto_backup == true'` will fail.
**Why it happens:** Bash has no native boolean type; everything is a string unless jq knows otherwise.
**How to avoid:** Use `--argjson val "$bool_val"` (not `--arg`) when writing booleans. Use `--argjson` for numbers too. The existing `instances.sh` already does this correctly.
**Warning signs:** `jq '.backup.auto_backup'` returns `"false"` with quotes instead of `false` without.

### Pitfall 2: Config File Missing on New Installs Breaks Callers
**What goes wrong:** `settings_get()` is called during `docker_start_instance()` before `settings_ensure_config_file()` has run, returning empty/null.
**Why it happens:** If `settings_ensure_config_file()` is not the first thing called in `bin/csm` startup, callers may hit missing file.
**How to avoid:** Call `settings_ensure_config_file()` in the startup block of `bin/csm` before `menu_main()`, immediately after sourcing. Docker run fallbacks (`${mem_limit:-2g}`) provide a safety net but should not be relied upon.
**Warning signs:** Containers start with empty `--memory=` flags causing docker run errors.

### Pitfall 3: Auto-Backup Migration From .env
**What goes wrong:** Existing users have `CSM_AUTO_BACKUP=1` in their `.env`. After migration, config file defaults to `auto_backup: false`. Auto-backup silently stops working.
**Why it happens:** Config file becomes source of truth; old env var is ignored.
**How to avoid:** During `settings_ensure_config_file()`, detect if `CSM_AUTO_BACKUP` is present in `.env` and migrate its value into the new config file. Log a `msg_warn` telling the user about the migration.
**Warning signs:** User reports auto-backup stopped working after upgrade.

### Pitfall 4: Instance Name Regex Edge Cases
**What goes wrong:** The regex `^[a-z0-9][a-z0-9-]{2,8}[a-z0-9]$` requires exactly 4+ chars (1 + 2-8 + 1). A 3-char name like "foo" fails (middle group needs 2). A 2-char name like "ab" fails. This is intentional per the locked decision but must be communicated clearly.
**Why it happens:** Middle group `{2,8}` enforces minimum total length of 4.
**How to avoid:** Error message should be explicit: "Instance name must be 4-10 characters."
**Warning signs:** Users confused why 3-character names are rejected.

### Pitfall 5: README Outdated Windows References
**What goes wrong:** The current README is Windows-centric (claude-manager.bat, PowerShell). Full rewrite must not carry forward Windows-primary framing — Linux/macOS comes first.
**Why it happens:** Original project was Windows-only; README was never updated for cross-platform.
**How to avoid:** Write README sections in order: Linux/macOS primary, Windows secondary. bin/csm is the primary entry point; claude-manager.bat is the Windows alternative.

### Pitfall 6: Memory Format Validation Complexity
**What goes wrong:** Docker memory format allows `512m`, `2g`, `1024k`, `1073741824` (bytes). A naive regex that only allows `Ng` format will reject valid inputs.
**Why it happens:** Docker accepts multiple formats.
**How to avoid:** Validate with `^[0-9]+[mgkMGK]?$` — matches number + optional unit suffix. Keep it permissive; Docker itself will validate further.

---

## Code Examples

### settings_get with jq nested path
```bash
# Read a value from config, with fallback
settings_get() {
    local jq_path="$1"
    local config_file="${CSM_ROOT}/csm-config.json"
    jq -r "${jq_path} // empty" "$config_file" 2>/dev/null
}

# Usage:
mem="$(settings_get '.defaults.memory_limit')"  # returns "2g"
port="$(settings_get '.integrations.mcp_port')" # returns "8811"
```

### Boolean toggle pattern
```bash
# Toggle a boolean setting
_settings_toggle_auto_backup() {
    local config_file="${CSM_ROOT}/csm-config.json"
    local current
    current="$(jq -r 'if (.backup | has("auto_backup")) then .backup.auto_backup else false end' "$config_file")"

    local new_val
    if [[ "$current" == "true" ]]; then new_val="false"; else new_val="true"; fi

    jq --argjson val "$new_val" '.backup.auto_backup = $val' \
        "$config_file" > "${config_file}.tmp" \
        && mv "${config_file}.tmp" "$config_file"

    msg_ok "Auto-backup: ${new_val}"
}
```

### Port validation regex
```bash
# Validate port is in range 1024-65535
_settings_validate_port() {
    local val="$1"
    if ! [[ "$val" =~ ^[0-9]+$ ]] || (( val < 1024 || val > 65535 )); then
        msg_error "Port must be a number between 1024 and 65535."
        return 1
    fi
    return 0
}
```

### shields.io static badge pattern
```markdown
![Platform](https://img.shields.io/badge/platform-Linux%20%7C%20macOS%20%7C%20Windows-blue)
![License](https://img.shields.io/badge/license-Apache%202.0-green)
![Docker](https://img.shields.io/badge/requires-Docker-2496ED?logo=docker&logoColor=white)
```

### Apache 2.0 LICENSE file header (first 15 lines)
```
                                 Apache License
                           Version 2.0, January 2004
                        http://www.apache.org/licenses/

   TERMS AND CONDITIONS FOR USE, REPRODUCTION, AND DISTRIBUTION
   ...
```
Full text: https://www.apache.org/licenses/LICENSE-2.0.txt — copy verbatim, do not summarize.

### SECURITY.md risk table structure
```markdown
## Risk Summary

| Risk | Severity | Mitigation | Status |
|------|----------|------------|--------|
| Container escape | Low | Dropped capabilities, no-new-privileges, resource limits | 🟢 Hardened |
| Credential exposure | Medium | .env gitignored, runtime injection only, never baked into images | 🟢 Hardened |
| Network access from container | Medium | Containers have outbound internet access (intentional for Claude Code) | 🟡 User responsibility |
| Resource abuse | Low | Memory (2g) and CPU (2) limits enforced | 🟢 Hardened |
| AI agent permissions (--dangerously-skip-permissions) | Medium | Container isolation is what makes this trade-off acceptable | 🟡 User responsibility |
```

---

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| CSM_AUTO_BACKUP in .env | `backup.auto_backup` in csm-config.json | Phase 6 | Clean separation of secrets vs preferences |
| CSM_MCP_PORT in .env | `integrations.mcp_port` in csm-config.json | Phase 6 | Config file is single source of truth for preferences |
| Hardcoded `--memory=2g --cpus=2` | Read from `defaults.memory_limit` / `defaults.cpu_limit` | Phase 6 | User-configurable without editing scripts |
| Silent name sanitization | Explicit validation with error message | Phase 6 | Clearer UX, enforces naming rules |

---

## Open Questions

1. **Migration: detect old CSM_ vars in .env**
   - What we know: `settings_ensure_config_file()` runs on first startup with new code
   - What's unclear: Should migration be automatic (silently move values) or prompt user?
   - Recommendation: Automatic silent migration with a single `msg_warn` notification — don't break existing users, and don't require interaction. Read `.env`, if `CSM_AUTO_BACKUP=1` detected, write `true` to `backup.auto_backup` in new config. Same for `CSM_MCP_PORT`. This is Claude's discretion per CONTEXT.md.

2. **Container type cycling: what is the cycle order?**
   - What we know: default container type is "cli", options are "cli" and "gui"
   - What's unclear: Toggle between two options (cli → gui → cli) or show a numbered sub-menu?
   - Recommendation: Toggle (two-value cycle) — consistent with "toggle-style inline interaction" locked decision.

3. **backup_restore in backup.sh uses hardcoded resource limits**
   - What we know: `backup_restore()` duplicates docker run flags including `--memory=2g --cpus=2` (with a "keep in sync" comment)
   - What's unclear: Should backup_restore also read from config file?
   - Recommendation: Yes — update `backup_restore()` to read from config just like `docker_run_instance()`. This is in scope since Phase 6 introduces config-driven resource limits. Planner should include this as part of the docker.sh integration task.

---

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | BATS (Bash Automated Testing System) |
| Config file | none — test files use `load test_helper` convention |
| Quick run command | `~/.local/bin/bats tests/settings.bats` |
| Full suite command | `~/.local/bin/bats tests/` |

### Phase Requirements → Test Map

| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETT-01 | `settings_ensure_config_file` creates csm-config.json with correct defaults | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-01 | `settings_ensure_config_file` is idempotent (existing file not overwritten) | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-01 | `settings_get` returns correct value for each config key | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-01 | `settings_set` writes value atomically and preserves other keys | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-02 | settings_menu shows [P] option in output | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-02 | menu_show_actions output includes [P] Preferences | unit | `~/.local/bin/bats tests/menu.bats` | ❌ (add to existing) |
| SETT-03 | config file contains auto_backup, container_type, memory_limit, cpu_limit, mcp_port | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-04 | New install with no csm-config.json creates defaults on startup | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SEC-05 | SECURITY.md file exists in project root | smoke | `test -f SECURITY.md` | ❌ Wave 0 |
| SEC-06 | README.md contains "Security" section | smoke | `grep -q "## Security" README.md` | ❌ Wave 0 |
| DOC-01 | README.md contains "Why I built this" section | smoke | `grep -q "Why I built this" README.md` | ❌ Wave 0 |
| DOC-02 | README.md contains "Who is this for" section | smoke | `grep -q "Who is this for" README.md` | ❌ Wave 0 |
| DOC-03 | README.md contains security disclaimer text | smoke | `grep -qi "dangerously" README.md` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `~/.local/bin/bats tests/settings.bats`
- **Per wave merge:** `~/.local/bin/bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] `tests/settings.bats` — covers SETT-01 through SETT-04
- [ ] Add `[P] Preferences` test to existing `tests/menu.bats`
- [ ] No new framework install needed — BATS already at `~/.local/bin/bats`

---

## Sources

### Primary (HIGH confidence)
- Direct codebase read: `lib/menu.sh`, `lib/credentials.sh`, `lib/instances.sh`, `lib/docker.sh`, `lib/backup.sh`, `lib/common.sh`, `bin/csm` — all patterns referenced are verified from actual code
- Direct codebase read: `tests/test_helper.bash`, `tests/menu.bats`, `tests/instances.bats` — BATS test structure verified
- `.planning/phases/06-settings-documentation/06-CONTEXT.md` — all locked decisions copied verbatim
- `.planning/config.json` — nyquist_validation: true confirmed

### Secondary (MEDIUM confidence)
- shields.io static badge URL format — standard public documentation, widely used
- Apache 2.0 license text — official OSI/Apache text at apache.org/licenses/LICENSE-2.0.txt

### Tertiary (LOW confidence)
- Docker memory format regex (`^[0-9]+[mgkMGK]?$`) — derived from Docker documentation knowledge; verify against `docker run --help` if needed

---

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — all tools are already present in the codebase
- Architecture patterns: HIGH — all patterns directly verified from existing code
- Pitfalls: HIGH — most derived from existing code inspection and established project decisions
- Test mapping: HIGH — BATS structure verified from existing test files

**Research date:** 2026-03-13
**Valid until:** 2026-06-13 (stable Bash/jq stack; no fast-moving dependencies)
