#!/bin/bash
# ==============================================================================
# VGUARD v2.0 - MÓDULO DE GESTIÓN DE CONTEXTO ACTIVO (WORKSPACE CONTEXT)
# ==============================================================================

get_context_file() {
    if [ -d "/run" ] && [ -w "/run" ]; then
        mkdir -p "/run/vguard" 2>/dev/null || true
        if [ -w "/run/vguard" ]; then
            echo "/run/vguard/context.json"
            return
        fi
    fi
    local user_dir="$HOME/.config/vguard"
    mkdir -p "$user_dir" 2>/dev/null || true
    echo "$user_dir/context.json"
}

guardar_contexto() {
    local service_name="$1"
    local tier="$2"
    local mount_point="$3"
    local lv_path="${4:-N/A}"
    local owner="${5:-$VGUARD_OWNER}"
    local posix="${6:-770}"
    local selinux="${7:-container_file_t}"

    local ctx_file
    ctx_file="$(get_context_file)"

    cat <<EOF > "$ctx_file"
{
  "service_name": "$service_name",
  "tier": "$tier",
  "mount_point": "$mount_point",
  "lv_path": "$lv_path",
  "owner": "$owner",
  "posix": "$posix",
  "selinux": "$selinux",
  "selected_at": "$(date -Iseconds)"
}
EOF
    chmod 644 "$ctx_file" 2>/dev/null || true
}

