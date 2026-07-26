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

    msg_info "Obteniendo últimas actualizaciones desde el repositorio Git remoto..."
    if (cd "$repo_dir" && git pull); then
        msg_success "Repositorio Git actualizado correctamente."
    else
        msg_error "Error al ejecutar 'git pull'. Revisa la conexión o cambios pendientes en Git."
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
