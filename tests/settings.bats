#!/usr/bin/env bats
# tests/settings.bats -- Tests for lib/settings.sh

load test_helper

setup() {
    REAL_CSM_ROOT="$CSM_ROOT"
    CSM_ROOT="$(mktemp -d)"
    export CSM_ROOT
    source "$REAL_CSM_ROOT/lib/common.sh"
    source "$REAL_CSM_ROOT/lib/settings.sh"
}

teardown() {
    rm -rf "$CSM_ROOT"
}

# ---------------------------------------------------------------------------
# settings_ensure_config_file -- creation and idempotency
# ---------------------------------------------------------------------------

@test "settings_ensure_config_file creates csm-config.json when missing" {
    [[ ! -f "${CSM_ROOT}/csm-config.json" ]]
    settings_ensure_config_file
    [[ -f "${CSM_ROOT}/csm-config.json" ]]
}

@test "settings_ensure_config_file creates valid JSON" {
    settings_ensure_config_file
    jq empty "${CSM_ROOT}/csm-config.json"
}

@test "settings_ensure_config_file sets default memory_limit to 2g" {
    settings_ensure_config_file
    val="$(jq -r '.defaults.memory_limit' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "2g" ]]
}

@test "settings_ensure_config_file sets default cpu_limit to 2" {
    settings_ensure_config_file
    val="$(jq -r '.defaults.cpu_limit' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "2" ]]
}

@test "settings_ensure_config_file sets default container_type to null" {
    settings_ensure_config_file
    # Raw jq should return "null" (the JSON null literal, not string "null")
    raw="$(jq '.defaults.container_type' "${CSM_ROOT}/csm-config.json")"
    [[ "$raw" == "null" ]]
    # settings_get should return empty string for null
    val="$(settings_get '.defaults.container_type')"
    [[ -z "$val" ]]
}

@test "settings_ensure_config_file sets backup.auto_backup to false" {
    settings_ensure_config_file
    val="$(jq '.backup.auto_backup' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "false" ]]
}

@test "settings_ensure_config_file sets integrations.mcp_port to 8811" {
    settings_ensure_config_file
    val="$(jq '.integrations.mcp_port' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "8811" ]]
}

@test "settings_ensure_config_file is idempotent (does not overwrite existing file)" {
    settings_ensure_config_file
    # Manually write a custom value
    echo '{"defaults":{"memory_limit":"4g","cpu_limit":4,"container_type":"cli"},"backup":{"auto_backup":false},"integrations":{"mcp_port":9000}}' \
        > "${CSM_ROOT}/csm-config.json"
    settings_ensure_config_file
    val="$(jq -r '.defaults.memory_limit' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "4g" ]]
}

@test "settings_ensure_config_file migrates CSM_AUTO_BACKUP=1 from .env" {
    # Create a .env with CSM_AUTO_BACKUP=1
    echo "CSM_AUTO_BACKUP=1" > "${CSM_ROOT}/.env"
    settings_ensure_config_file
    val="$(jq '.backup.auto_backup' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "true" ]]
}

@test "settings_ensure_config_file migrates CSM_MCP_PORT from .env" {
    # Create a .env with CSM_MCP_PORT=9000
    echo "CSM_MCP_PORT=9000" > "${CSM_ROOT}/.env"
    settings_ensure_config_file
    val="$(jq '.integrations.mcp_port' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "9000" ]]
}

@test "settings_ensure_config_file does not migrate when config already exists" {
    # Pre-create a config with default port
    cat > "${CSM_ROOT}/csm-config.json" <<'JSON'
{
  "defaults": {"container_type": "cli", "memory_limit": "2g", "cpu_limit": 2},
  "backup": {"auto_backup": false},
  "integrations": {"mcp_port": 8811}
}
JSON
    # .env has a different value
    echo "CSM_MCP_PORT=9999" > "${CSM_ROOT}/.env"
    settings_ensure_config_file
    # Should still be 8811 (existing config not overwritten)
    val="$(jq '.integrations.mcp_port' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "8811" ]]
}

# ---------------------------------------------------------------------------
# settings_get -- read dotted path values
# ---------------------------------------------------------------------------

@test "settings_get returns memory_limit value" {
    settings_ensure_config_file
    val="$(settings_get '.defaults.memory_limit')"
    [[ "$val" == "2g" ]]
}

@test "settings_get returns cpu_limit value" {
    settings_ensure_config_file
    val="$(settings_get '.defaults.cpu_limit')"
    [[ "$val" == "2" ]]
}

@test "settings_get returns mcp_port value" {
    settings_ensure_config_file
    val="$(settings_get '.integrations.mcp_port')"
    [[ "$val" == "8811" ]]
}

@test "settings_get returns empty string for missing key" {
    settings_ensure_config_file
    val="$(settings_get '.nonexistent.key')"
    [[ -z "$val" ]]
}

# ---------------------------------------------------------------------------
# settings_set -- write values atomically
# ---------------------------------------------------------------------------

@test "settings_set writes string value and preserves other keys" {
    settings_ensure_config_file
    settings_set '.defaults.memory_limit' '4g' 'string'
    val="$(jq -r '.defaults.memory_limit' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "4g" ]]
    # Verify other key still present
    cpu="$(jq -r '.defaults.cpu_limit' "${CSM_ROOT}/csm-config.json")"
    [[ "$cpu" == "2" ]]
}

