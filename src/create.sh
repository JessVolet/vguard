#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE CREACIÓN DE CARPETAS Y VOLÚMENES LVM
# ==============================================================================

aplicar_permisos() {
    local ruta="$1"
    local owner="$2"
    local posix="$3"
    local selinux="$4"

    msg_info "Aplicando propietario ($owner) a $ruta..."
    chown -R "$owner" "$ruta" || msg_warning "No se pudo cambiar el propietario a $owner (¿requiere sudo?)"

    msg_info "Aplicando permisos POSIX ($posix) a $ruta..."
    chmod -R "$posix" "$ruta"

    # Verificar si SELinux está activo en el sistema
    if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
        msg_info "Aplicando contexto SELinux ($selinux) a $ruta..."
        if command -v semanage >/dev/null 2>&1; then
            semanage fcontext -a -t "$selinux" "$ruta(/.*)?" 2>/dev/null || true
        fi
        if command -v restorecon >/dev/null 2>&1; then
            restorecon -R -v "$ruta" >/dev/null 2>&1 || true
        fi
    else
        msg_info "SELinux está deshabilitado o no disponible. Omitiendo restorecon."
    fi
}

escribir_metadatos() {
    local ruta="$1"
    local nombre="$2"
    local tipo="$3"
    local owner="$4"
    local posix="$5"
    local selinux="$6"
    local lv_path="${7:-N/A}"

    local meta_path="$ruta/$META_FILE"
    msg_info "Escribiendo metadatos declarativos en $meta_path"

    cat <<EOF > "$meta_path"
# Archivo autogenerado y gestionado por VGUARD
VGUARD_VERSION="1.0"
VGUARD_SERVICE_NAME="$nombre"
VGUARD_TIER="$tipo"
VGUARD_OWNER="$owner"
VGUARD_POSIX="$posix"
VGUARD_SELINUX="$selinux"
VGUARD_MOUNT_POINT="$ruta"
VGUARD_LV_PATH="$lv_path"
VGUARD_CREATED_AT="$(date -Iseconds)"
EOF

    # Proteger el archivo de metadatos contra modificaciones accidentales
    chmod 600 "$meta_path"
    if [ "$EUID" -eq 0 ]; then
        chown root:root "$meta_path"
    fi
}

