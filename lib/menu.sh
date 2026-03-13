#!/usr/bin/env bash
# lib/menu.sh -- Interactive menu loop with instance display and action dispatch
#
# This file is sourced by bin/csm after all other library modules.
# Provides the user-facing CLI experience matching the PowerShell manager UX.
#
# Provides: menu_show_header, menu_show_instances, menu_show_actions,
#           menu_select_instance, menu_select_container_type,
#           menu_action_start, menu_action_stop,
#           menu_action_new, menu_action_remove, menu_main

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
    echo "  [N] Create new instance"
    echo "  [R] Remove an instance"
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
    registered_names="$(jq -r 'keys[]' "${CSM_ROOT}/.instances.json" 2>/dev/null)"

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
    echo "$prompt"
    local i
    for i in "${!names[@]}"; do
        echo "  $((i + 1)). ${names[$i]}"
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
# menu_select_container_type -- Prompt user to choose a container type
# Returns: type string on stdout (currently always "cli")
# ---------------------------------------------------------------------------
menu_select_container_type() {
    echo ""
    echo "Select container type:"
    echo "  [1] Minimal CLI"
    echo "  [2] GUI Desktop (coming soon)"
    echo ""
    local choice
    read -rp "Type [1]: " choice
    case "${choice:-1}" in
        1) echo "cli" ;;
        2) msg_warn "GUI Desktop not yet available. Using Minimal CLI."; echo "cli" ;;
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

    local answer
    read -rp "SSH into instance now? (y/N) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        exec ssh "$(common_ssh_alias "$name")"
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
# menu_action_new -- Create and start a new instance
# ---------------------------------------------------------------------------
menu_action_new() {
    local input
    read -rp "Enter instance name (lowercase, no spaces): " input

    # Sanitize: keep only lowercase alphanumeric and hyphens
    local name
    name="$(echo "$input" | tr -cd 'a-z0-9-')"

    if [[ -z "$name" ]]; then
        msg_error "Invalid name."
        return
    fi

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

    docker_start_instance "$name"

    local answer
    read -rp "SSH into instance now? (y/N) " answer
    if [[ "$answer" == "y" || "$answer" == "Y" ]]; then
        exec ssh "$(common_ssh_alias "$name")"
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
# menu_main -- Main interactive loop (entry point for the menu)
# ---------------------------------------------------------------------------
menu_main() {
    # Auto-create "default" instance if none exist (like PowerShell version)
    local registered_names
    registered_names="$(jq -r 'keys[]' "${CSM_ROOT}/.instances.json" 2>/dev/null)"

    if [[ -z "$registered_names" ]]; then
        msg_warn "No instances found. Creating 'default' instance..."
        instances_add "default" "cli"
        docker_start_instance "default"
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
            n) menu_action_new ;;
            r) menu_action_remove ;;
            q) exit 0 ;;
            *) msg_error "Invalid choice." ;;
        esac
    done
}
