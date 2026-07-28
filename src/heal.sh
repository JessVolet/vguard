#!/bin/bash
# ==============================================================================
# VGUARD v3.0 - MÓDULO DE AUDITORÍA READ-ONLY Y REPARACIÓN PER-VOLUMEN (HEAL)
# ==============================================================================

aplicar_permisos_recursivos_por_politica() {
    local ruta_root="$1"
    local vol_name="$2"

    msg_info "Obteniendo política declarativa personalizada para $vol_name..."
    obtener_politica_volumen "$vol_name" ""

    local target_owner="$POL_OWNER:$POL_GROUP"
    local target_mode_dir="$POL_MODE_DIR"
    local target_mode_file="$POL_MODE_FILE"
    local target_selinux="$POL_SELINUX"

    msg_info "Aplicando propietario ($target_owner) a $ruta_root..."
    chown -R "$target_owner" "$ruta_root" || msg_warning "No se pudo cambiar propietario a $target_owner (¿requiere sudo?)"

    msg_info "Aplicando permisos POSIX a directorios ($target_mode_dir) y archivos ($target_mode_file)..."
    find "$ruta_root" -type d -exec chmod "$target_mode_dir" {} + 2>/dev/null || chmod -R "$target_mode_dir" "$ruta_root"
    # Asegurar remoción de bits especiales SGID/SUID si la política especifica modo estándar 07xx
    if [[ "$target_mode_dir" =~ ^0?[0-7]{3}$ ]]; then
        find "$ruta_root" -type d -exec chmod ug-s {} + 2>/dev/null || true
    fi
    find "$ruta_root" -type f ! -name "$META_FILE" -exec chmod "$target_mode_file" {} + 2>/dev/null || true

    # Si hay políticas de subcarpetas personalizadas declaradas
    python3 - "$CONFIG_FILE" "$vol_name" "$ruta_root" << 'EOF' 2>/dev/null || true
import os
import sys
import subprocess
from policy_helper import load_json_config

config_file = sys.argv[1]
vol_name = sys.argv[2]
root_path = sys.argv[3]

data = load_json_config(config_file)
vol_dict = data.get("managed_volumes", {}).get(vol_name, {})
sub_policies = vol_dict.get("subfolder_policies", {})

for rel_sub, pol in sub_policies.items():
    sub_abs = os.path.join(root_path, rel_sub.strip("/"))
    if os.path.exists(sub_abs):
        owner = f"{pol.get('owner', '1000')}:{pol.get('group', '1000')}"
        mode_dir = pol.get("mode_dir", "0775")
        mode_file = pol.get("mode_file", "0664")
        selinux = pol.get("selinux_context", "container_file_t")

        subprocess.run(["chown", "-R", owner, sub_abs], stderr=subprocess.DEVNULL)
        subprocess.run(["find", sub_abs, "-type", "d", "-exec", "chmod", mode_dir, "{}", "+"], stderr=subprocess.DEVNULL)
        subprocess.run(["find", sub_abs, "-type", "f", "-exec", "chmod", mode_file, "{}", "+"], stderr=subprocess.DEVNULL)
        if selinux and selinux != "N/A":
            subprocess.run(["chcon", "-R", "-t", selinux, sub_abs], stderr=subprocess.DEVNULL)
EOF

    # Aplicar contexto SELinux
    if command -v selinuxenabled >/dev/null 2>&1 && selinuxenabled; then
        msg_info "Aplicando contexto SELinux ($target_selinux) a $ruta_root..."
        if command -v semanage >/dev/null 2>&1; then
            semanage fcontext -a -t "$target_selinux" "$ruta_root(/.*)?" 2>/dev/null || true
        fi
        if command -v restorecon >/dev/null 2>&1; then
            restorecon -R -v "$ruta_root" >/dev/null 2>&1 || true
        fi
    fi
}

