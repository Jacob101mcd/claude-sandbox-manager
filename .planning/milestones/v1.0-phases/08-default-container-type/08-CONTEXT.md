# Phase 8: Wire Default Container Type - Context

**Gathered:** 2026-03-14
**Status:** Ready for planning

<domain>
## Phase Boundary

The `defaults.container_type` setting from user preferences is applied when creating new instances, fixing the "Preferences → Effect" end-to-end flow. Only `menu_select_container_type()` and `_settings_cycle_container_type()` are affected. Restore flow is untouched — restore always uses the backup's original type.

</domain>

<decisions>
## Implementation Decisions

### Auto-skip behavior
- When `defaults.container_type` is explicitly set (non-null), skip the container type prompt entirely
- Show plain text message: `→ Using default: GUI Desktop` (or Minimal CLI) with hint `Change in [P] Preferences`
- When `defaults.container_type` is null (factory default), show the full selection prompt as today
- Restore flow is NOT affected — restore always uses the backed-up container type regardless of preference

### Config schema change
- Factory default for `defaults.container_type` changes from `"cli"` to `null`
- Null means "not explicitly set by user" — triggers the interactive prompt
- Once user sets a preference via [P] Preferences, it becomes `"cli"` or `"gui"` and auto-skips from then on

### Settings menu cycle behavior
- Cycle: null → cli → gui → cli (no way back to null once set)
- Display when null: `Container Type: Ask each time`
- Display when set: `Container Type: Minimal CLI` or `Container Type: GUI Desktop`

### Message style
- Auto-skip uses plain text with arrow (no msg_info/msg_ok color function):
  ```
  → Using default: GUI Desktop
    Change in [P] Preferences
  ```
- "Not set" state displayed as "Ask each time" in preferences menu

### Claude's Discretion
- Exact implementation of null detection in settings_get (jq null handling)
- Whether to update settings_ensure_config_file to use null or omit the key entirely
- Test structure and assertions

</decisions>

<specifics>
## Specific Ideas

- "Ask each time" label in preferences describes the behavior, not the state — more user-friendly than "Not set"
- The auto-skip message should feel lightweight — plain arrow, no color, brief hint to preferences
- Once a user commits to a default in preferences, there's no "unset" — they've made a choice

</specifics>

<code_context>
## Existing Code Insights

### Reusable Assets
- `settings_get '.defaults.container_type'`: Already reads the value from config — just needs null handling
- `_settings_cycle_container_type()` in `lib/settings.sh:199`: Current toggle logic, needs null-aware cycling
- `menu_select_container_type()` in `lib/menu.sh:121`: Current hardcoded prompt, main target for this phase

### Established Patterns
- `settings_get` returns raw jq output — null will come through as literal `"null"` string or empty
- `settings_set` takes a type parameter ('string', 'number') for correct jq typing
- `settings_ensure_config_file()` creates factory defaults — needs container_type changed to null

### Integration Points
- `lib/menu.sh:204`: `menu_action_new()` calls `menu_select_container_type()` — the auto-skip happens here
- `lib/settings.sh:55-65`: `settings_ensure_config_file()` — factory default schema needs update
- `lib/settings.sh:199-208`: `_settings_cycle_container_type()` — cycle logic needs null awareness
- `lib/settings.sh:274`: Settings display — needs "Ask each time" for null state

</code_context>

<deferred>
## Deferred Ideas

None — discussion stayed within phase scope

</deferred>

---

*Phase: 08-default-container-type*
*Context gathered: 2026-03-14*
