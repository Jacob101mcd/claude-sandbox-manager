#!/usr/bin/env bash
# lib/settings.sh -- Config file management and interactive preferences menu
#
# This file is sourced by bin/csm after common.sh and before credentials.sh.
# CSM_ROOT must be set by the entry point before sourcing this file.
#
# Provides: settings_ensure_config_file, settings_get, settings_get_bool,
#           settings_set, settings_menu

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# ---------------------------------------------------------------------------
# settings_ensure_config_file -- Create csm-config.json with defaults if missing.
# Migrates CSM_AUTO_BACKUP and CSM_MCP_PORT from .env if present.
# ---------------------------------------------------------------------------
settings_ensure_config_file() {
    local config_file="${CSM_ROOT}/csm-config.json"

    if [[ -f "$config_file" ]]; then
        return 0
    fi

    # Default values (may be overridden by .env migration)
    local auto_backup="false"
    local mcp_port="8811"

    # Migrate legacy .env vars if .env exists
    local env_file="${CSM_ROOT}/.env"
    if [[ -f "$env_file" ]]; then
        local line key value
        while IFS= read -r line || [[ -n "$line" ]]; do
            [[ -z "$line" ]] && continue
            [[ "$line" =~ ^[[:space:]]*# ]] && continue
            key="${line%%=*}"
            value="${line#*=}"
            [[ "$key" == "$line" ]] && continue

            if [[ "$key" == "CSM_AUTO_BACKUP" && "$value" == "1" ]]; then
                auto_backup="true"
                msg_warn "Migrating CSM_AUTO_BACKUP from .env to csm-config.json"
            fi

            if [[ "$key" == "CSM_MCP_PORT" && -n "$value" ]]; then
                mcp_port="$value"
                msg_warn "Migrating CSM_MCP_PORT from .env to csm-config.json"
            fi
        done < "$env_file"
    fi

    # Write config file with resolved defaults
    jq -n \
        --arg mem "2g" \
        --argjson cpu 2 \
        --argjson ab "$auto_backup" \
        --argjson port "$mcp_port" \
        '{
          defaults: {
            container_type: null,
            memory_limit: $mem,
            cpu_limit: $cpu
          },
          backup: {
            auto_backup: $ab
          },
          integrations: {
            mcp_port: $port
          }
        }' > "${config_file}.tmp" && mv "${config_file}.tmp" "$config_file"

    msg_warn "Created csm-config.json with defaults at ${config_file}"
}

# ---------------------------------------------------------------------------
# settings_get -- Read a jq dotted path from csm-config.json
# Args: $1 = jq path (e.g. '.defaults.memory_limit')
# Returns: value on stdout, empty string if missing
# ---------------------------------------------------------------------------
settings_get() {
    local jq_path="$1"
    local config_file="${CSM_ROOT}/csm-config.json"

    if [[ ! -f "$config_file" ]]; then
        echo ""
        return 0
    fi

    jq -r "${jq_path} // empty" "$config_file" 2>/dev/null || echo ""
}

# ---------------------------------------------------------------------------
# settings_get_bool -- Read a boolean field using has() to avoid false-as-absent bug
# Args: $1 = jq path (e.g. '.backup.auto_backup')
# Returns: "true" or "false" on stdout
# ---------------------------------------------------------------------------
settings_get_bool() {
    local jq_path="$1"
    local config_file="${CSM_ROOT}/csm-config.json"

    if [[ ! -f "$config_file" ]]; then
        echo "false"
        return 0
    fi

    # Build a jq expression that handles nested paths safely
    # For .backup.auto_backup: check if backup exists and has auto_backup field
    local result
    result="$(jq -r "if (${jq_path} | type) == \"boolean\" then ${jq_path} else false end" "$config_file" 2>/dev/null || echo "false")"

    echo "${result:-false}"
}

# ---------------------------------------------------------------------------
# settings_set -- Write a value to csm-config.json atomically
# Args: $1 = jq path (e.g. '.defaults.memory_limit')
#       $2 = value to set
#       $3 = type: "string" | "bool" | "number"
# ---------------------------------------------------------------------------
settings_set() {
    local jq_path="$1"
    local value="$2"
    local type="${3:-string}"
    local config_file="${CSM_ROOT}/csm-config.json"

    if [[ ! -f "$config_file" ]]; then
        return 1
    fi

    case "$type" in
        bool|number)
            jq --argjson val "$value" "${jq_path} = \$val" \
                "$config_file" > "${config_file}.tmp" \
                && mv "${config_file}.tmp" "$config_file"
            ;;
        *)
            jq --arg val "$value" "${jq_path} = \$val" \
                "$config_file" > "${config_file}.tmp" \
                && mv "${config_file}.tmp" "$config_file"
            ;;
    esac
}

