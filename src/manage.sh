#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE MANIPULACIÓN Y EDICIÓN DE VOLÚMENES Y CARPETAS (MANAGE)
# ==============================================================================

renombrar_almacenamiento() {
    local target_input="$1"
    local nuevo_nombre="$2"

    msg_section "RENOMBRAR SERVICIO Y ALMACENAMIENTO"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
            msg_info "Usando objetivo activo del Workspace: $CTX_SERVICE_NAME ($target_input)"
        else
            read -p "Ingresa el nombre o ruta del servicio actual a renombrar: " target_input
        fi
    fi

    local ruta_actual=""
    if [ -d "$target_input" ]; then
        ruta_actual="$target_input"
    else
        local base_paths=(
            "$PATH_HDD_SERVICIOS/$target_input"
            "$PATH_NVME_FAST/$target_input"
            "$PATH_HDD_COMPARTIDO/$target_input"
            "$PATH_HDD_SISTEMA/$target_input"
        )
        for path in "${base_paths[@]}"; do
            if [ -d "$path" ]; then
                ruta_actual="$path"
                break
            fi
        done
    fi

    if [ -z "$ruta_actual" ] || [ ! -d "$ruta_actual" ]; then
        msg_error "El directorio o servicio '$target_input' no existe."
        return 1
    fi

    local meta_file="$ruta_actual/$META_FILE"
    if [ ! -f "$meta_file" ]; then
        msg_error "No se encontró el archivo de metadatos ($META_FILE) en $ruta_actual."
        return 1
    fi

    # Cargar metadatos actuales
    VGUARD_SERVICE_NAME=""
    VGUARD_TIER=""
    VGUARD_OWNER=""
    VGUARD_POSIX=""
    VGUARD_SELINUX=""
    VGUARD_LV_PATH=""
    # shellcheck source=/dev/null
    source "$meta_file"

    local nombre_actual="${VGUARD_SERVICE_NAME:-$(basename "$ruta_actual")}"

    if [ -z "$nuevo_nombre" ]; then
        read -p "Ingresa el nuevo nombre para el servicio '$nombre_actual': " nuevo_nombre
    fi

    nuevo_nombre=$(echo "$nuevo_nombre" | tr -cd 'a-zA-Z0-9_-')
    if [ -z "$nuevo_nombre" ]; then
        msg_error "Nuevo nombre de servicio inválido."
        return 1
    fi

    local parent_dir
    parent_dir="$(dirname "$ruta_actual")"
    local ruta_nueva="$parent_dir/$nuevo_nombre"

    if [ -d "$ruta_nueva" ]; then
        msg_error "Ya existe un directorio en el destino: $ruta_nueva"
        return 1
    fi

    msg_info "Renombrando de '$nombre_actual' ($ruta_actual) a '$nuevo_nombre' ($ruta_nueva)..."

    # Manejo si tiene Volumen Lógico LVM asignado
    if [ -n "$VGUARD_LV_PATH" ] && [ "$VGUARD_LV_PATH" != "N/A" ]; then
        if [ "$EUID" -ne 0 ]; then
            msg_error "Renombrar volúmenes LVM requiere ejecutarse con sudo/root."
            return 1
        fi

        local nuevo_lv_path="/dev/$VG_NAME/${nuevo_nombre}_data"

        msg_info "Desmontando volumen temporalmente..."
        umount "$ruta_actual" 2>/dev/null || true

        msg_info "Renombrando Logical Volume LVM en Volume Group $VG_NAME..."
        if lvrename "$VG_NAME" "${nombre_actual}_data" "${nuevo_nombre}_data"; then
            msg_success "Volumen LVM renombrado a $nuevo_lv_path"
        else
            msg_error "Error al renombrar el volumen LVM."
            return 1
        fi

        msg_info "Actualizando entradas en /etc/fstab..."
        sed -i "s|$VGUARD_LV_PATH $ruta_actual|$nuevo_lv_path $ruta_nueva|g" /etc/fstab
        sed -i "s|$ruta_actual|$ruta_nueva|g" /etc/fstab

        mv "$ruta_actual" "$ruta_nueva"

        systemctl daemon-reload 2>/dev/null || true
        mount -a
        VGUARD_LV_PATH="$nuevo_lv_path"
    else
        mv "$ruta_actual" "$ruta_nueva"
    fi

    # Actualizar metadatos
    escribir_metadatos "$ruta_nueva" "$nuevo_nombre" "$VGUARD_TIER" "$VGUARD_OWNER" "$VGUARD_POSIX" "$VGUARD_SELINUX" "$VGUARD_LV_PATH"

    # Reaplicar contextos y permisos en la nueva ruta
    aplicar_permisos "$ruta_nueva" "$VGUARD_OWNER" "$VGUARD_POSIX" "$VGUARD_SELINUX"

    if cargar_contexto >/dev/null 2>&1 && [ "$CTX_MOUNT_POINT" = "$ruta_actual" ]; then
        guardar_contexto "$nuevo_nombre" "$VGUARD_TIER" "$ruta_nueva" "$VGUARD_LV_PATH" "$VGUARD_OWNER" "$VGUARD_POSIX" "$VGUARD_SELINUX"
        msg_info "Contexto activo actualizado a la nueva ruta y nombre."
    fi

    msg_success "Almacenamiento renombrado exitosamente a: $ruta_nueva"
}

