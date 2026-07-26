#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE CARGA DE CONFIGURACIÓN Y POLÍTICAS
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

    # Cargar variables del archivo de configuración
    # shellcheck source=/dev/null
    source "$CONFIG_FILE"

    # Establecer valores predeterminados de seguridad si faltan
    VG_NAME="${VG_NAME:-fedora_server}"
    PATH_HDD_SERVICIOS="${PATH_HDD_SERVICIOS:-/mnt/sda1/servicios}"
    PATH_HDD_COMPARTIDO="${PATH_HDD_COMPARTIDO:-/mnt/sda1/compartido}"
    PATH_HDD_SISTEMA="${PATH_HDD_SISTEMA:-/mnt/sda1/sistema}"
    PATH_NVME_FAST="${PATH_NVME_FAST:-/mnt/nvme_fast}"
    VGUARD_OWNER="${VGUARD_OWNER:-vsynlo:vsynlo}"
    META_FILE="${META_FILE:-.vguard_meta}"
    
    SELINUX_CONTAINER="${SELINUX_CONTAINER:-container_file_t}"
    SELINUX_NETWORK="${SELINUX_NETWORK:-samba_share_t}"
    SELINUX_SYSTEM="${SELINUX_SYSTEM:-systemd_system_unit_t}"

    PERM_POSIX_CONTAINER="${PERM_POSIX_CONTAINER:-770}"
    PERM_POSIX_NETWORK="${PERM_POSIX_NETWORK:-775}"
    PERM_POSIX_SYSTEM="${PERM_POSIX_SYSTEM:-750}"
}

init_config() {
    local target_dir="/etc/vguard"
    local target_file="$target_dir/vguard.conf"

    msg_section "INICIALIZACIÓN DE CONFIGURACIÓN VGUARD"

    if [ "$EUID" -ne 0 ]; then
        target_dir="$HOME/.config/vguard"
        target_file="$target_dir/vguard.conf"
        msg_info "Instalando configuración a nivel de usuario en: $target_file"
    else
        msg_info "Instalando configuración a nivel de sistema en: $target_file"
    fi

    mkdir -p "$target_dir"

    if [ -f "$target_file" ]; then
        msg_warning "El archivo $target_file ya existe."
        read -p "¿Deseas sobrescribirlo con la plantilla por defecto? (s/N): " confirm
        if [[ ! "$confirm" =~ ^[sS]$ ]]; then
            msg_info "Operación cancelada."
            return 0
        fi
    fi

    local template_source="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/../config/vguard.conf.example"
    if [ -f "$template_source" ]; then
        cp "$template_source" "$target_file"
        msg_success "Configuración inicializada correctamente en: $target_file"
    else
        msg_error "No se encontró la plantilla de configuración en $template_source"
        return 1
    fi
}
