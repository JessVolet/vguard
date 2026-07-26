#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE AUDITORÍA GLOBAL Y ESTADO (STATUS / LIST / HEAL-ALL)
# ==============================================================================

listar_volumenes_gestionados() {
    msg_section "AUDITORÍA GLOBAL DE ALMACENAMIENTO VGUARD"

    local active_mount=""
    if cargar_contexto >/dev/null 2>&1; then
        active_mount="$CTX_MOUNT_POINT"
    fi

    local base_paths=(
        "$PATH_HDD_SERVICIOS"
        "$PATH_NVME_FAST"
        "$PATH_HDD_COMPARTIDO"
        "$PATH_HDD_SISTEMA"
    )

    local found_count=0

    printf "%-22s %-16s %-9s %-10s %-8s %-10s\n" "SERVICIO" "TIER" "TAMAÑO" "OWNER" "PERMS" "ESTADO"
    draw_separator

    for base in "${base_paths[@]}"; do
        if [ ! -d "$base" ]; then
            continue
        fi

        while IFS= read -r dir; do
            [ -z "$dir" ] && continue
            found_count=$((found_count + 1))

            local meta_file="$dir/$META_FILE"
            if [ ! -f "$meta_file" ] && [ -f "$dir/.storage_meta.env" ]; then
                meta_file="$dir/.storage_meta.env"
            fi

            VGUARD_SERVICE_NAME=""
            VGUARD_TIER=""
            VGUARD_OWNER=""
            VGUARD_POSIX=""
            OWNER_CORRECTO=""
            PERMISO_POSIX=""
            TIPO_USO=""

            # shellcheck source=/dev/null
            source "$meta_file" 2>/dev/null

            local service_name="${VGUARD_SERVICE_NAME:-$(basename "$dir")}"
            local tier="${VGUARD_TIER:-${TIPO_USO:-Desconocido}}"
            local exp_owner="${VGUARD_OWNER:-$OWNER_CORRECTO}"
            local exp_posix="${VGUARD_POSIX:-$PERMISO_POSIX}"

            local is_active=""
            if [ -n "$active_mount" ] && [ "$dir" = "$active_mount" ]; then
                is_active=" [ACTIVE]"
            fi

            local disk_usage
            disk_usage=$(du -sh "$dir" 2>/dev/null | awk '{print $1}')
            [ -z "$disk_usage" ] && disk_usage="N/A"

            local actual_owner
            actual_owner=$(stat -c '%U:%G' "$dir" 2>/dev/null || echo "???")

            local actual_posix
            actual_posix=$(stat -c '%a' "$dir" 2>/dev/null || echo "???")

            local health_status="${CLR_GREEN}HEALTHY${CLR_RESET}"
            if [ "$actual_owner" != "$exp_owner" ] || [ "$actual_posix" != "$exp_posix" ]; then
                health_status="${CLR_RED}DRIFTED${CLR_RESET}"
            fi

            local display_name="${service_name:0:15}${is_active}"

            printf "%-22s %-16s %-9s %-10s %-8s %b\n" \
                "$display_name" \
                "${tier:0:15}" \
                "$disk_usage" \
                "${actual_owner:0:9}" \
                "$actual_posix" \
                "$health_status"

        done < <(find "$base" -maxdepth 2 -type f \( -name "$META_FILE" -o -name ".storage_meta.env" \) -exec dirname {} \;)
    done

    draw_separator
    if [ "$found_count" -eq 0 ]; then
        msg_info "No se encontraron volúmenes ni carpetas gestionadas por VGUARD."
        msg_info "Usa 'vguard create' para crear tu primer servicio asegurado."
    else
        msg_success "Total de volúmenes gestionados encontrados: $found_count"
    fi
}

sanar_todos_los_volumenes() {
    msg_section "AUDITORÍA Y AUTOCURACIÓN GLOBAL (HEAL-ALL)"

    local base_paths=(
        "$PATH_HDD_SERVICIOS"
        "$PATH_NVME_FAST"
        "$PATH_HDD_COMPARTIDO"
        "$PATH_HDD_SISTEMA"
    )

    local processed_count=0

    for base in "${base_paths[@]}"; do
        if [ ! -d "$base" ]; then
            continue
        fi

        while IFS= read -r dir; do
            [ -z "$dir" ] && continue
            processed_count=$((processed_count + 1))
            auditar_y_reparar_directorio "$dir" "false"
        done < <(find "$base" -maxdepth 2 -type f \( -name "$META_FILE" -o -name ".storage_meta.env" \) -exec dirname {} \;)
    done

    draw_separator
    msg_success "Proceso heal-all completado. Se auditaron y restauraron $processed_count volúmenes."
    draw_separator
}