# ---------------------------------------------------------------------------
# _settings_validate_port -- Validate port is in range 1024-65535
# ---------------------------------------------------------------------------
_settings_validate_port() {
    local val="$1"
    if ! [[ "$val" =~ ^[0-9]+$ ]] || (( val < 1024 || val > 65535 )); then
        msg_error "Port must be a number between 1024 and 65535."
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# _settings_validate_memory -- Validate Docker memory format
# ---------------------------------------------------------------------------
_settings_validate_memory() {
    local val="$1"
    if ! [[ "$val" =~ ^[0-9]+[mgkMGK]?$ ]]; then
        msg_error "Memory must match Docker format (e.g. 2g, 512m, 1024k, or bytes)."
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# _settings_validate_cpu -- Validate CPU is a positive number
# ---------------------------------------------------------------------------
_settings_validate_cpu() {
    local val="$1"
    # Must be a positive integer or decimal
    if ! [[ "$val" =~ ^[0-9]+(\.[0-9]+)?$ ]]; then
        msg_error "CPU limit must be a positive number (e.g. 2 or 0.5)."
        return 1
    fi
    return 0
}

# ---------------------------------------------------------------------------
# _settings_toggle_auto_backup -- Toggle backup.auto_backup boolean
# ---------------------------------------------------------------------------
_settings_toggle_auto_backup() {
    local config_file="${CSM_ROOT}/csm-config.json"
    local current
    current="$(settings_get_bool '.backup.auto_backup')"

    local new_val
    if [[ "$current" == "true" ]]; then new_val="false"; else new_val="true"; fi

    settings_set '.backup.auto_backup' "$new_val" 'bool'
    msg_ok "Auto-backup: ${new_val}"
}

# ---------------------------------------------------------------------------
# _settings_cycle_container_type -- Toggle default container type cli<->gui
# ---------------------------------------------------------------------------
_settings_cycle_container_type() {
    local current
    current="$(settings_get '.defaults.container_type')"

    local new_val
    case "$current" in
        "cli") new_val="gui" ;;
        "gui") new_val="cli" ;;
        *)     new_val="cli" ;;   # null/"" -> cli (first explicit set)
    esac

    settings_set '.defaults.container_type' "$new_val" 'string'
    msg_ok "Default container type: ${new_val}"
}

# ---------------------------------------------------------------------------
# _settings_set_memory_limit -- Prompt and update memory limit
# ---------------------------------------------------------------------------
_settings_set_memory_limit() {
    local current
    current="$(settings_get '.defaults.memory_limit')"

    local input
    read -rp "Memory limit [${current}]: " input
    input="${input:-$current}"

    if ! _settings_validate_memory "$input"; then
        return 1
    fi

    settings_set '.defaults.memory_limit' "$input" 'string'
    msg_ok "Memory limit: ${input}"
}

# ---------------------------------------------------------------------------
# _settings_set_cpu_limit -- Prompt and update CPU limit
# ---------------------------------------------------------------------------
_settings_set_cpu_limit() {
    local current
    current="$(settings_get '.defaults.cpu_limit')"

    local input
    read -rp "CPU limit [${current}]: " input
    input="${input:-$current}"

    if ! _settings_validate_cpu "$input"; then
        return 1
    fi

    settings_set '.defaults.cpu_limit' "$input" 'number'
    msg_ok "CPU limit: ${input}"
}

# ---------------------------------------------------------------------------
# _settings_set_mcp_port -- Prompt and update MCP port
# ---------------------------------------------------------------------------
_settings_set_mcp_port() {
    local current
    current="$(settings_get '.integrations.mcp_port')"

    local input
    read -rp "MCP port [${current}]: " input
    input="${input:-$current}"

    if ! _settings_validate_port "$input"; then
        return 1
    fi

    settings_set '.integrations.mcp_port' "$input" 'number'
    msg_ok "MCP port: ${input}"
}

# ---------------------------------------------------------------------------
# _settings_show_preferences_menu -- Display preferences menu with current values
# ---------------------------------------------------------------------------
_settings_show_preferences_menu() {
    local auto_bk mem cpu ctype port

    auto_bk="$(settings_get_bool '.backup.auto_backup')"
    ctype="$(settings_get '.defaults.container_type')"
    mem="$(settings_get '.defaults.memory_limit')"
    cpu="$(settings_get '.defaults.cpu_limit')"
    port="$(settings_get '.integrations.mcp_port')"

    local ctype_label
    case "$ctype" in
        "cli") ctype_label="Minimal CLI" ;;
        "gui") ctype_label="GUI Desktop" ;;
        *)     ctype_label="Ask each time" ;;
    esac

    echo ""
    echo "${_MENU_CLR_CYAN}--- Preferences ---${_CLR_RESET}"
    echo "  [1] Auto-backup:          ${auto_bk}"
    echo "  [2] Default container:    ${ctype_label}"
    echo "  [3] Memory limit:         ${mem}"
    echo "  [4] CPU limit:            ${cpu}"
    echo "  [5] MCP port:             ${port}"
    echo "  [B] Back"
}

# ---------------------------------------------------------------------------
# settings_menu -- Interactive preferences sub-menu
# ---------------------------------------------------------------------------
settings_menu() {
    settings_ensure_config_file

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
