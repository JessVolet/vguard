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
