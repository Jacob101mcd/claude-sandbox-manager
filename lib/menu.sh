#!/usr/bin/env bash
# lib/menu.sh -- Interactive menu loop with instance display and action dispatch
#
# This file is sourced by bin/csm after all other library modules.
# Provides the user-facing CLI experience matching the PowerShell manager UX.
#
# Provides: menu_show_header, menu_show_instances, menu_show_actions,
#           menu_select_instance, menu_select_container_type,
#           menu_action_start, menu_action_stop, menu_action_rebuild,
#           menu_action_new, menu_action_remove,
#           menu_action_backup, menu_action_restore, menu_main

# Guard: CSM_ROOT must be set by entry point
[[ -n "${CSM_ROOT:-}" ]] || { echo "ERROR: CSM_ROOT not set. Run via bin/csm." >&2; exit 1; }

# ---------------------------------------------------------------------------
# Color constants for menu (defined inline since common.sh colors may be empty)
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
    _MENU_CLR_CYAN=$'\033[0;36m'
    _MENU_CLR_GRAY=$'\033[0;37m'
else
    _MENU_CLR_CYAN=""
    _MENU_CLR_GRAY=""
fi

# ---------------------------------------------------------------------------
# menu_show_header -- Print colored banner
# ---------------------------------------------------------------------------
menu_show_header() {
    echo ""
    echo "${_CLR_GREEN}=== Claude Sandbox Manager ===${_CLR_RESET}"
    echo ""
}

# ---------------------------------------------------------------------------
# menu_show_instances -- Display all instances with Docker status
# ---------------------------------------------------------------------------
menu_show_instances() {
    echo "${_MENU_CLR_CYAN}--- Instances ---${_CLR_RESET}"

    local registered_names
    registered_names="$(jq -r 'keys[]' "${CSM_ROOT}/.instances.json" 2>/dev/null)"

    if [[ -z "$registered_names" ]]; then
        echo "${_MENU_CLR_GRAY}  (no instances registered)${_CLR_RESET}"
        return
    fi

    instances_list_with_status
}

# ---------------------------------------------------------------------------
# menu_show_actions -- Print available action menu
# ---------------------------------------------------------------------------
menu_show_actions() {
    echo ""
    echo "${_MENU_CLR_CYAN}--- Actions ---${_CLR_RESET}"
    echo "  [S] Start an instance"
    echo "  [T] Stop an instance"
    echo "  [D] Rebuild an instance"
    echo "  [N] Create new instance"
    echo "  [R] Remove an instance"
    echo "  [B] Backup an instance"
    echo "  [E] Restore an instance"
    echo "  [P] Preferences"
    echo "  [Q] Quit"
}

# ---------------------------------------------------------------------------
# menu_select_instance -- Prompt user to pick an instance
# Args: $1 = prompt string
# Returns: selected instance name on stdout, or returns 1 if none available
# ---------------------------------------------------------------------------
menu_select_instance() {
    local prompt="${1:-Select instance:}"

    local registered_names
    registered_names="$(jq -r 'keys[]' "${CSM_ROOT}/.instances.json" 2>/dev/null || true)"

    if [[ -z "$registered_names" ]]; then
        msg_warn "No instances found."
        return 1
    fi

    # Convert to array
    local names=()
    while IFS= read -r name; do
        names+=("$name")
    done <<< "$registered_names"

    # Auto-select if only one
    if [[ ${#names[@]} -eq 1 ]]; then
        msg_info "Using instance: ${names[0]}"
        echo "${names[0]}"
        return 0
    fi

    # Show numbered list for selection
    echo "$prompt" >&2
    local i
    for i in "${!names[@]}"; do
        echo "  $((i + 1)). ${names[$i]}" >&2
    done

    local choice
    read -rp "Enter number: " choice

    # Validate: must be a number in range
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#names[@]} )); then
        msg_error "Invalid selection."
        return 1
    fi

    echo "${names[$((choice - 1))]}"
}

# ---------------------------------------------------------------------------
# menu_select_container_type -- Return container type, auto-skipping if default is set
# Returns: type string on stdout; auto-skip message on stderr when default is set
# ---------------------------------------------------------------------------
menu_select_container_type() {
    local default_type
    default_type="$(settings_get '.defaults.container_type')"

    if [[ -n "$default_type" ]]; then
        # User has set a preference -- auto-skip
        local label
        if [[ "$default_type" == "gui" ]]; then label="GUI Desktop"; else label="Minimal CLI"; fi
        echo "-> Using default: ${label}" >&2
        echo "  Change in [P] Preferences" >&2
        echo "$default_type"
        return
    fi

    # Null/unset -- show interactive prompt
    echo "" >&2
    echo "Select container type:" >&2
    echo "  [1] Minimal CLI" >&2
    echo "  [2] GUI Desktop" >&2
    echo "" >&2
    local choice
    read -rp "Select type [1]: " choice
    case "${choice:-1}" in
        1) echo "cli" ;;
        2) echo "gui" ;;
        *) msg_error "Invalid selection. Using Minimal CLI."; echo "cli" ;;
    esac
}