auditar_y_reparar_directorio() {
    local ruta_target="$1"
    local solo_auditar="${2:-false}"

    if [ ! -d "$ruta_target" ]; then
        msg_error "El directorio $ruta_target no existe."
        return 1
    fi

    local vol_name
    vol_name="$(basename "$ruta_target")"

    # Obtener política declarativa SSOT desde vguard.conf (Single Source of Truth)
    obtener_politica_volumen "$vol_name" ""

    local target_owner="$POL_OWNER:$POL_GROUP"
    local target_posix="$POL_MODE_DIR"
    local target_selinux="$POL_SELINUX"

    draw_separator
    msg_info "Evaluando estado declarativo para: ${CLR_BOLD}$vol_name${CLR_RESET}"
    msg_info "Ruta: $ruta_target"
    msg_info "Política Declarativa Per-Volumen (SSOT):"
    echo "  - Propietario: $target_owner"
    echo "  - Permisos POSIX Directorio: $target_posix"
    echo "  - Contexto SELinux: $target_selinux"

    # PILLAR 1: LECTURA PURA (Read-Only) al auditar
    if [ "$solo_auditar" = "true" ]; then
        local current_owner current_posix current_selinux
        current_owner=$(stat -c '%U:%G' "$ruta_target" 2>/dev/null || echo "Desconocido")
        current_posix=$(stat -c '%a' "$ruta_target" 2>/dev/null || echo "Desconocido")
        current_selinux=$(ls -Zd "$ruta_target" 2>/dev/null | awk '{print $1}' | cut -d: -f3 || echo "Desconocido")

        # Comparación inteligente de permisos POSIX (evalúa los últimos 3 dígitos octales)
        local clean_current_posix="${current_posix: -3}"
        local clean_target_posix="${target_posix: -3}"

        local py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"
        local owner_matches="false"
        if [ -f "$py_helper" ] && command -v python3 >/dev/null 2>&1; then
            owner_matches=$(python3 "$py_helper" check-owner "$ruta_target" "$target_owner" 2>/dev/null || echo "false")
        else
            local current_num=$(stat -c '%u:%g' "$ruta_target" 2>/dev/null || echo "")
            if [ "$current_owner" = "$target_owner" ] || [ "$current_num" = "$target_owner" ]; then
                owner_matches="true"
            fi
        fi

        local tiene_desviacion=false
        echo -e "\n${CLR_BOLD}Detección de Desviaciones:${CLR_RESET}"
        if [ "$owner_matches" != "true" ]; then
            echo -e "  - Propietario:  ${CLR_RED}$current_owner${CLR_RESET} (Esperado: $target_owner) ${CLR_RED}[X] DESVIACIÓN${CLR_RESET}"
            tiene_desviacion=true
        else
            echo -e "  - Propietario:  ${CLR_GREEN}$current_owner${CLR_RESET} [OK]"
        fi

        if [ "$clean_current_posix" != "$clean_target_posix" ]; then
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

        msg_info "Modo de Auditoría 100% LECTURA (Read-Only). Ningún permiso fue alterado."
        if [ "$tiene_desviacion" = "true" ]; then
            msg_warning "Se detectaron desviaciones. Ejecuta 'vguard heal $ruta_target' para restaurar intencionalmente."
        else
            msg_success "El estado del volumen está alineado al 100% con su política."
        fi
        return 0
    fi

    # PILLAR 1: ESCRITURA EXPLÍCITA solo al ejecutar 'vguard heal'
    msg_section "EJECUTANDO REPARACIÓN DE ESTADO PER-VOLUMEN (AUTO-HEAL EXPLÍCITO)"

    # Sincronizar archivo .vguard_meta local desde la fuente de verdad global (SSOT)
    local meta_path="$ruta_target/$META_FILE"
    if command -v escribir_metadatos >/dev/null 2>&1; then
        escribir_metadatos "$ruta_target" "$vol_name" "custom" "$target_owner" "$target_posix" "$target_selinux" "N/A" 2>/dev/null || true
    fi

    aplicar_permisos_recursivos_por_politica "$ruta_target" "$vol_name"

    if [ -f "$meta_path" ]; then
        chmod 600 "$meta_path" 2>/dev/null || true
        if [ "$EUID" -eq 0 ]; then
            chown root:root "$meta_path" 2>/dev/null || true
        fi
    fi

    msg_success "Reparación completada. Permisos y contextos SELinux restaurados según la política per-volumen."
}

reparar_almacenamiento() {
    local ruta="$1"

    if [ -z "$ruta" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            ruta="$CTX_MOUNT_POINT"
            msg_info "Usando objetivo activo del Workspace: $CTX_SERVICE_NAME ($ruta)"
        else
            msg_section "AUDITORÍA Y REPARACIÓN DE PERMISOS"
            read -p "Ingresa la ruta absoluta a reparar (ej. /mnt/sda1/servicios/gitea): " ruta
        fi
    fi

    if [ -z "$ruta" ]; then
        msg_error "Ruta no especificada."
        return 1
    fi

    auditar_y_reparar_directorio "$ruta" "false"
}
