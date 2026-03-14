# Phase 8: Wire Default Container Type - Research

**Researched:** 2026-03-14
**Domain:** Bash shell scripting — settings integration, menu flow control, jq null handling
**Confidence:** HIGH

<user_constraints>
## User Constraints (from CONTEXT.md)

### Locked Decisions
- When `defaults.container_type` is explicitly set (non-null), skip the container type prompt entirely
- Show plain text message: `→ Using default: GUI Desktop` (or Minimal CLI) with hint `Change in [P] Preferences`
- When `defaults.container_type` is null (factory default), show the full selection prompt as today
- Restore flow is NOT affected — restore always uses the backed-up container type regardless of preference
- Factory default for `defaults.container_type` changes from `"cli"` to `null`
- Null means "not explicitly set by user" — triggers the interactive prompt
- Once user sets a preference via [P] Preferences, it becomes `"cli"` or `"gui"` and auto-skips from then on
- Cycle: null → cli → gui → cli (no way back to null once set)
- Display when null: `Container Type: Ask each time`
- Display when set: `Container Type: Minimal CLI` or `Container Type: GUI Desktop`
- Auto-skip uses plain text with arrow (no msg_info/msg_ok color function)
- "Not set" state displayed as "Ask each time" in preferences menu

### Claude's Discretion
- Exact implementation of null detection in settings_get (jq null handling)
- Whether to update settings_ensure_config_file to use null or omit the key entirely
- Test structure and assertions

### Deferred Ideas (OUT OF SCOPE)
None — discussion stayed within phase scope
</user_constraints>

<phase_requirements>
## Phase Requirements

| ID | Description | Research Support |
|----|-------------|-----------------|
| SETT-01 | JSON config file in project root stores all user preferences | `csm-config.json` already exists; this phase changes the `defaults.container_type` field's default value from `"cli"` to JSON `null` |
| SETT-04 | Sensible defaults work out of the box with zero configuration | Null factory default means first-run shows the interactive prompt (sensible behavior) — user is never silently locked into a type they didn't choose |
</phase_requirements>

## Summary

Phase 8 is a focused wiring phase: three functions need modification and one factory default value changes. The entire change surface is `lib/settings.sh` (functions: `settings_ensure_config_file`, `_settings_cycle_container_type`, `_settings_show_preferences_menu`) and `lib/menu.sh` (function: `menu_select_container_type`). No new libraries are needed — this is pure Bash and jq work.

The critical technical concern is jq null handling. The existing `settings_get` uses `jq -r "${jq_path} // empty"` which will output an empty string for both a missing key AND a JSON null value — this is exactly the right behavior for null detection. When `container_type` is `null` in JSON, `settings_get '.defaults.container_type'` already returns `""`, so the null check in `menu_select_container_type` is simply `[[ -z "$container_type" ]]`.

The test suite is BATS-based and fully green at baseline. Existing tests include one that asserts `container_type` defaults to `"cli"` — that test must be updated to assert `null` (JSON) / empty string (settings_get output) as part of this phase.

**Primary recommendation:** Change the factory default in `settings_ensure_config_file` to emit `null` via `jq -n '{defaults: {container_type: null, ...}}'` (no `--arg ctype` needed), update `_settings_cycle_container_type` to handle null → cli transition, update `_settings_show_preferences_menu` display label, and gate `menu_select_container_type` on an emptiness check.

## Standard Stack

### Core
| Library | Version | Purpose | Why Standard |
|---------|---------|---------|--------------|
| jq | ~1.6 (installed at `~/.local/bin/jq`) | JSON read/write for config | Already the entire config layer; atomic writes via tmp+mv already established |
| BATS | installed at `~/.local/bin/bats` | Shell unit testing | Already the test framework for all 9 test files in `tests/` |

No new dependencies. This phase introduces no new tools.

### Supporting
| Library | Version | Purpose | When to Use |
|---------|---------|---------|-------------|
| bash string ops | built-in | Null/empty detection via `[[ -z "$var" ]]` | Checking settings_get return value for null state |

### Alternatives Considered
| Instead of | Could Use | Tradeoff |
|------------|-----------|----------|
| `jq -r 'path // empty'` returning `""` for null | Separate `settings_get_null` function | Not needed — existing behavior already maps null→empty string correctly |
| `null` in JSON | Omit the key entirely | Both work with `// empty`; null is more explicit about "intentionally unset" |

**Installation:**
No new packages needed.

## Architecture Patterns

### Files Modified
```
lib/
├── settings.sh    # settings_ensure_config_file, _settings_cycle_container_type,
│                  # _settings_show_preferences_menu
└── menu.sh        # menu_select_container_type

tests/
├── settings.bats  # Update: "sets default container_type to cli" → null
│                  # Add: cycle null→cli→gui→cli tests
│                  # Add: display "Ask each time" when null
└── menu.bats      # Add: auto-skip tests (with settings_get mock via config file)
```