# ---------------------------------------------------------------------------
# menu_action_start -- Start an instance and optionally SSH in
# ---------------------------------------------------------------------------
menu_action_start() {
    local name
    name="$(menu_select_instance "Select instance to start:")" || return

    docker_start_instance "$name"

    local type
    type="$(instances_get_type "$name")"

    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        msg_ok "noVNC desktop: http://localhost:${vnc_port}"
        local answer
        read -rp "Open in browser? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            xdg-open "http://localhost:${vnc_port}" 2>/dev/null || \
            open "http://localhost:${vnc_port}" 2>/dev/null || \
            true
        fi
    else
        local answer
        read -rp "SSH into instance now? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            exec ssh "$(common_ssh_alias "$name")"
        fi
    fi
}

# ---------------------------------------------------------------------------
# menu_action_stop -- Stop a running instance
# ---------------------------------------------------------------------------
menu_action_stop() {
    local name
    name="$(menu_select_instance "Select instance to stop:")" || return

    docker_stop "$name"
    msg_ok "Stopped."
}

# ---------------------------------------------------------------------------
# menu_action_rebuild -- Rebuild an instance's image and restart the container
# ---------------------------------------------------------------------------
menu_action_rebuild() {
    local name
    name="$(menu_select_instance "Select instance to rebuild:")" || return

    msg_warn "Rebuild will recreate the container from a fresh image."
    msg_warn "In-container changes will be lost. Your workspace is preserved."

    local confirm
    read -rp "Continue? (y/N) " confirm
    [[ "$confirm" == "y" || "$confirm" == "Y" ]] || { msg_warn "Cancelled."; return; }

    docker_start_instance "$name"

    local type
    type="$(instances_get_type "$name")"

    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        msg_ok "noVNC desktop: http://localhost:${vnc_port}"
        local answer
        read -rp "Open in browser? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            xdg-open "http://localhost:${vnc_port}" 2>/dev/null || \
            open "http://localhost:${vnc_port}" 2>/dev/null || \
            true
        fi
    else
        local answer
        read -rp "SSH into instance now? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            exec ssh "$(common_ssh_alias "$name")"
        fi
    fi
}

