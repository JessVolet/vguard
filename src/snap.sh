#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE SNAPSHOTS LVM Y RESTAURACIÓN (SNAP / ROLLBACK)
# ==============================================================================

crear_snapshot() {
    local nombre_servicio="$1"
    local tamano_snap="${2:-5G}"

    if [ -z "$nombre_servicio" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            nombre_servicio="$CTX_SERVICE_NAME"
            msg_info "Usando servicio activo del Workspace: $nombre_servicio"
        else
            msg_section "CREACIÓN DE SNAPSHOT LVM"
            read -p "Ingresa el nombre del servicio (ej. redis_prod, mysql_prod): " nombre_servicio
        fi
    fi

    if [ "$EUID" -ne 0 ]; then
        msg_error "La gestión de Snapshots LVM requiere ejecutar con sudo/root."
        return 1
    fi

    local lv_target="${nombre_servicio}_data"
    local snap_name="${nombre_servicio}_snap_$(date +%Y%m%d_%H%M%S)"

    msg_info "Verificando existencia del volumen /dev/$VG_NAME/$lv_target..."
    if ! lvs "/dev/$VG_NAME/$lv_target" >/dev/null 2>&1; then
        msg_error "El volumen LVM /dev/$VG_NAME/$lv_target no existe."
        return 1
    fi

    msg_info "Creando Snapshot LVM de $tamano_snap: $snap_name..."
    if lvcreate -s -n "$snap_name" -L "$tamano_snap" "/dev/$VG_NAME/$lv_target"; then
        draw_separator
        msg_success "Snapshot creado exitosamente:"
        echo "  - Servicio: $nombre_servicio"
        echo "  - Snapshot LV: /dev/$VG_NAME/$snap_name"
        echo "  - Tamaño reservado: $tamano_snap"
        draw_separator
    else
        msg_error "Error al crear el snapshot LVM."
        return 1
    fi
}

listar_snapshots() {
    msg_section "SNAPSHOTS LVM ACTIVOS EN VOLUME GROUP ($VG_NAME)"

    if [ "$EUID" -ne 0 ]; then
        msg_error "Se requieren privilegios sudo/root para listar snapshots LVM."
        return 1
    fi

    if command -v lvs >/dev/null 2>&1; then
        lvs -o lv_name,origin,lv_size,data_percent "$VG_NAME" | grep "_snap_" || msg_info "No hay snapshots LVM activos en $VG_NAME."
    else
        msg_error "Comando 'lvs' no disponible en el sistema."
    fi
}

revertir_snapshot() {
    local snap_name="$1"

    if [ -z "$snap_name" ]; then
        msg_section "REVERTIR SNAPSHOT LVM (ROLLBACK)"
        read -p "Ingresa el nombre exacto del Snapshot a revertir: " snap_name
    fi

    if [ "$EUID" -ne 0 ]; then
        msg_error "El rollback de LVM requiere ejecutar con sudo/root."
        return 1
    fi

    msg_warning "¡ATENCIÓN! Revertir un snapshot sobrescribirá los datos actuales con el estado de la foto."
    read -p "¿Estás seguro de continuar con el rollback de /dev/$VG_NAME/$snap_name? (s/N): " confirm
    if [[ ! "$confirm" =~ ^[sS]$ ]]; then
        msg_info "Rollback cancelado."
        return 0
    fi

    msg_info "Ejecutando lvconvert --merge /dev/$VG_NAME/$snap_name..."
    if lvconvert --merge "/dev/$VG_NAME/$snap_name"; then
        msg_success "Rollback completado con éxito. Es posible que debas reiniciar o desmontar/montar el volumen."
    else
        msg_error "Error al ejecutar el rollback del snapshot."
        return 1
    fi
}