### Pattern 1: jq Null Factory Default
**What:** Emit JSON null (not the string "null") using `jq -n` without `--arg`
**When to use:** When you want a field to be JSON null in the output

```bash
# Source: verified against jq manual — jq null literal
jq -n \
    --arg mem "2g" \
    --argjson cpu 2 \
    --argjson ab "false" \
    --argjson port 8811 \
    '{
      defaults: {
        container_type: null,   # literal null, no --arg needed
        memory_limit: $mem,
        cpu_limit: $cpu
      },
      backup: { auto_backup: $ab },
      integrations: { mcp_port: $port }
    }'
```

### Pattern 2: Null Detection via settings_get
**What:** `settings_get` uses `jq -r "${jq_path} // empty"` — this already returns `""` for both missing keys and JSON null values
**When to use:** Checking whether user has set a preference

```bash
# In menu_select_container_type (menu.sh):
local default_type
default_type="$(settings_get '.defaults.container_type')"

if [[ -n "$default_type" ]]; then
    # User has set a preference — auto-skip
    local label
    if [[ "$default_type" == "gui" ]]; then label="GUI Desktop"; else label="Minimal CLI"; fi
    echo "→ Using default: ${label}"
    echo "  Change in [P] Preferences"
    echo "$default_type"
    return
fi

# Null/unset — show interactive prompt (existing code unchanged below)
```

### Pattern 3: Null-Aware Cycle in _settings_cycle_container_type
**What:** Three-state cycle: null → cli → gui → cli
**When to use:** User presses [2] in settings menu

```bash
_settings_cycle_container_type() {
    local current
    current="$(settings_get '.defaults.container_type')"

    local new_val
    case "$current" in
        "cli") new_val="gui" ;;
        "gui") new_val="cli" ;;
        *)     new_val="cli" ;;   # null/"" → cli (first explicit set)
    esac

    settings_set '.defaults.container_type' "$new_val" 'string'
    msg_ok "Default container type: ${new_val}"
}
```

### Pattern 4: Display Label in _settings_show_preferences_menu
**What:** Map null/empty → "Ask each time", "cli" → "Minimal CLI", "gui" → "GUI Desktop"
**When to use:** Displaying the preferences menu

```bash
# In _settings_show_preferences_menu:
local ctype_raw ctype_label
ctype_raw="$(settings_get '.defaults.container_type')"
case "$ctype_raw" in
    "cli") ctype_label="Minimal CLI" ;;
    "gui") ctype_label="GUI Desktop" ;;
    *)     ctype_label="Ask each time" ;;
esac
echo "  [2] Default container:    ${ctype_label}"
```

### Anti-Patterns to Avoid
- **String "null" comparison:** `settings_get` returns `""` for JSON null (due to `// empty`), never the string `"null"`. Do not compare against `"null"`.
- **Modifying restore flow:** `menu_action_restore` in menu.sh must not be touched — it reads type from instance registry, not preferences.
- **Using msg_info/msg_ok for auto-skip message:** The decision is plain text with arrow, no color function.
- **Writing null via `--arg`:** `--arg val "null"` writes the string `"null"`, not JSON null. Use `jq -n '{ field: null }'` directly in the jq expression.

## Don't Hand-Roll

| Problem | Don't Build | Use Instead | Why |
|---------|-------------|-------------|-----|
| Atomic JSON writes | Custom write function | Existing `settings_set` + `settings_get` | Already handles tmp+mv atomicity |
| Null detection | Custom null checker | `[[ -z "$(settings_get ...)" ]]` | `// empty` in settings_get already maps null→"" |
| Boolean config reads | Custom bool parser | Existing `settings_get_bool` | Already handles type() check for booleans |

**Key insight:** All infrastructure already exists. This phase wires existing plumbing — it does not add new plumbing.

## Common Pitfalls

### Pitfall 1: Writing null with `--arg` in jq
**What goes wrong:** `jq --arg val "null" '{ field: $val }'` writes the JSON string `"null"`, not JSON null. Then `settings_get` returns the literal string `"null"` (not empty), and the null-detection check `[[ -z "$result" ]]` fails.
**Why it happens:** `--arg` always produces strings.
**How to avoid:** In `settings_ensure_config_file`, use `container_type: null` as a literal in the jq expression body, not via `--arg`.
**Warning signs:** `jq '.defaults.container_type | type'` returns `"string"` instead of `"null"` after fresh config creation.

