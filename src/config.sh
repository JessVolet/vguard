#!/bin/bash
# ==============================================================================
# VGUARD v3.0 - MÓDULO DE CARGA DE CONFIGURACIÓN Y POLÍTICAS DE INFRAESTRUCTURA
# ==============================================================================

load_config() {
    local config_paths=(
        "/etc/vguard/vguard.conf"
        "$HOME/.config/vguard/vguard.conf"
        "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../config/vguard.conf.example"
        "./vguard.conf"
    )

    CONFIG_FILE=""
    for path in "${config_paths[@]}"; do
        if [ -f "$path" ]; then
            CONFIG_FILE="$path"
            break
        fi
    done

    if [ -z "$CONFIG_FILE" ]; then
        msg_error "No se encontró ningún archivo de configuración para VGUARD."
        msg_info "Ejecuta 'vguard init' para crear una configuración inicial."
        exit 1
    fi

    # Usar helper de Python para cargar variables JSON en el entorno
    local py_helper
    py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"

    if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
        eval "$(python3 "$py_helper" get-vars "$CONFIG_FILE")"
    else
        # Fallback a bash plano si python3 no está disponible
        VG_NAME="${VG_NAME:-fedora_server}"
        PATH_HDD_SERVICIOS="${PATH_HDD_SERVICIOS:-/mnt/sda1/servicios}"
        PATH_HDD_COMPARTIDO="${PATH_HDD_COMPARTIDO:-/mnt/sda1/compartido}"
        PATH_HDD_SISTEMA="${PATH_HDD_SISTEMA:-/mnt/sda1/sistema}"
        PATH_NVME_FAST="${PATH_NVME_FAST:-/mnt/nvme_fast}"
        VGUARD_OWNER="${VGUARD_OWNER:-vsynlo:vsynlo}"
        META_FILE="${META_FILE:-.vguard_meta}"
    fi

    SELINUX_CONTAINER="${SELINUX_CONTAINER:-container_file_t}"
    SELINUX_NETWORK="${SELINUX_NETWORK:-samba_share_t}"
    SELINUX_SYSTEM="${SELINUX_SYSTEM:-systemd_system_unit_t}"

    PERM_POSIX_CONTAINER="${PERM_POSIX_CONTAINER:-770}"
    PERM_POSIX_NETWORK="${PERM_POSIX_NETWORK:-775}"
    PERM_POSIX_SYSTEM="${PERM_POSIX_SYSTEM:-750}"

    detect_language
}

configurar_idioma() {
    local target_lang="$1"
    if [ -z "$target_lang" ]; then
        msg_info "Language option required: 'en' or 'es'"
        return 1
    fi

    local py_helper
    py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"
    if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$py_helper" set-lang "$CONFIG_FILE" "$target_lang"
    fi

    VGUARD_LANG="$target_lang"
    CURRENT_LANG="$target_lang"
    msg_success "$(t LANG_CHANGED) $target_lang"
}

configurar_modo_explorer() {
    local target_mode="$1"
    if [ -z "$target_mode" ]; then
        msg_info "Modos del explorador de VGUARD disponibles:"
        msg_info "  - experimental : TUI dinámica interactiva estilo Yazi usando FZF (Lazy 1-nivel)"
        msg_info "  - stable       : CLI liviano paginado basado en ls"
        msg_info "Modo actual: ${CFG_EXPLORER_MODE:-experimental}"
        return 0
    fi

    if [ "$target_mode" != "experimental" ] && [ "$target_mode" != "stable" ]; then
        msg_error "Modo del explorador no válido. Elige 'experimental' o 'stable'."
        return 1
    fi

    local py_helper
    py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"
    if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$py_helper" set-explorer-mode "$CONFIG_FILE" "$target_mode"
    fi

    CFG_EXPLORER_MODE="$target_mode"
    msg_success "Modo del explorador cambiado a: $target_mode"
}

