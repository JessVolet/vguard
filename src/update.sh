#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE ACTUALIZACIÓN DEL SISTEMA (UPDATE)
# ==============================================================================

actualizar_vguard() {
    msg_section "ACTUALIZACIÓN DE VGUARD"

    local repo_dir
    repo_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/.."
    repo_dir="$(realpath "$repo_dir")"

    msg_info "Directorio de repositorio detectado: $repo_dir"

    if [ ! -d "$repo_dir/.git" ]; then
        msg_error "El directorio $repo_dir no es un repositorio Git válido. No se puede ejecutar 'git pull'."
        return 1
    fi

    msg_info "Buscando actualizaciones en el repositorio remoto..."
    if ! (cd "$repo_dir" && git fetch -q 2>/dev/null); then
        msg_error "No se pudo conectar con el repositorio remoto."
        return 1
    fi

    local local_commit
    local remote_commit
    local_commit=$(cd "$repo_dir" && git rev-parse HEAD 2>/dev/null)
    remote_commit=$(cd "$repo_dir" && git rev-parse @{u} 2>/dev/null)

    if [ "$local_commit" = "$remote_commit" ]; then
        msg_success "VGUARD ya está actualizado a la última versión disponible."
        return 0
    fi

    msg_info "Nuevos cambios detectados. Descargando actualización..."
    if (cd "$repo_dir" && git pull -q); then
        msg_success "Código fuente actualizado exitosamente."
    else
        msg_error "Error al aplicar 'git pull'. Revisa cambios locales pendientes."
        return 1
    fi

    msg_info "Reinstalando accesos directos y permisos de VGUARD..."
    if [ -f "$repo_dir/install.sh" ]; then
        bash "$repo_dir/install.sh"
    else
        chmod +x "$repo_dir/vguard"
    fi

    draw_separator
    msg_success "VGUARD ha sido actualizado exitosamente a la última versión."
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
        if [ "$CURRENT_LANG" = "en" ]; then
            msg_info "Checking for VGUARD updates (Local: $current_version)..."
        else
            msg_info "Comprobando actualizaciones de VGUARD (Local: $current_version)..."
        fi
    fi

    local raw_url="https://gitlab.com/sowtarez/vguard/-/raw/main/VERSION"
    local remote_version
    remote_version=$(curl -s --connect-timeout 2 "$raw_url" 2>/dev/null | tr -d '[:space:]') || true

    if [ -z "$remote_version" ] || [[ ! "$remote_version" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
        if [ "$silent_mode" = "false" ]; then
            if [ "$CURRENT_LANG" = "en" ]; then
                msg_warning "Could not connect to update server or response is invalid."
            else
                msg_warning "No se pudo conectar con el servidor de actualizaciones o la respuesta es inválida."
            fi
        fi
        return 1
    fi

    if [ "$current_version" != "$remote_version" ] && [ "$current_version" != "unknown" ]; then
        if [ "$silent_mode" = "false" ]; then
            echo -e "\n${CLR_YELLOW}========================================================${CLR_RESET}"
            if [ "$CURRENT_LANG" = "en" ]; then
                echo -e "${CLR_BOLD}🚀 NEW VERSION AVAILABLE: $remote_version${CLR_RESET}"
                echo -e "${CLR_YELLOW}========================================================${CLR_RESET}"
                echo -e "You are using version ${CLR_CYAN}$current_version${CLR_RESET}."
                echo -e "Run '${CLR_GREEN}sudo vguard update${CLR_RESET}' to install the latest version."
            else
                echo -e "${CLR_BOLD}🚀 NUEVA VERSIÓN DISPONIBLE: $remote_version${CLR_RESET}"
                echo -e "${CLR_YELLOW}========================================================${CLR_RESET}"
                echo -e "Estás usando la versión ${CLR_CYAN}$current_version${CLR_RESET}."
                echo -e "Ejecuta '${CLR_GREEN}sudo vguard update${CLR_RESET}' para instalar la última versión."
            fi
            echo -e ""
        else
            if [ "$CURRENT_LANG" = "en" ]; then
                echo -e "\n${CLR_YELLOW}[!] A new VGUARD update is available ($remote_version). Run 'sudo vguard update'.${CLR_RESET}"
            else
                echo -e "\n${CLR_YELLOW}[!] Hay una nueva actualización de VGUARD disponible ($remote_version). Ejecuta 'sudo vguard update'.${CLR_RESET}"
            fi
        fi
        return 0
    else
        if [ "$silent_mode" = "false" ]; then
            if [ "$CURRENT_LANG" = "en" ]; then
                msg_success "You are using the latest version of VGUARD ($current_version)."
            else
                msg_success "Estás utilizando la última versión de VGUARD ($current_version)."
            fi
        fi
        return 2
    fi
}