### Pitfall 2: Forgetting to update the existing settings test
**What goes wrong:** Test `"settings_ensure_config_file sets default container_type to cli"` (line 45-49 of settings.bats) will fail after the factory default changes to null.
**Why it happens:** The test asserts `[[ "$val" == "cli" ]]` — this breaks when default becomes null/empty.
**How to avoid:** Update the test to assert that `settings_get '.defaults.container_type'` returns `""` (empty string) on fresh config. Add a raw jq test confirming `jq '.defaults.container_type'` returns `"null"`.
**Warning signs:** BATS run shows a failure in settings.bats after the factory default change.

### Pitfall 3: Auto-skip message appearing in subshell output
**What goes wrong:** `menu_select_container_type` is called as `container_type="$(menu_select_container_type)"` in `menu_action_new`. The auto-skip message (arrow text) and the return value (type string) both go to stdout. The caller captures ALL stdout as `$container_type`, so the messages get concatenated into the variable.
**Why it happens:** Command substitution captures all stdout.
**How to avoid:** Print the auto-skip message to stderr (`>&2`) rather than stdout, so only the type string (`"cli"` or `"gui"`) ends up captured. OR use the same tail-line extraction pattern already used in menu.bats tests: the type is always the last line of output.

Looking at the existing test pattern in menu.bats:
```bash
result="$(echo "1" | menu_select_container_type)"
last_line="$(echo "$result" | tail -1)"
[[ "$last_line" == "cli" ]]
```
The tests already use `tail -1` to get the type. The caller in `menu_action_new` does:
```bash
container_type="$(menu_select_container_type)"
```
This captures the full output including the prompt lines, then uses `$container_type` as the type value. This works today because the prompt lines go to `/dev/tty` (read -rp) or stdout, and the only echoed value is the type. After the change, the auto-skip prints two lines to stdout before echoing the type.

**Resolution:** Print auto-skip message lines to stderr. The single `echo "$default_type"` at the end is the only stdout output, so command substitution captures only the type cleanly.

**Warning signs:** `instances_add "$name" "$container_type"` gets called with a value like `"→ Using default: GUI Desktop\n  Change in [P] Preferences\ngui"` instead of `"gui"`.

### Pitfall 4: _settings_show_preferences_menu currently displays raw ctype value
**What goes wrong:** If left unchanged, the preferences menu will show `Container Type: ` (blank) or `Container Type: null` after the factory default change.
**Why it happens:** `_settings_show_preferences_menu` does `ctype="$(settings_get '.defaults.container_type')"` and prints it directly.
**How to avoid:** Add label mapping in `_settings_show_preferences_menu` (Pattern 4 above).

## Code Examples

Verified patterns from official sources (jq manual + existing codebase):

### Null literal in jq expression
```bash
# Write null as a JSON null (not string), no --arg needed
jq -n '{
  defaults: {
    container_type: null,
    memory_limit: "2g"
  }
}' > config.json
# Verify: jq '.defaults.container_type | type' config.json => "null"
# Verify: jq -r '.defaults.container_type // empty' config.json => "" (empty)
```

### settings_get behavior with null
```bash
# Given config: { "defaults": { "container_type": null } }
settings_get '.defaults.container_type'
# Returns: "" (empty string — because jq -r 'null // empty' outputs nothing)

# Test for "not yet set":
val="$(settings_get '.defaults.container_type')"
[[ -z "$val" ]]  # true when null or missing
```

### settings_set writing null (not needed — cycle only goes to cli/gui)
```bash
# The null state is only the factory state; settings_set is never called with null
# Cycle: null -> cli -> gui -> cli (null is only the initial unset state)
```

### BATS test pattern for updated default
```bash
@test "settings_ensure_config_file sets default container_type to null" {
    settings_ensure_config_file
    # Raw JSON value should be null
    val="$(jq '.defaults.container_type' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "null" ]]
    # settings_get should return empty string
    got="$(settings_get '.defaults.container_type')"
    [[ -z "$got" ]]
}
```

### BATS test pattern for auto-skip in menu_select_container_type
```bash
@test "menu_select_container_type auto-skips when default is cli" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'cli' 'string'
    result="$(menu_select_container_type 2>/dev/null)"
    [[ "$result" == "cli" ]]
}

@test "menu_select_container_type shows prompt when container_type is null" {
    settings_ensure_config_file
    # Default is null — should show prompt, read "1"
    result="$(echo "1" | menu_select_container_type 2>/dev/null)"
    last_line="$(echo "$result" | tail -1)"
    [[ "$last_line" == "cli" ]]
}
```

## State of the Art

| Old Approach | Current Approach | When Changed | Impact |
|--------------|------------------|--------------|--------|
| Factory default `"cli"` | Factory default `null` | Phase 8 | First-time users see the interactive prompt instead of silently defaulting to CLI |
| `container_type` raw value displayed | Human-readable label displayed | Phase 8 | "Minimal CLI", "GUI Desktop", "Ask each time" instead of "cli", "gui", "" |
| `cli ↔ gui` two-state toggle | `null → cli → gui → cli` three-state cycle | Phase 8 | Null is entry state only; once set, user cycles between the two real types |