asignar_perfil_servicio() {
    local target_vol="$1"
    local perfil="$2"

    if [ -z "$target_vol" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_vol="$CTX_SERVICE_NAME"
        else
            read -p "Ingresa el nombre del servicio u objetivo: " target_vol
        fi
    fi

    if [ -z "$perfil" ]; then
        echo -e "\n${CLR_BOLD}${CLR_CYAN}--- PERFILES DE SERVICIO DISPONIBLES EN VGUARD ---${CLR_RESET}"
        echo "1) datastore  : Bases de datos, backups, logs privados (Strict 0770/0660)"
        echo "2) webapp     : Nginx, PHP, Node.js, Web Servers (0755/0644 con storage 0775)"
        echo "3) shared-app : Contenedores compartidos mediante GID comun (0775/0664)"
        read -p "Selecciona un perfil (1-3) o nombre (datastore/webapp/shared-app): " choice_prof
        case "$choice_prof" in
            1) perfil="datastore" ;;
            2) perfil="webapp" ;;
            3) perfil="shared-app" ;;
            *) perfil="$choice_prof" ;;
        esac
    fi

    if [ -z "$perfil" ]; then
        msg_error "Perfil no especificado."
        return 1
    fi

    local py_helper
    py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"

    if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
        python3 "$py_helper" set-profile "$CONFIG_FILE" "$target_vol" "$perfil"
        msg_success "Perfil de servicio '$perfil' asignado correctamente a '$target_vol'."
        msg_info "Ejecuta 'vguard selected heal' para aplicar los permisos del perfil en disco."
    else
        msg_error "Se requiere Python3 para guardar perfiles en vguard.conf."
        return 1
    fi
}

obtener_politica_volumen() {
    local target_vol="$1"
    local subfolder="${2:-}"
    local target_path="${3:-}"

    local py_helper
    py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"

    POL_OWNER="vsynlo"
    POL_GROUP="vsynlo"
    POL_MODE_DIR="0770"
    POL_MODE_FILE="0660"
    POL_SELINUX="container_file_t"
    POL_ALLOW_SUB="true"
    POL_CONTAINER_MANAGED="false"

    if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
        local policy_json
        local query_target="${target_path:-$target_vol}"
        policy_json=$(python3 "$py_helper" get-policy "$CONFIG_FILE" "$query_target" "$subfolder")
        if [ -n "$policy_json" ]; then
            POL_OWNER=$(echo "$policy_json" | jq -r '.owner // "vsynlo"' 2>/dev/null || echo "vsynlo")
            POL_GROUP=$(echo "$policy_json" | jq -r '.group // "vsynlo"' 2>/dev/null || echo "vsynlo")
            POL_MODE_DIR=$(echo "$policy_json" | jq -r '.mode_dir // "0770"' 2>/dev/null || echo "0770")
            POL_MODE_FILE=$(echo "$policy_json" | jq -r '.mode_file // "0660"' 2>/dev/null || echo "0660")
            POL_SELINUX=$(echo "$policy_json" | jq -r '.selinux_context // "container_file_t"' 2>/dev/null || echo "container_file_t")
            POL_ALLOW_SUB=$(echo "$policy_json" | jq -r '.allow_subfolder_overrides // true' 2>/dev/null || echo "true")
            POL_CONTAINER_MANAGED=$(echo "$policy_json" | jq -r '.container_managed // false' 2>/dev/null || echo "false")
        fi
    fi
}

init_config() {
    local target_dir="/etc/vguard"
    local target_file="$target_dir/vguard.conf"

    msg_section "INICIALIZACIÓN DE CONFIGURACIÓN VGUARD v3.0"

    if [ "$EUID" -ne 0 ]; then
        target_dir="$HOME/.config/vguard"
        target_file="$target_dir/vguard.conf"
        msg_info "Instalando configuración a nivel de usuario en: $target_file"
    else
        msg_info "Instalando configuración a nivel de sistema en: $target_file"
    fi

    mkdir -p "$target_dir/policies"

    if [ -f "$target_file" ]; then
        msg_warning "El archivo $target_file ya existe."
        read -p "¿Deseas sobrescribirlo con la plantilla v3.0 por defecto? (s/N): " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            msg_info "Operación cancelada."
            return 0
        fi
    fi

    local template_source="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../config/vguard.conf.example"
    local policies_dir="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../config/policies"

    if [ -f "$template_source" ]; then
        cp "$template_source" "$target_file"
        if [ -d "$policies_dir" ]; then
            cp -r "$policies_dir"/* "$target_dir/policies/" 2>/dev/null || true
        fi
        msg_success "Configuración e plantillas v3.0 inicializadas correctamente en: $target_file"
    else
        msg_error "No se encontró la plantilla de configuración en $template_source"
        return 1
    fi
}