# ---------------------------------------------------------------------------
# menu_action_new -- Create and start a new instance
# ---------------------------------------------------------------------------
menu_action_new() {
    local input
    read -rp "Enter instance name (lowercase, no spaces): " input
    input="${input,,}"

    # Validate: 4-10 chars, lowercase letters/digits/hyphens, no leading/trailing hyphen
    local name
    if ! [[ "$input" =~ ^[a-z0-9][a-z0-9-]{2,8}[a-z0-9]$ ]]; then
        msg_error "Invalid name. Use 4-10 characters: lowercase letters, digits, hyphens. Cannot start or end with a hyphen."
        return
    fi
    name="$input"

    # Check if already exists
    local existing_port
    existing_port="$(instances_get_port "$name")"
    if [[ -n "$existing_port" ]]; then
        msg_error "Instance '$name' already exists."
        return
    fi

    # Select container type
    local container_type
    container_type="$(menu_select_container_type)"

    # Register instance with type (docker_start_instance will find the port)
    instances_add "$name" "$container_type"

    # Prompt for remote control (default off per locked decision)
    local rc_answer
    read -rp "Enable remote control (requires claude.ai account, not API key)? (y/N) " rc_answer
    if [[ "$rc_answer" == "y" || "$rc_answer" == "Y" ]]; then
        instances_set_remote_control "$name" true
    fi

    docker_start_instance "$name"

    # Show remote control info if enabled
    local rc_enabled
    rc_enabled="$(instances_get_remote_control "$name")"
    if [[ "$rc_enabled" == "true" ]]; then
        msg_info "Remote control enabled. After SSH, check /tmp/csm-remote-control.log for session URL."
    fi

    if [[ "$container_type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        msg_ok "noVNC desktop: http://localhost:${vnc_port}"
        local answer
        read -rp "Open in browser? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            xdg-open "http://localhost:${vnc_port}" 2>/dev/null || \
            open "http://localhost:${vnc_port}" 2>/dev/null || \
            true
        fi
    else
        local answer
        read -rp "SSH into instance now? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            exec ssh "$(common_ssh_alias "$name")"
        fi
    fi
}

# ---------------------------------------------------------------------------
# menu_action_remove -- Remove an instance with confirmation
# ---------------------------------------------------------------------------
menu_action_remove() {
    local name
    name="$(menu_select_instance "Select instance to remove:")" || return

    local confirm
    read -rp "Remove instance '$name'? This stops the container and deregisters it. Type YES to confirm: " confirm

    if [[ "$confirm" != "YES" ]]; then
        msg_warn "Cancelled."
        return
    fi

    docker_remove "$name"
    ssh_remove_config "$name"
    instances_remove "$name"

    local delete_files
    read -rp "Also delete workspace and backups for '$name'? (y/N) " delete_files
    if [[ "$delete_files" == "y" || "$delete_files" == "Y" ]]; then
        local ws_dir bk_dir ssh_dir
        ws_dir="$(common_workspace_dir "$name")"
        bk_dir="$(common_backup_dir "$name")"
        ssh_dir="$(common_ssh_dir "$name")"

        [[ -d "$ws_dir" ]] && rm -rf "$ws_dir"
        [[ -d "$bk_dir" ]] && rm -rf "$bk_dir"
        [[ -d "$ssh_dir" ]] && rm -rf "$ssh_dir"

        msg_ok "Deleted files for '$name'."
    fi

    msg_ok "Instance '$name' removed."
}

# ---------------------------------------------------------------------------
# menu_action_backup -- Create a backup of an instance
# ---------------------------------------------------------------------------
menu_action_backup() {
    local name
    name="$(menu_select_instance "Select instance to back up:")" || return

    backup_create "$name"
}

# ---------------------------------------------------------------------------
# menu_action_restore -- Restore an instance from a selected backup
# ---------------------------------------------------------------------------
menu_action_restore() {
    local name
    name="$(menu_select_instance "Select instance to restore:")" || return

    backup_list "$name" || return

    local choice
    read -rp "Select backup number: " choice

    # Validate choice is a number in range
    if ! [[ "$choice" =~ ^[0-9]+$ ]] || (( choice < 1 || choice > ${#_BACKUP_LISTED_DIRS[@]} )); then
        msg_error "Invalid selection."
        return
    fi

    local selected_dir="${_BACKUP_LISTED_DIRS[$((choice - 1))]}"

    msg_warn "This will REPLACE the current instance with the selected backup."

    local confirm
    read -rp "Type YES to confirm restore: " confirm

    if [[ "$confirm" != "YES" ]]; then
        msg_warn "Cancelled."
        return
    fi

    backup_restore "$name" "$selected_dir"

    local type
    type="$(instances_get_type "$name")"

    if [[ "$type" == "gui" ]]; then
        local vnc_port
        vnc_port="$(instances_get_vnc_port "$name")"
        msg_ok "noVNC desktop: http://localhost:${vnc_port}"
        local answer
        read -rp "Open in browser? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            xdg-open "http://localhost:${vnc_port}" 2>/dev/null || \
            open "http://localhost:${vnc_port}" 2>/dev/null || \
            true
        fi
    else
        local answer
        read -rp "SSH into instance now? (y/N) " answer
        if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
            exec ssh "$(common_ssh_alias "$name")"
        fi
    fi
}

# ---------------------------------------------------------------------------
# menu_main -- Main interactive loop (entry point for the menu)
# ---------------------------------------------------------------------------
menu_main() {
    # Auto-create "default" instance if none exist (like PowerShell version)
    local registered_names
    registered_names="$(jq -r 'keys[]' "${CSM_ROOT}/.instances.json" 2>/dev/null || true)"

    if [[ -z "$registered_names" ]]; then
        msg_warn "No instances found. Creating 'default' instance..."
        instances_add "default" "cli"
        msg_info "Press [S] to build and start the default instance."
    fi

    menu_show_header

    while true; do
        menu_show_instances
        menu_show_actions

        local choice
        read -rp $'\nChoice: ' choice

        case "${choice,,}" in
            s) menu_action_start ;;
            t) menu_action_stop ;;
            d) menu_action_rebuild ;;
            n) menu_action_new ;;
            r) menu_action_remove ;;
            b) menu_action_backup ;;
            e) menu_action_restore ;;
            p) settings_menu ;;
            q) exit 0 ;;
            *) msg_error "Invalid choice." ;;
        esac
    done
}
