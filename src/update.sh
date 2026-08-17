#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE ACTUALIZACIÓN DEL SISTEMA (UPDATE)
# ==============================================================================

actualizar_vguard() {
    msg_section "$(t UPDATE_TITLE)"

    local repo_dir
    repo_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."
    repo_dir="$(realpath "$repo_dir")"

    msg_info "$(t UPDATE_DIR_DETECTED "$repo_dir")"

    if [ ! -d "$repo_dir/.git" ]; then
        msg_error "$(t UPDATE_NOT_GIT "$repo_dir")"
        return 1
    fi

    msg_info "$(t UPDATE_FETCHING)"
    if ! (cd "$repo_dir" && git fetch -q 2>/dev/null); then
        msg_error "$(t UPDATE_NO_CONN)"
        return 1
    fi

    local local_commit
    local remote_commit
    local_commit=$(cd "$repo_dir" && git rev-parse HEAD 2>/dev/null)
    remote_commit=$(cd "$repo_dir" && git rev-parse @{u} 2>/dev/null)

    if [ "$local_commit" = "$remote_commit" ]; then
        msg_success "$(t UPDATE_ALREADY)"
        return 0
    fi

    msg_info "$(t UPDATE_DL)"
    if (cd "$repo_dir" && git pull -q); then
        msg_success "$(t UPDATE_SUCCESS)"
    else
        msg_error "$(t UPDATE_PULL_ERR)"
        return 1
    fi

    msg_info "$(t UPDATE_REINSTALL)"
    if [ -f "$repo_dir/install.sh" ]; then
        bash "$repo_dir/install.sh"
    else
        chmod +x "$repo_dir/vguard"
    fi

    draw_separator
    msg_success "$(t UPDATE_DONE)"
    draw_separator
}

chequear_actualizaciones_vguard() {
    local silent_mode="${1:-false}"
    local repo_dir
    repo_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."
    repo_dir="$(realpath "$repo_dir")"

    local current_version="unknown"
    if [ -f "$repo_dir/VERSION" ]; then
        current_version=$(cat "$repo_dir/VERSION" 2>/dev/null || echo "unknown")
    fi

    if [ "$silent_mode" = "false" ]; then
        msg_info "$(t UPDATE_CHECKING "$current_version")"
    fi

    local github_api_url="https://api.github.com/repos/sowtarez/vguard/releases/latest"
    local api_response
    
    # Defensive curl request, avoid set -e crash
    api_response=$(curl -s --connect-timeout 5 "$github_api_url" 2>/dev/null) || true
    
    if [ -z "$api_response" ]; then
        if [ "$silent_mode" = "false" ]; then
            msg_warning "$(t UPDATE_CONN_ERROR)"
        fi
        return 1
    fi

    # Parse JSON with Python to extract tag_name (removing 'v' prefix if present)
    local remote_version
    remote_version=$(echo "$api_response" | python3 -c "import sys, json; data=json.load(sys.stdin); tag=data.get('tag_name', '').lstrip('v'); print(tag)" 2>/dev/null) || true

    if [ -z "$remote_version" ] || [[ ! "$remote_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if [ "$silent_mode" = "false" ]; then
            msg_warning "$(t UPDATE_CONN_ERROR)"
        fi
        return 1
    fi

    if [ "$current_version" != "$remote_version" ] && [ "$current_version" != "unknown" ]; then
        if [ "$silent_mode" = "false" ]; then
            echo -e "\n${CLR_YELLOW}========================================================${CLR_RESET}"
            echo -e "${CLR_BOLD}$(t UPDATE_NEW_VERSION "$remote_version")${CLR_RESET}"
            echo -e "${CLR_YELLOW}========================================================${CLR_RESET}"
            echo -e "$(t UPDATE_CURRENT_VER "${CLR_CYAN}$current_version${CLR_RESET}")"
            echo -e "$(t UPDATE_INSTRUCTION)"
            echo -e ""
        else
            echo -e "\n${CLR_YELLOW}[!] $(t UPDATE_SILENT_NEW "$remote_version")${CLR_RESET}"
        fi
        return 0
    else
        if [ "$silent_mode" = "false" ]; then
            msg_success "$(t UPDATE_LATEST "$current_version")"
        fi
        return 2
    fi
}