cargar_contexto() {
    local ctx_file
    ctx_file="$(get_context_file)"

    if [ ! -f "$ctx_file" ]; then
        return 1
    fi

    # Extraer valores usando tr/grep/awk sin requerir jq externo
    CTX_SERVICE_NAME=$(grep '"service_name"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_TIER=$(grep '"tier"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_MOUNT_POINT=$(grep '"mount_point"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_LV_PATH=$(grep '"lv_path"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_OWNER=$(grep '"owner"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_POSIX=$(grep '"posix"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_SELINUX=$(grep '"selinux"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')
    CTX_SELECTED_AT=$(grep '"selected_at"' "$ctx_file" | head -n1 | awk -F': "' '{print $2}' | awk -F'"' '{print $1}')

    if [ -n "$CTX_MOUNT_POINT" ] && [ -d "$CTX_MOUNT_POINT" ]; then
        return 0
    else
        limpiar_contexto >/dev/null 2>&1 || true
        return 1
    fi
}

limpiar_contexto() {
    local ctx_file
    ctx_file="$(get_context_file)"
    if [ -f "$ctx_file" ]; then
        rm -f "$ctx_file"
    fi
    msg_info "Contexto activo limpiado."
}

seleccionar_contexto() {
    local target_input="$1"
    local sub_target="$2"

    # Soporte para vguard select <storage_tier> <service_name>
    if [ -n "$sub_target" ]; then
        target_input="$sub_target"
    fi

    if [ -z "$target_input" ]; then
        msg_section "SELECCIÓN DE OBJETIVO ACTIVO (SELECT / USE)"
        read -p "Ingresa el nombre o la ruta del servicio a seleccionar: " target_input
    fi

    local ruta_target=""
    if [ -d "$target_input" ]; then
        ruta_target="$target_input"
    else
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
        msg_error "No se encontró el servicio o directorio '$target_input'."
        return 1
    fi

    local meta_path="$ruta_target/$META_FILE"
    if [ ! -f "$meta_path" ] && [ -f "$ruta_target/.storage_meta.env" ]; then
        meta_path="$ruta_target/.storage_meta.env"
    fi

    VGUARD_SERVICE_NAME=""
    VGUARD_TIER=""
    VGUARD_OWNER=""
    VGUARD_POSIX=""
    VGUARD_SELINUX=""
    VGUARD_LV_PATH=""
    OWNER_CORRECTO=""
    PERMISO_POSIX=""
    CONTEXTO_SELINUX=""
    TIPO_USO=""

    if [ -f "$meta_path" ]; then
        # shellcheck source=/dev/null
        source "$meta_path" 2>/dev/null || true
    fi

    local s_name="${VGUARD_SERVICE_NAME:-$(basename "$ruta_target")}"
    local s_tier="${VGUARD_TIER:-${TIPO_USO:-Desconocido}}"
    local s_owner="${VGUARD_OWNER:-$OWNER_CORRECTO}"
    local s_posix="${VGUARD_POSIX:-$PERMISO_POSIX}"
    local s_selinux="${VGUARD_SELINUX:-$CONTEXTO_SELINUX}"
    local s_lv="${VGUARD_LV_PATH:-N/A}"

    guardar_contexto "$s_name" "$s_tier" "$ruta_target" "$s_lv" "$s_owner" "$s_posix" "$s_selinux"

    draw_separator
    msg_success "Objetivo activo seleccionado: ${CLR_BOLD}[$s_tier] -> $s_name${CLR_RESET}"
    echo "  - Ruta en Host: $ruta_target"
    if [ "$s_lv" != "N/A" ]; then
        echo "  - Dispositivo LVM: $s_lv"
    fi
    draw_separator
}

mostrar_contexto_activo() {
    if ! cargar_contexto; then
        msg_warning "No hay ningún volumen u objetivo seleccionado actualmente."
        msg_info "Usa 'vguard select <servicio>' para marcar un objetivo activo."
        return 1
    fi

    draw_separator
    echo -e "${CLR_BOLD}${CLR_BRIGHT_CYAN} VGUARD WORKSPACE // OBJETIVO ACTIVO ${CLR_RESET}"
    draw_separator
    echo " Storage Tier : $CTX_TIER"
    echo " Volumen      : $CTX_SERVICE_NAME"
    echo " Punto Montaje: $CTX_MOUNT_POINT"
    echo " Dispositivo  : ${CTX_LV_PATH:-N/A}"
    echo " Seleccionado : $CTX_SELECTED_AT"
    draw_separator

    echo -e "${CLR_BOLD} SALUD Y ESPACIO:${CLR_RESET}"
    local disk_usage
    disk_usage=$(du -sh "$CTX_MOUNT_POINT" 2>/dev/null | awk '{print $1}')
    echo -e "   [OK] Uso de Disco   : ${disk_usage:-N/A}"

    if [ -n "$CTX_LV_PATH" ] && [ "$CTX_LV_PATH" != "N/A" ]; then
        if lvs "$CTX_LV_PATH" >/dev/null 2>&1; then
            echo -e "   [OK] Estado LVM     : Online (Healthy)"
        else
            echo -e "   [!] Estado LVM     : No detectado / Offline"
        fi
    fi

    draw_separator
    echo -e "${CLR_BOLD} PERMISOS Y SEGURIDAD:${CLR_RESET}"
    local actual_owner actual_posix actual_selinux
    actual_owner=$(stat -c '%U:%G' "$CTX_MOUNT_POINT" 2>/dev/null || echo "Desconocido")
    actual_posix=$(stat -c '%a' "$CTX_MOUNT_POINT" 2>/dev/null || echo "Desconocido")
    actual_selinux=$(ls -Zd "$CTX_MOUNT_POINT" 2>/dev/null | awk '{print $1}' | cut -d: -f3 || echo "Desconocido")

    if [ "$actual_owner" = "$CTX_OWNER" ]; then
        echo -e "   [OK] Propietario    : $actual_owner"
    else
        echo -e "   [X] Propietario    : $actual_owner (Esperado: $CTX_OWNER)"
    fi

    if [ "$actual_posix" = "$CTX_POSIX" ]; then
        echo -e "   [OK] Modo POSIX     : $actual_posix"
    else
        echo -e "   [X] Modo POSIX     : $actual_posix (Esperado: $CTX_POSIX)"
    fi

    if [ -n "$CTX_SELINUX" ] && [ "$CTX_SELINUX" != "N/A" ]; then
        if [[ "$actual_selinux" == *"$CTX_SELINUX"* ]]; then
            echo -e "   [OK] Contexto SELinux: $actual_selinux"
        else
            echo -e "   [!] Contexto SELinux: $actual_selinux (Esperado: $CTX_SELINUX)"
        fi
    fi
    draw_separator
}
