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
            source "$meta_file" 2>/dev/null || true

            local fallback_name
            fallback_name="$(basename "${dir%/}")"

            local raw_service_name="${VGUARD_SERVICE_NAME:-$fallback_name}"
            raw_service_name="${raw_service_name%/}"
            raw_service_name="${raw_service_name%/.}"
            raw_service_name="${raw_service_name%/}"
            raw_service_name="${raw_service_name%.}"

            local service_name
            service_name="$(basename "$raw_service_name")"
            if [ -z "$service_name" ] || [ "$service_name" = "." ]; then
                service_name="$fallback_name"
            fi

            # Obtener política declarativa global SSOT desde vguard.conf
            obtener_politica_volumen "$service_name" ""
            local exp_owner="$POL_OWNER:$POL_GROUP"
            local exp_posix="$POL_MODE_DIR"

            # Si existía metadato local, cargarlo solo para el Tier/Nombre visual si aplica
            local tier="${VGUARD_TIER:-${TIPO_USO:-custom}}"

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

            local clean_actual_posix="${actual_posix: -3}"
            local clean_exp_posix="${exp_posix: -3}"

            # Validar propietario de forma inteligente (normaliza UID numérico vs nombre)
            local py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"
            local owner_matches="false"
            if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
                owner_matches=$(python3 "$py_helper" check-owner "$dir" "$exp_owner" 2>/dev/null || echo "false")
            else
                local actual_num=$(stat -c '%u:%g' "$dir" 2>/dev/null || echo "")
                if [ "$actual_owner" = "$exp_owner" ] || [ "$actual_num" = "$exp_owner" ]; then
                    owner_matches="true"
                fi
            fi

            local health_status="${CLR_GREEN}HEALTHY${CLR_RESET}"
            if [ "$owner_matches" != "true" ] || [ "$clean_actual_posix" != "$clean_exp_posix" ]; then
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
    
    # Check for updates silently in the background (timeout 1s to avoid blocking)
    # shellcheck source=/dev/null
    source "$(dirname "$(realpath "${BASH_SOURCE[0]}")")/update.sh" 2>/dev/null || true
    if command -v chequear_actualizaciones_vguard >/dev/null 2>&1; then
        chequear_actualizaciones_vguard "true" &
        # We don't wait for it. It might print to terminal slightly after, which is fine for CLI background checks.
        wait $! 2>/dev/null || true
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
    msg_success "Proceso Heal-All completado. Se procesaron $processed_count volúmenes."
}

auditar_logs_selinux() {
    local target_input="$1"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
        else
            read -p "Ingresa el nombre o ruta del servicio para inspeccionar logs SELinux: " target_input
        fi
    fi

    local ruta_target=""
    if [ -d "$target_input" ]; then
        ruta_target="$(realpath "$target_input")"
    else
        local base_paths=(
            "$PATH_HDD_SERVICIOS/$target_input"
            "$PATH_NVME_FAST/$target_input"
            "$PATH_HDD_COMPARTIDO/$target_input"
            "$PATH_HDD_SISTEMA/$target_input"
        )
        for path in "${base_paths[@]}"; do
            if [ -d "$path" ]; then
                ruta_target="$(realpath "$path")"
                break
            fi
        done
    fi

    local vol_name="$(basename "${ruta_target:-$target_input}")"

    draw_separator
    echo -e "${CLR_BOLD}${CLR_CYAN} AUDITORÍA Y LOGS SELINUX (AVC DENIALS) // $vol_name ${CLR_RESET}"
    draw_separator

    local avc_found=false

    if command -v ausearch >/dev/null 2>&1; then
        msg_info "Buscando denegaciones AVC con ausearch..."
        local logs_avc
        logs_avc=$(ausearch -m avc 2>/dev/null | grep -E "$vol_name|$ruta_target" | tail -n 20 || true)
        if [ -n "$logs_avc" ]; then
            echo -e "${CLR_RED}$logs_avc${CLR_RESET}"
            avc_found=true
        fi
    fi

    if [ "$avc_found" = "false" ] && [ -f "/var/log/audit/audit.log" ]; then
        msg_info "Analizando /var/log/audit/audit.log..."
        local logs_audit
        logs_audit=$(grep -i "denied" /var/log/audit/audit.log 2>/dev/null | grep -E "$vol_name|$ruta_target" | tail -n 20 || true)
        if [ -n "$logs_audit" ]; then
            echo -e "${CLR_YELLOW}$logs_audit${CLR_RESET}"
            avc_found=true
        fi
    fi

    if [ "$avc_found" = "false" ] && command -v journalctl >/dev/null 2>&1; then
        msg_info "Consultando journalctl en busca de auditd denegados..."
        local logs_journal
        logs_journal=$(journalctl -t audit -o cat 2>/dev/null | grep -i "denied" | grep -E "$vol_name|$ruta_target" | tail -n 15 || true)
        if [ -n "$logs_journal" ]; then
            echo -e "${CLR_YELLOW}$logs_journal${CLR_RESET}"
            avc_found=true
        fi
    fi

    if [ "$avc_found" = "false" ]; then
        msg_success "No se detectaron denegaciones SELinux (AVC Denials) para '$vol_name'."
    fi
    draw_separator
}