crear_almacenamiento() {
    msg_section "NUEVO ALMACENAMIENTO / SERVICIO"

    local opcion_tipo="$1"
    local nombre_servicio="$2"
    local tamano_lv="$3"

    if [ -z "$opcion_tipo" ]; then
        echo "Selecciona el tipo de servicio / uso:"
        echo "  1) Datos masivos de contenedor (HDD)    -> Ej. Podman, Repos, WebDAV"
        echo "  2) Base de datos / Alta IOPS (NVMe LVM) -> Ej. MySQL, Redis, PostgreSQL"
        echo "  3) Carpeta compartida en Red (HDD)      -> Ej. Samba, NFS"
        echo "  4) Datos de sistema / Archivos (HDD)    -> Ej. Backups, Logs"
        read -p "Opción (1-4): " opcion_tipo
    fi

    if [ -z "$nombre_servicio" ]; then
        read -p "Nombre del servicio o carpeta (ej. uptime-kuma, redis_prod): " nombre_servicio
    fi

    # Sanitizar nombre
    nombre_servicio=$(echo "$nombre_servicio" | tr -cd 'a-zA-Z0-9_-')
    if [ -z "$nombre_servicio" ]; then
        msg_error "Nombre de servicio inválido."
        return 1
    fi

    local ruta_final=""
    local posix=""
    local selinux=""
    local tipo=""
    local lv_path="N/A"

    case $opcion_tipo in
        1|contenedor_hdd)
            ruta_final="$PATH_HDD_SERVICIOS/$nombre_servicio"
            posix="$PERM_POSIX_CONTAINER"
            selinux="$SELINUX_CONTAINER"
            tipo="contenedor_hdd"

            msg_info "Creando directorio en HDD: $ruta_final"
            mkdir -p "$ruta_final"
            aplicar_permisos "$ruta_final" "$VGUARD_OWNER" "$posix" "$selinux"
            escribir_metadatos "$ruta_final" "$nombre_servicio" "$tipo" "$VGUARD_OWNER" "$posix" "$selinux"
            ;;

        2|lvm_nvme_fast)
            ruta_final="$PATH_NVME_FAST/$nombre_servicio"
            posix="$PERM_POSIX_CONTAINER"
            selinux="$SELINUX_CONTAINER"
            tipo="lvm_nvme_fast"

            if [ -z "$tamano_lv" ]; then
                read -p "Tamaño del Logical Volume (ej. 10G, 50G): " tamano_lv
            fi

            if [ -z "$tamano_lv" ]; then
                msg_error "Tamaño de volumen no especificado."
                return 1
            fi

            if [ "$EUID" -ne 0 ]; then
                msg_error "La creación de volúmenes LVM requiere privilegios de superusuario (sudo/root)."
                return 1
            fi

            lv_path="/dev/$VG_NAME/${nombre_servicio}_data"

            msg_info "Creando Logical Volume de $tamano_lv en Volume Group $VG_NAME..."
            if lvcreate -L "$tamano_lv" -n "${nombre_servicio}_data" "$VG_NAME"; then
                msg_success "Logical Volume creado: $lv_path"
            else
                msg_error "Error al crear el volumen LVM."
                return 1
            fi

            msg_info "Formateando volumen con XFS..."
            mkfs.xfs -f "$lv_path"

            msg_info "Creando punto de montaje $ruta_final..."
            mkdir -p "$ruta_final"

            # Registrar en /etc/fstab si no existe
            if ! grep -q "$lv_path" /etc/fstab; then
                msg_info "Añadiendo entrada a /etc/fstab..."
                echo "$lv_path $ruta_final xfs defaults 0 0" >> /etc/fstab
            fi

            systemctl daemon-reload 2>/dev/null || true
            mount -a

            aplicar_permisos "$ruta_final" "$VGUARD_OWNER" "$posix" "$selinux"
            escribir_metadatos "$ruta_final" "$nombre_servicio" "$tipo" "$VGUARD_OWNER" "$posix" "$selinux" "$lv_path"
            ;;

        3|compartido_red)
            ruta_final="$PATH_HDD_COMPARTIDO/$nombre_servicio"
            posix="$PERM_POSIX_NETWORK"
            selinux="$SELINUX_NETWORK"
            tipo="compartido_red"

            msg_info "Creando directorio compartido en HDD: $ruta_final"
            mkdir -p "$ruta_final"

            # Habilitar bit SGID para herencia de grupo
            chmod g+s "$ruta_final"

            aplicar_permisos "$ruta_final" "$VGUARD_OWNER" "$posix" "$selinux"
            escribir_metadatos "$ruta_final" "$nombre_servicio" "$tipo" "$VGUARD_OWNER" "$posix" "$selinux"
            ;;

        4|sistema_hdd)
            ruta_final="$PATH_HDD_SISTEMA/$nombre_servicio"
            posix="$PERM_POSIX_SYSTEM"
            selinux="$SELINUX_SYSTEM"
            tipo="sistema_hdd"

            msg_info "Creando directorio de sistema en HDD: $ruta_final"
            mkdir -p "$ruta_final"
            aplicar_permisos "$ruta_final" "$VGUARD_OWNER" "$posix" "$selinux"
            escribir_metadatos "$ruta_final" "$nombre_servicio" "$tipo" "$VGUARD_OWNER" "$posix" "$selinux"
            ;;

        *)
            msg_error "Opción de tipo de almacenamiento inválida."
            return 1
            ;;
    esac

    draw_separator
    msg_success "Almacenamiento listo y asegurado en: $ruta_final"
    guardar_contexto "$nombre_servicio" "$tipo" "$ruta_final" "$lv_path" "$VGUARD_OWNER" "$posix" "$selinux"
    msg_info "Objetivo marcado como activo automáticamente en el Workspace."
    draw_separator
}