**Deprecated/outdated:**
- Test assertion `[[ "$val" == "cli" ]]` for container_type default: replaced by null assertion in Phase 8.

## Open Questions

1. **menu_select_container_type needs settings_get — but menu.sh currently does not source settings.sh**
   - What we know: `menu.sh` is sourced after all other modules in `bin/csm`. The source order in `bin/csm` is: common.sh → settings.sh → credentials.sh → instances.sh → docker.sh → backup.sh → menu.sh. Settings functions are available when menu.sh runs.
   - What's unclear: Does `menu.sh` need to call `settings_ensure_config_file` defensively before calling `settings_get`? Looking at the existing code, `settings_ensure_config_file` is called inside `settings_menu()` — other callers just call `settings_get` directly (e.g., `credentials.sh` calls `settings_get '.integrations.mcp_port'` without a guard).
   - Recommendation: Call `settings_get` directly in `menu_select_container_type` without a guard — consistent with the existing pattern in credentials.sh. The config file will always exist by the time menu is invoked (startup calls `settings_ensure_config_file` via `settings_menu` or directly).

   **Actually:** Check `bin/csm` to confirm `settings_ensure_config_file` is called at startup — see below.

## Validation Architecture

### Test Framework
| Property | Value |
|----------|-------|
| Framework | BATS (bats-core) |
| Config file | none — tests sourced directly |
| Quick run command | `~/.local/bin/bats tests/settings.bats tests/menu.bats` |
| Full suite command | `~/.local/bin/bats tests/` |

### Phase Requirements → Test Map
| Req ID | Behavior | Test Type | Automated Command | File Exists? |
|--------|----------|-----------|-------------------|-------------|
| SETT-01 | `defaults.container_type` is JSON null in fresh config | unit | `~/.local/bin/bats tests/settings.bats` | ✅ (update existing test) |
| SETT-01 | `settings_get` returns empty string for null container_type | unit | `~/.local/bin/bats tests/settings.bats` | ✅ (new test in settings.bats) |
| SETT-04 | Auto-skip when default is set (cli) | unit | `~/.local/bin/bats tests/menu.bats` | ✅ (new test in menu.bats) |
| SETT-04 | Auto-skip when default is set (gui) | unit | `~/.local/bin/bats tests/menu.bats` | ✅ (new test in menu.bats) |
| SETT-04 | Interactive prompt shown when container_type is null | unit | `~/.local/bin/bats tests/menu.bats` | ✅ (update existing tests) |
| SETT-04 | Cycle null→cli→gui→cli in _settings_cycle_container_type | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-04 | Preferences menu displays "Ask each time" when null | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-04 | Preferences menu displays "Minimal CLI" when cli | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |
| SETT-04 | Preferences menu displays "GUI Desktop" when gui | unit | `~/.local/bin/bats tests/settings.bats` | ❌ Wave 0 |

### Sampling Rate
- **Per task commit:** `~/.local/bin/bats tests/settings.bats tests/menu.bats`
- **Per wave merge:** `~/.local/bin/bats tests/`
- **Phase gate:** Full suite green before `/gsd:verify-work`

### Wave 0 Gaps
- [ ] New tests in `tests/settings.bats` — covers cycle behavior (SETT-04) and null display labels
- [ ] New tests in `tests/menu.bats` — covers auto-skip behavior (SETT-04)
- [ ] Update existing test in `tests/settings.bats` line 45-49: assert null not "cli"

*(Existing test infrastructure covers all other phase requirements)*

## Sources

### Primary (HIGH confidence)
- Direct code reading of `lib/settings.sh` — full source reviewed
- Direct code reading of `lib/menu.sh` — full source reviewed
- Direct code reading of `tests/settings.bats` and `tests/menu.bats` — all tests reviewed
- jq manual: `// empty` alternative operator maps null/false to empty output in `-r` mode
- jq manual: `--arg` always produces strings; null literals must appear in expression body

### Secondary (MEDIUM confidence)
- Existing codebase patterns (Phase 01 decisions in STATE.md): atomic writes via tmp+mv, settings_get uses `// empty`, `settings_set` type parameter

### Tertiary (LOW confidence)
- None

## Metadata

**Confidence breakdown:**
- Standard stack: HIGH — no new dependencies, all existing tools
- Architecture: HIGH — code read directly, jq behavior verified through existing test patterns
- Pitfalls: HIGH — identified through direct code analysis (stderr vs stdout, jq null vs string null)

**Research date:** 2026-03-14
**Valid until:** 2026-04-14 (stable Bash/jq — no churn risk)