redimensionar_volumen() {
    local target_input="$1"
    local nuevo_tamano="$2"

    msg_section "REDIMENSIONAR VOLUMEN LVM (RESIZE / EXTEND)"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
            msg_info "Usando objetivo activo del Workspace: $CTX_SERVICE_NAME ($target_input)"
        else
            read -p "Ingresa el nombre o ruta del servicio LVM a redimensionar: " target_input
        fi
    fi

    local ruta_actual=""
    if [ -d "$target_input" ]; then
        ruta_actual="$target_input"
    else
        ruta_actual="$PATH_NVME_FAST/$target_input"
    fi

    if [ ! -d "$ruta_actual" ]; then
        msg_error "El directorio o servicio '$target_input' no existe."
        return 1
    fi

    local meta_file="$ruta_actual/$META_FILE"
    if [ ! -f "$meta_file" ]; then
        msg_error "No se encontró el archivo de metadatos ($META_FILE) en $ruta_actual."
        return 1
    fi

    VGUARD_LV_PATH=""
    # shellcheck source=/dev/null
    source "$meta_file"

    if [ -z "$VGUARD_LV_PATH" ] || [ "$VGUARD_LV_PATH" = "N/A" ]; then
        msg_error "Este servicio no está asociado a un Logical Volume LVM en NVMe."
        return 1
    fi

    if [ "$EUID" -ne 0 ]; then
        msg_error "La extensión de volúmenes LVM requiere privilegios sudo/root."
        return 1
    fi

    if [ -z "$nuevo_tamano" ]; then
        read -p "Ingresa la cantidad a extender o el nuevo tamaño (ej. +10G, 30G): " nuevo_tamano
    fi

    if [ -z "$nuevo_tamano" ]; then
        msg_error "Especificación de tamaño no válida."
        return 1
    fi

    msg_info "Extendiendo Logical Volume $VGUARD_LV_PATH..."
    if [[ "$nuevo_tamano" == +* ]]; then
        lvextend -L "$nuevo_tamano" "$VGUARD_LV_PATH"
    else
        lvextend -L "$nuevo_tamano" "$VGUARD_LV_PATH" || lvextend -L "+$nuevo_tamano" "$VGUARD_LV_PATH"
    fi

    msg_info "Redimensionando sistema de archivos XFS en caliente..."
    if xfs_growfs "$ruta_actual"; then
        msg_success "Sistema de archivos extendido exitosamente en $ruta_actual."
    else
        msg_warning "No se pudo ejecutar xfs_growfs. Es posible que el sistema de archivos sea ext4 (probando resize2fs)..."
        resize2fs "$VGUARD_LV_PATH" || true
    fi

    msg_success "Redimensionamiento completado con éxito."
}

crear_subcarpeta() {
    local target_input="$1"
    local subcarpeta="$2"

    msg_section "CREAR SUBCARPETA CON HERENCIA DE POLÍTICAS"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
            msg_info "Usando objetivo activo del Workspace: $CTX_SERVICE_NAME ($target_input)"
        else
            read -p "Ingresa el nombre o ruta del servicio principal: " target_input
        fi
    fi

    local ruta_actual=""
    if [ -d "$target_input" ]; then
        ruta_actual="$target_input"
    else
        local base_paths=(
            "$PATH_HDD_SERVICIOS/$target_input"
            "$PATH_NVME_FAST/$target_input"
            "$PATH_HDD_COMPARTIDO/$target_input"
            "$PATH_HDD_SISTEMA/$target_input"
        )
        for path in "${base_paths[@]}"; do
            if [ -d "$path" ]; then
                ruta_actual="$path"
                break
            fi
        done
    fi

    if [ -z "$ruta_actual" ] || [ ! -d "$ruta_actual" ]; then
        msg_error "El servicio o ruta '$target_input' no existe."
        return 1
    fi

    local meta_file="$ruta_actual/$META_FILE"
    if [ ! -f "$meta_file" ]; then
        msg_warning "No se encontraron metadatos en $ruta_actual. Se usarán las políticas globales por defecto."
    fi

    VGUARD_OWNER="${VGUARD_OWNER:-$VGUARD_OWNER}"
    VGUARD_POSIX="${VGUARD_POSIX:-770}"
    VGUARD_SELINUX="${VGUARD_SELINUX:-container_file_t}"
    # shellcheck source=/dev/null
    source "$meta_file" 2>/dev/null

    if [ -z "$subcarpeta" ]; then
        read -p "Ingresa el nombre de la subcarpeta a crear (ej. repos, backups, config): " subcarpeta
    fi

    if [ -z "$subcarpeta" ]; then
        msg_error "Subcarpeta no válida."
        return 1
    fi

    local ruta_subcarpeta="$ruta_actual/$subcarpeta"
    msg_info "Creando subcarpeta $ruta_subcarpeta..."
    mkdir -p "$ruta_subcarpeta"

    msg_info "Aplicando herencia de propietario ($VGUARD_OWNER), permisos ($VGUARD_POSIX) y SELinux ($VGUARD_SELINUX)..."
    aplicar_permisos "$ruta_subcarpeta" "$VGUARD_OWNER" "$VGUARD_POSIX" "$VGUARD_SELINUX"

    msg_success "Subcarpeta creada y asegurada correctamente en: $ruta_subcarpeta"
}

gestionar_almacenamiento() {
    msg_section "ADMINISTRACIÓN Y EDICIÓN DE VOLÚMENES"
    echo "1) Renombrar un servicio o carpeta"
    echo "2) Redimensionar un volumen LVM (NVMe)"
    echo "3) Crear una subcarpeta asegurada (con herencia de permisos)"
    read -p "Selecciona una opción (1-3): " opcion_gestion

    case "$opcion_gestion" in
        1) renombrar_almacenamiento ;;
        2) redimensionar_volumen ;;
        3) crear_subcarpeta ;;
        *) msg_error "Opción inválida."; return 1 ;;
    esac
}
