#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE AUDITORÍA Y AUTO-REPARACIÓN (SELF-HEALING)
# ==============================================================================

auditar_y_reparar_directorio() {
    local ruta_target="$1"
    local solo_auditar="${2:-false}"

    if [ ! -d "$ruta_target" ]; then
        msg_error "El directorio $ruta_target no existe."
        return 1
    fi

    local meta_path="$ruta_target/$META_FILE"

    if [ ! -f "$meta_path" ]; then
        msg_warning "No se encontró el archivo de metadatos ($META_FILE) en: $ruta_target"
        msg_info "Esta carpeta no es gestionada por VGUARD o el archivo de metadatos fue eliminado."
        return 1
    fi

    # Cargar metadatos declarativos del directorio
    # Limpiar variables previas por seguridad
    VGUARD_SERVICE_NAME=""
    VGUARD_TIER=""
    VGUARD_OWNER=""
    VGUARD_POSIX=""
    VGUARD_SELINUX=""

    # Compatibilidad con variables antiguas (.storage_meta.env)
    OWNER_CORRECTO=""
    PERMISO_POSIX=""
    CONTEXTO_SELINUX=""

    # shellcheck source=/dev/null
    source "$meta_path"

    # Mapear compatibilidad si proviene de versión legacy
    local target_owner="${VGUARD_OWNER:-$OWNER_CORRECTO}"
    local target_posix="${VGUARD_POSIX:-$PERMISO_POSIX}"
    local target_selinux="${VGUARD_SELINUX:-$CONTEXTO_SELINUX}"
    local target_tier="${VGUARD_TIER:-$TIPO_USO}"
    local target_service="${VGUARD_SERVICE_NAME:-$(basename "$ruta_target")}"

    draw_separator
    msg_info "Evaluando estado declarativo para: ${CLR_BOLD}$target_service${CLR_RESET}"
    msg_info "Ruta: $ruta_target"
    msg_info "Perfil: [$target_tier]"
    msg_info "Estado Deseado:"
    echo "  - Propietario: $target_owner"
    echo "  - Permisos POSIX: $target_posix"
    echo "  - Contexto SELinux: $target_selinux"

    if [ "$solo_auditar" = "true" ]; then
        # Verificar propietario actual
        local current_owner
        current_owner=$(stat -c '%U:%G' "$ruta_target" 2>/dev/null || echo "Desconocido")
        
        # Verificar permisos POSIX actuales
        local current_posix
        current_posix=$(stat -c '%a' "$ruta_target" 2>/dev/null || echo "Desconocido")

        # Verificar contexto SELinux actual
        local current_selinux
        current_selinux=$(ls -Zd "$ruta_target" 2>/dev/null | awk '{print $1}' | cut -d: -f3 || echo "Desconocido")

        local tiene_desviacion=false
        echo -e "\n${CLR_BOLD}Detección de Desviaciones:${CLR_RESET}"
        if [ "$current_owner" != "$target_owner" ]; then
            echo -e "  - Propietario:  ${CLR_RED}$current_owner${CLR_RESET} (Esperado: $target_owner) ${CLR_RED}[X] DESVIACIÓN${CLR_RESET}"
            tiene_desviacion=true
        else
            echo -e "  - Propietario:  ${CLR_GREEN}$current_owner${CLR_RESET} [OK]"
        fi

        if [ "$current_posix" != "$target_posix" ]; then
            echo -e "  - Permisos POSIX: ${CLR_RED}$current_posix${CLR_RESET} (Esperado: $target_posix) ${CLR_RED}[X] DESVIACIÓN${CLR_RESET}"
            tiene_desviacion=true
        else
            echo -e "  - Permisos POSIX: ${CLR_GREEN}$current_posix${CLR_RESET} [OK]"
        fi

        if [ -n "$target_selinux" ] && [ "$target_selinux" != "N/A" ]; then
            if [[ "$current_selinux" != *"$target_selinux"* ]]; then
                echo -e "  - Contexto SELinux: ${CLR_YELLOW}$current_selinux${CLR_RESET} (Esperado: $target_selinux) ${CLR_YELLOW}[!] DESVIACIÓN${CLR_RESET}"
                tiene_desviacion=true
            else
                echo -e "  - Contexto SELinux: ${CLR_GREEN}$current_selinux${CLR_RESET} [OK]"
            fi
        fi

        if [ "$tiene_desviacion" = "true" ]; then
            msg_warning "Se detectaron desviaciones de permisos. Ejecuta 'vguard heal $ruta_target' para restaurar."
        else
            msg_success "El estado del volumen está alineado al 100% con las políticas."
        fi
        return 0
    fi

    # Ejecutar restauración / sanación
    msg_section "EJECUTANDO REPARACIÓN DE ESTADO (SELF-HEALING)"
    aplicar_permisos "$ruta_target" "$target_owner" "$target_posix" "$target_selinux"

    # Re-proteger metadatos
    chmod 600 "$meta_path"
    if [ "$EUID" -eq 0 ]; then
        chown root:root "$meta_path"
    fi

    msg_success "Reparación completada. Permisos y contextos SELinux restaurados correctamente."
}

reparar_almacenamiento() {
    local ruta="$1"

    if [ -z "$ruta" ]; then
        msg_section "AUDITORÍA Y REPARACIÓN DE PERMISOS"
        read -p "Ingresa la ruta absoluta a reparar (ej. /mnt/sda1/servicios/gitea): " ruta
    fi

    if [ -z "$ruta" ]; then
        msg_error "Ruta no especificada."
        return 1
    fi

    auditar_y_reparar_directorio "$ruta" "false"
}
