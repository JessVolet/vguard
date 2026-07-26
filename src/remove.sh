#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE ELIMINACIÓN SEGURA DE SERVICIOS Y VOLÚMENES (REMOVE / RM)
# ==============================================================================

remover_almacenamiento() {
    local target_input="$1"

    msg_section "ELIMINACIÓN SEGURA DE ALMACENAMIENTO (REMOVE)"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
            msg_info "Usando objetivo activo del Workspace: $CTX_SERVICE_NAME ($target_input)"
        else
            read -p "Ingresa la ruta absoluta o el nombre del servicio a eliminar: " target_input
        fi
    fi

    if [ -z "$target_input" ]; then
        msg_error "No se especificó ninguna ruta ni nombre de servicio."
        return 1
    fi

    local ruta_target=""
    local lv_target=""
    local meta_path=""

    # Determinar si se pasó una ruta directa o un nombre de servicio
    if [ -d "$target_input" ]; then
        ruta_target="$target_input"
    else
        # Buscar en las rutas base configuradas
        local base_paths=(
            "$PATH_HDD_SERVICIOS/$target_input"
            "$PATH_NVME_FAST/$target_input"
            "$PATH_HDD_COMPARTIDO/$target_input"
            "$PATH_HDD_SISTEMA/$target_input"
        )
        for path in "${base_paths[@]}"; do
            if [ -d "$path" ]; then
                ruta_target="$path"
                break
            fi
        done
    fi

    if [ -z "$ruta_target" ] || [ ! -d "$ruta_target" ]; then
        msg_error "El directorio o servicio '$target_input' no existe o no fue encontrado."
        return 1
    fi

    meta_path="$ruta_target/$META_FILE"
    if [ ! -f "$meta_path" ] && [ -f "$ruta_target/.storage_meta.env" ]; then
        meta_path="$ruta_target/.storage_meta.env"
    fi

    if [ -f "$meta_path" ]; then
        # Cargar metadatos para verificar si está vinculado a un LVM
        VGUARD_LV_PATH=""
        # shellcheck source=/dev/null
        source "$meta_path" 2>/dev/null
        lv_target="${VGUARD_LV_PATH:-N/A}"
    fi

    msg_warning "Se procederá a evaluar la eliminación del siguiente almacenamiento:"
    echo "  - Ruta en Host: $ruta_target"
    if [ -n "$lv_target" ] && [ "$lv_target" != "N/A" ]; then
        echo "  - Volumen Lógico LVM: $lv_target"
    fi

    draw_separator
    # PRIMERA CONFIRMACIÓN
    read -p "¿Estás seguro de que deseas eliminar este almacenamiento y TODOS sus datos? (s/N): " confirm1
    if [[ ! "$confirm1" =~ ^[sS]$ ]]; then
        msg_info "Operación cancelada en la primera confirmación."
        return 0
    fi

    # SEGUNDA CONFIRMACIÓN (DOBLE CHECK DE SEGURIDAD)
    msg_warning "[!] VERIFICACIÓN DE SEGURIDAD SECUNDARIA [!]"
    msg_warning "¡ATENCIÓN! Esta acción destruirá permanentemente los datos sin posibilidad de recuperación."
    read -p "Para confirmar definitivamente, escribe 'DESTRUIR': " confirm2

    if [ "$confirm2" != "DESTRUIR" ]; then
        msg_info "Texto de confirmación incorrecto. Operación cancelada por seguridad."
        return 0
    fi

    msg_info "Iniciando proceso de eliminación..."

    # Si hay un volumen LVM asociado o montado
    if [ -n "$lv_target" ] && [ "$lv_target" != "N/A" ]; then
        if [ "$EUID" -ne 0 ]; then
            msg_error "Se requieren privilegios root/sudo para desmontar y eliminar volúmenes LVM."
            return 1
        fi

        msg_info "Desmontando punto de montaje $ruta_target..."
        umount "$ruta_target" 2>/dev/null || true

        msg_info "Removiendo entrada de /etc/fstab si existe..."
        sed -i "\| $ruta_target |d" /etc/fstab
        sed -i "\|$lv_target|d" /etc/fstab
        systemctl daemon-reload 2>/dev/null || true

        msg_info "Eliminando Volumen Lógico LVM $lv_target..."
        if lvremove -f "$lv_target"; then
            msg_success "Volumen Lógico LVM eliminado correctamente."
        else
            msg_warning "No se pudo eliminar el volumen LVM $lv_target (puede que no exista o esté ocupado)."
        fi
    fi

    msg_info "Eliminando carpeta y datos de $ruta_target..."
    if rm -rf "$ruta_target"; then
        draw_separator
        msg_success "Almacenamiento y datos eliminados correctamente de: $ruta_target"
        if cargar_contexto >/dev/null 2>&1 && [ "$CTX_MOUNT_POINT" = "$ruta_target" ]; then
            limpiar_contexto >/dev/null 2>&1 || true
        fi
        draw_separator
    else
        msg_error "Error al eliminar el directorio $ruta_target"
        return 1
    fi
}
