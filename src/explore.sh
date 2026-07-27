#!/bin/bash
# ==============================================================================
# VGUARD v3.0 - MÓDULO EXPLORADOR INTERACTIVO TUI (EXPLORE)
# ==============================================================================

explorar_volumen_tui() {
    local target_input="$1"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
        else
            read -p "Ingresa el nombre o ruta del servicio a explorar: " target_input
        fi
    fi

    local ruta_base=""
    if [ -d "$target_input" ]; then
        ruta_base="$target_input"
    else
        local base_paths=(
            "$PATH_HDD_SERVICIOS/$target_input"
            "$PATH_NVME_FAST/$target_input"
            "$PATH_HDD_COMPARTIDO/$target_input"
            "$PATH_HDD_SISTEMA/$target_input"
        )
        for path in "${base_paths[@]}"; do
            if [ -d "$path" ]; then
                ruta_base="$path"
                break
            fi
        done
    fi

    if [ -z "$ruta_base" ] || [ ! -d "$ruta_base" ]; then
        msg_error "El servicio o directorio '$target_input' no existe."
        return 1
    fi

    local ruta_actual="$ruta_base"
    local vol_name
    vol_name="$(basename "$ruta_base")"

    # Verificar si whiptail está disponible en el servidor
    if command -v whiptail >/dev/null 2>&1; then
        while true; do
            local items=()
            
            # Opción para ir al directorio superior si no estamos en la raíz del servicio
            if [ "$ruta_actual" != "$ruta_base" ]; then
                items+=(".." "<DIR> (Ir arriba)")
            fi

            items+=("__MKDIR__" "[+] Crear nueva subcarpeta")
            items+=("__SETPOL__" "[*] Editar política de este directorio")
            items+=("__HEAL__" "[!] Ejecutar Auto-Heal en este directorio")

            # Listar subdirectorios y archivos
            while IFS= read -r item_name; do
                [ -z "$item_name" ] && continue
                local full_item="$ruta_actual/$item_name"
                local item_info
                item_info=$(stat -c '%U:%G %a' "$full_item" 2>/dev/null || echo "???")
                
                local selinux
                selinux=$(ls -Zd "$full_item" 2>/dev/null | awk '{print $1}' | cut -d: -f3 || echo "N/A")

                if [ -d "$full_item" ]; then
                    items+=("$item_name" "<DIR>  [$item_info  $selinux]")
                else
                    items+=("$item_name" "       [$item_info  $selinux]")
                fi
            done < <(ls -1 "$ruta_actual" 2>/dev/null)

            local rel_display
            rel_display="$(os.path.relpath "$ruta_actual" "$ruta_base" 2>/dev/null || echo "$vol_name")"

            local seleccion
            seleccion=$(whiptail --title "VGUARD EXPLORER v3.0 // $vol_name ($ruta_actual)" \
                --menu "Navega por las subcarpetas del volumen activo:" 20 80 12 \
                "${items[@]}" 3>&1 1>&2 2>&3 || true)

            if [ -z "$seleccion" ]; then
                break
            fi

            case "$seleccion" in
                "..")
                    ruta_actual="$(dirname "$ruta_actual")"
                    ;;
                "__MKDIR__")
                    local sub_name
                    sub_name=$(whiptail --inputbox "Ingresa el nombre de la subcarpeta:" 10 60 3>&1 1>&2 2>&3 || true)
                    if [ -n "$sub_name" ]; then
                        mkdir -p "$ruta_actual/$sub_name"
                        local rel_p
                        rel_p="$(realpath --relative-to="$ruta_base" "$ruta_actual/$sub_name")"
                        obtener_politica_volumen "$vol_name" "$rel_p"
                        aplicar_permisos "$ruta_actual/$sub_name" "$POL_OWNER:$POL_GROUP" "$POL_MODE_DIR" "$POL_SELINUX"
                        whiptail --msgbox "Subcarpeta creada y asegurada: $sub_name" 8 50
                    fi
                    ;;
                "__SETPOL__")
                    local rel_p
                    rel_p="$(realpath --relative-to="$ruta_base" "$ruta_actual")"
                    [ "$rel_p" = "." ] && rel_p=""
                    local pol_user pol_mode
                    pol_user=$(whiptail --inputbox "Propietario (usuario:grupo):" 10 60 "1000:1000" 3>&1 1>&2 2>&3 || true)
                    pol_mode=$(whiptail --inputbox "Modo POSIX (ej. 0775, 0770):" 10 60 "0775" 3>&1 1>&2 2>&3 || true)
                    if [ -n "$pol_user" ] && [ -n "$pol_mode" ]; then
                        establecer_politica_subcarpeta "$vol_name" "$rel_p" --owner "$pol_user" --mode "$pol_mode"
                        whiptail --msgbox "Política declarativa guardada para $rel_p" 8 50
                    fi
                    ;;
                "__HEAL__")
                    if [ "$EUID" -ne 0 ]; then
                        whiptail --msgbox "La reparación requiere privilegios root/sudo." 8 50
                    else
                        auditar_y_reparar_directorio "$ruta_actual" "false"
                        whiptail --msgbox "Auto-Heal ejecutado exitosamente en $ruta_actual." 8 50
                    fi
                    ;;
                *)
                    local selected_path="$ruta_actual/$seleccion"
                    if [ -d "$selected_path" ]; then
                        ruta_actual="$selected_path"
                    else
                        whiptail --msgbox "Archivo: $seleccion\nRuta: $selected_path\nDetalles: $(stat -c '%U:%G  %a' "$selected_path")" 10 60
                    fi
                    ;;
            esac
        done
    else
        # Fallback de explorador de terminal si whiptail no está presente
        msg_info "Explorador TUI de terminal para $ruta_actual:"
        mostrar_arbol_volumen "$ruta_base"
    fi
}