@test "settings_set writes boolean value (not as string)" {
    settings_ensure_config_file
    settings_set '.backup.auto_backup' 'true' 'bool'
    # Should be boolean true (no quotes in JSON)
    val="$(jq '.backup.auto_backup' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "true" ]]
    # Confirm it is actually a boolean, not a string
    type_check="$(jq -r '.backup.auto_backup | type' "${CSM_ROOT}/csm-config.json")"
    [[ "$type_check" == "boolean" ]]
}

@test "settings_set writes numeric value (not as string)" {
    settings_ensure_config_file
    settings_set '.integrations.mcp_port' '9000' 'number'
    val="$(jq '.integrations.mcp_port' "${CSM_ROOT}/csm-config.json")"
    [[ "$val" == "9000" ]]
    type_check="$(jq -r '.integrations.mcp_port | type' "${CSM_ROOT}/csm-config.json")"
    [[ "$type_check" == "number" ]]
}

@test "settings_set uses atomic write (tmp+mv)" {
    settings_ensure_config_file
    # Write a value and confirm no .tmp file remains
    settings_set '.defaults.memory_limit' '8g' 'string'
    [[ ! -f "${CSM_ROOT}/csm-config.json.tmp" ]]
}

# ---------------------------------------------------------------------------
# settings_get_bool -- boolean field detection using has()
# ---------------------------------------------------------------------------

@test "settings_get_bool returns false for false boolean field" {
    settings_ensure_config_file
    val="$(settings_get_bool '.backup.auto_backup')"
    [[ "$val" == "false" ]]
}

@test "settings_get_bool returns true after toggling auto_backup" {
    settings_ensure_config_file
    settings_set '.backup.auto_backup' 'true' 'bool'
    val="$(settings_get_bool '.backup.auto_backup')"
    [[ "$val" == "true" ]]
}

@test "settings_get_bool returns false for missing field" {
    settings_ensure_config_file
    val="$(settings_get_bool '.nonexistent.field')"
    [[ "$val" == "false" ]]
}

# ---------------------------------------------------------------------------
# Validation helpers
# ---------------------------------------------------------------------------

@test "_settings_validate_port accepts 8811" {
    _settings_validate_port 8811
}

@test "_settings_validate_port accepts 1024 (minimum)" {
    _settings_validate_port 1024
}

@test "_settings_validate_port accepts 65535 (maximum)" {
    _settings_validate_port 65535
}

@test "_settings_validate_port rejects 1023 (below minimum)" {
    run _settings_validate_port 1023
    [[ "$status" -ne 0 ]]
}

@test "_settings_validate_port rejects 65536 (above maximum)" {
    run _settings_validate_port 65536
    [[ "$status" -ne 0 ]]
}

@test "_settings_validate_port rejects non-numeric input" {
    run _settings_validate_port "abc"
    [[ "$status" -ne 0 ]]
}

@test "_settings_validate_memory accepts 2g" {
    _settings_validate_memory "2g"
}

@test "_settings_validate_memory accepts 512m" {
    _settings_validate_memory "512m"
}

@test "_settings_validate_memory accepts 1024k" {
    _settings_validate_memory "1024k"
}

@test "_settings_validate_memory accepts numeric bytes" {
    _settings_validate_memory "1073741824"
}

@test "_settings_validate_memory rejects abc" {
    run _settings_validate_memory "abc"
    [[ "$status" -ne 0 ]]
}

@test "_settings_validate_cpu accepts 2" {
    _settings_validate_cpu "2"
}

@test "_settings_validate_cpu accepts 0.5" {
    _settings_validate_cpu "0.5"
}

@test "_settings_validate_cpu rejects non-numeric" {
    run _settings_validate_cpu "abc"
    [[ "$status" -ne 0 ]]
}

@test "_settings_validate_cpu rejects negative number" {
    run _settings_validate_cpu "-1"
    [[ "$status" -ne 0 ]]
}

# ---------------------------------------------------------------------------
# _settings_cycle_container_type -- null-aware cycling
# ---------------------------------------------------------------------------

@test "_settings_cycle_container_type from null sets cli" {
    settings_ensure_config_file
    # Config starts with null container_type
    _settings_cycle_container_type
    val="$(settings_get '.defaults.container_type')"
    [[ "$val" == "cli" ]]
}

@test "_settings_cycle_container_type from cli sets gui" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'cli' 'string'
    _settings_cycle_container_type
    val="$(settings_get '.defaults.container_type')"
    [[ "$val" == "gui" ]]
}

@test "_settings_cycle_container_type from gui sets cli" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'gui' 'string'
    _settings_cycle_container_type
    val="$(settings_get '.defaults.container_type')"
    [[ "$val" == "cli" ]]
}

# ---------------------------------------------------------------------------
# _settings_show_preferences_menu -- human-readable labels
# ---------------------------------------------------------------------------

@test "_settings_show_preferences_menu shows Ask each time when null" {
    settings_ensure_config_file
    # container_type is null by default
    result="$(_settings_show_preferences_menu)"
    [[ "$result" == *"Ask each time"* ]]
}

@test "_settings_show_preferences_menu shows Minimal CLI when cli" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'cli' 'string'
    result="$(_settings_show_preferences_menu)"
    [[ "$result" == *"Minimal CLI"* ]]
}

@test "_settings_show_preferences_menu shows GUI Desktop when gui" {
    settings_ensure_config_file
    settings_set '.defaults.container_type' 'gui' 'string'
    result="$(_settings_show_preferences_menu)"
    [[ "$result" == *"GUI Desktop"* ]]
}
