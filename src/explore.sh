#!/bin/bash
# ==============================================================================
# VGUARD v3.1 - MÓDULO EXPLORADOR INTERACTIVO (LAZY EXPLORE)
# Soporta modo 'experimental' (FZF Yazi-style) y 'stable' (CLI liviano)
# ==============================================================================

explorar_fzf_lazy() {
    local ruta_base="$1"
    local vol_name="$2"
    local cur_dir="$ruta_base"

    while true; do
        # 1. Obtiene únicamente los archivos/directorios del nivel actual (sin recursividad)
        # Formatea: [TIPO] Nombre | [USER:GROUP PERMS SELINUX]
        local fzf_out
        fzf_out=$(python3 - "$cur_dir" "$ruta_base" << 'EOF' | fzf --expect=alt-p,alt-h,alt-m \
            --header="VGUARD EXPLORER (MODO EXPERIMENTAL): $vol_name ($cur_dir)
[ENTER]: Navegar | [ALT+P]: Asignar Política | [ALT+H]: Heal | [ALT+M]: Crear Subcarpeta | [ESC/Q]: Salir" \
            --ansi --reverse --height=80% --prompt="Posición: $cur_dir > "
import os, stat, pwd, grp, sys

cur_dir = sys.argv[1]
root_dir = sys.argv[2]
items = []

if os.path.abspath(cur_dir) != os.path.abspath(root_dir):
    items.append('.. (Subir nivel)')

try:
    with os.scandir(cur_dir) as entries:
        for entry in entries:
            try:
                st = entry.stat(follow_symlinks=False)
                try: user = pwd.getpwuid(st.st_uid).pw_name
                except: user = str(st.st_uid)
                try: group = grp.getgrgid(st.st_gid).gr_name
                except: group = str(st.st_gid)

                mode = oct(st.st_mode & 0o7777)[2:].zfill(4)
                is_dir = '<DIR>' if entry.is_dir() else '     '

                selinux = "N/A"
                try:
                    raw = os.getxattr(entry.path, "security.selinux").decode("utf-8", errors="ignore").strip("\x00")
                    parts = raw.split(":")
                    selinux = parts[2] if len(parts) >= 3 else raw
                except Exception:
                    pass

                items.append(f'{is_dir} {entry.name:<30} │ [{user}:{group} {mode} {selinux}]')
            except Exception:
                continue
except Exception as e:
    items.append(f'Error leyendo directorio: {e}')

for item in sorted(items, key=lambda x: (not x.startswith('..'), not x.startswith('<DIR>'), x.lower())):
    print(item)
EOF
)

        [ -z "$fzf_out" ] && break

        local key_pressed selection item_name target_path rel_p
        key_pressed=$(echo "$fzf_out" | head -n 1)
        selection=$(echo "$fzf_out" | tail -n +2)

        [ -z "$selection" ] && break

        item_name=$(echo "$selection" | awk -F'│' '{print $1}' | sed 's/<DIR>//g' | xargs)

        if [ "$item_name" = ".. (Subir nivel)" ] || [ "$item_name" = ".." ]; then
            target_path="$(dirname "$cur_dir")"
            if [[ "$target_path" != "$ruta_base"* ]]; then
                target_path="$ruta_base"
            fi
        else
            target_path="$cur_dir/$item_name"
        fi

        case "$key_pressed" in
            alt-p)
                local target_for_policy="$target_path"
                [ ! -e "$target_for_policy" ] && target_for_policy="$cur_dir"

                rel_p="$(realpath --relative-to="$ruta_base" "$target_for_policy" 2>/dev/null || echo ".")"
                [ "$rel_p" = "." ] && rel_p=""

                echo -e "\n${CLR_BOLD}${CLR_CYAN}--- ASIGNAR POLÍTICA EN CALIENTE (EXPERIMENTAL) ---${CLR_RESET}"
                echo "Objetivo: $vol_name/${rel_p:-.}"
                read -p "Propietario (usuario:grupo) [1000:1000]: " pol_owner
                pol_owner="${pol_owner:-1000:1000}"
                read -p "Modo POSIX (ej. 0775, 0770) [0775]: " pol_mode
                pol_mode="${pol_mode:-0775}"

                establecer_politica_subcarpeta "$vol_name" "$rel_p" --owner "$pol_owner" --mode "$pol_mode"

                read -p "¿Deseas aplicar la política ahora mismo con Heal? (s/N): " apply_now
                if [[ "$apply_now" =~ ^[Ss]$ ]]; then
                    auditar_y_reparar_directorio "$target_for_policy" "false"
                fi
                read -p "Presiona Enter para continuar..." dummy
                ;;
            alt-h)
                local target_for_heal="$target_path"
                [ ! -e "$target_for_heal" ] && target_for_heal="$cur_dir"

                echo -e "\n${CLR_BOLD}${CLR_CYAN}--- EJECUTANDO AUTO-HEAL EN CALIENTE (EXPERIMENTAL) ---${CLR_RESET}"
                auditar_y_reparar_directorio "$target_for_heal" "false"
                read -p "Presiona Enter para continuar..." dummy
                ;;
            alt-m)
                echo -e "\n${CLR_BOLD}${CLR_CYAN}--- CREAR NUEVA SUBCARPETA ---${CLR_RESET}"
                read -p "Ingresa el nombre de la subcarpeta: " sub_name
                if [ -n "$sub_name" ]; then
                    mkdir -p "$cur_dir/$sub_name"
                    local rel_sub
                    rel_sub="$(realpath --relative-to="$ruta_base" "$cur_dir/$sub_name" 2>/dev/null || echo "$sub_name")"
                    obtener_politica_volumen "$vol_name" "$rel_sub"
                    aplicar_permisos "$cur_dir/$sub_name" "$POL_OWNER:$POL_GROUP" "$POL_MODE_DIR" "$POL_SELINUX"
                    msg_success "Subcarpeta creada y asegurada: $cur_dir/$sub_name"
                fi
                read -p "Presiona Enter para continuar..." dummy
                ;;
            *)
                # ENTER o Selección normal
                if [ "$item_name" = ".. (Subir nivel)" ] || [ "$item_name" = ".." ]; then
                    cur_dir="$(dirname "$cur_dir")"
                    if [[ "$cur_dir" != "$ruta_base"* ]]; then
                        cur_dir="$ruta_base"
                    fi
                elif [ -d "$target_path" ]; then
                    cur_dir="$target_path"
                elif [ -f "$target_path" ]; then
                    echo -e "\n${CLR_BOLD}DETALLES DEL ARCHIVO:${CLR_RESET}"
                    echo "Ruta: $target_path"
                    stat "$target_path" 2>/dev/null || true
                    read -p "Presiona Enter para continuar..." dummy
                fi
                ;;
        esac
    done
}

explorar_cli_lazy() {
    local ruta_base="$1"
    local vol_name="$2"
    local cur_dir="$ruta_base"

    while true; do
        local rel_p
        rel_p="$(realpath --relative-to="$ruta_base" "$cur_dir" 2>/dev/null || echo ".")"
        local current_depth=0
        if [ "$rel_p" != "." ] && [ -n "$rel_p" ]; then
            current_depth=$(echo "$rel_p" | tr -s '/' '\n' | grep -v '^$' | wc -l)
        fi

        draw_separator
        echo -e "${CLR_BOLD}${CLR_CYAN} VGUARD EXPLORER (MODO ESTABLE) // $vol_name ${CLR_RESET}"
        echo -e "${CLR_YELLOW}[!] NOTA: Herramienta de inspección rápida (Límite: máx 4 niveles de profundidad).${CLR_RESET}"
        draw_separator
        echo -e "Ruta Actual: ${CLR_BOLD}$cur_dir${CLR_RESET}  (Nivel $current_depth de 4)"
        echo ""

        local display_items=()
        local real_names=()

        if [ "$cur_dir" != "$ruta_base" ]; then
            display_items+=(".. (Subir nivel)")
            real_names+=("..")
        fi

        while IFS= read -r line; do
            [ -z "$line" ] && continue
            display_items+=("$line")
            local name_part
            name_part=$(echo "$line" | cut -c8-35 | sed 's/[ \t]*$//')
            real_names+=("$name_part")
        done < <(python3 - "$cur_dir" << 'EOF' 2>/dev/null
import os, sys, pwd, grp

cur_dir = sys.argv[1]
try:
    with os.scandir(cur_dir) as it:
        for entry in sorted(list(it), key=lambda e: (not e.is_dir(), e.name.lower())):
            try:
                st = entry.stat(follow_symlinks=False)
                try: user = pwd.getpwuid(st.st_uid).pw_name
                except: user = str(st.st_uid)
                try: group = grp.getgrgid(st.st_gid).gr_name
                except: group = str(st.st_gid)

                mode = oct(st.st_mode & 0o7777)[2:].zfill(4)
                tag = "<DIR> " if entry.is_dir() else "      "

                selinux = "N/A"
                try:
                    raw = os.getxattr(entry.path, "security.selinux").decode("utf-8", errors="ignore").strip("\x00")
                    parts = raw.split(":")
                    selinux = parts[2] if len(parts) >= 3 else raw
                except Exception:
                    pass

                print(f"{tag} {entry.name:<28} [{user}:{group}  {mode}  {selinux}]")
            except Exception:
                continue
except Exception as e:
    pass
EOF
)

        if [ ${#display_items[@]} -eq 0 ]; then
            echo "   (Directorio vacío)"
        else
            local idx=0
            for item in "${display_items[@]}"; do
                printf "  [%2d] %s\n" "$idx" "$item"
                ((idx++))
            done
        fi

        draw_separator
        echo "Opciones:"
        echo "  [0-$(( ${#display_items[@]} - 1 ))] Entrar a directorio / Ver archivo"
        echo "  [p] Asignar política a esta carpeta"
        echo "  [h] Ejecutar Auto-Heal en esta carpeta"
        echo "  [m] Crear subcarpeta aquí"
        echo "  [q] Salir al menú principal"
        draw_separator
        read -p "Ingresa tu opción: " choice

        [ -z "$choice" ] || [ "$choice" = "q" ] || [ "$choice" = "Q" ] && break

        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 0 ] && [ "$choice" -lt "${#display_items[@]}" ]; then
            local target_name="${real_names[$choice]}"

            if [ "$target_name" = ".." ]; then
                cur_dir="$(dirname "$cur_dir")"
                [[ "$cur_dir" != "$ruta_base"* ]] && cur_dir="$ruta_base"
            else
                local target_path="$cur_dir/$target_name"

                if [ -d "$target_path" ]; then
                    local next_rel
                    next_rel="$(realpath --relative-to="$ruta_base" "$target_path" 2>/dev/null || echo ".")"
                    local next_depth=0
                    if [ "$next_rel" != "." ] && [ -n "$next_rel" ]; then
                        next_depth=$(echo "$next_rel" | tr -s '/' '\n' | grep -v '^$' | wc -l)
                    fi

                    if [ "$next_depth" -gt 4 ]; then
                        echo -e "\n${CLR_BOLD}${CLR_RED}[!] AVISO DE VGUARD:${CLR_RESET}"
                        echo -e "${CLR_YELLOW}Esta herramienta NO está diseñada como un explorador de archivos completo.${CLR_RESET}"
                        echo -e "${CLR_YELLOW}El límite máximo de navegación es de 4 subdirectorios de profundidad.${CLR_RESET}\n"
                        read -p "Presiona Enter para continuar..." dummy
                    else
                        cur_dir="$target_path"
                    fi
                elif [ -f "$target_path" ]; then
                    echo -e "\n${CLR_BOLD}DETALLES DEL ARCHIVO:${CLR_RESET}"
                    echo "Ruta: $target_path"
                    stat "$target_path" 2>/dev/null || true
                    read -p "Presiona Enter para continuar..." dummy
                fi
            fi
        elif [ "$choice" = "p" ] || [ "$choice" = "P" ]; then
            local rel_p_pol
            rel_p_pol="$(realpath --relative-to="$ruta_base" "$cur_dir" 2>/dev/null || echo ".")"
            [ "$rel_p_pol" = "." ] && rel_p_pol=""

            echo -e "\n${CLR_BOLD}${CLR_CYAN}--- ASIGNAR POLÍTICA A ESTA CARPETA ---${CLR_RESET}"
            echo "Objetivo: $vol_name/${rel_p_pol:-.}"
            read -p "Propietario (usuario:grupo) [1000:1000]: " pol_owner
            pol_owner="${pol_owner:-1000:1000}"
            read -p "Modo POSIX (ej. 0775, 0770) [0775]: " pol_mode
            pol_mode="${pol_mode:-0775}"

            establecer_politica_subcarpeta "$vol_name" "$rel_p_pol" --owner "$pol_owner" --mode "$pol_mode"

            read -p "¿Deseas aplicar la política ahora mismo con Heal? (s/N): " apply_now
            if [[ "$apply_now" =~ ^[Ss]$ ]]; then
                auditar_y_reparar_directorio "$cur_dir" "false"
            fi
            read -p "Presiona Enter para continuar..." dummy
        elif [ "$choice" = "h" ] || [ "$choice" = "H" ]; then
            echo -e "\n${CLR_BOLD}${CLR_CYAN}--- EJECUTANDO AUTO-HEAL ---${CLR_RESET}"
            auditar_y_reparar_directorio "$cur_dir" "false"
            read -p "Presiona Enter para continuar..." dummy
        elif [ "$choice" = "m" ] || [ "$choice" = "M" ]; then
            echo -e "\n${CLR_BOLD}${CLR_CYAN}--- CREAR NUEVA SUBCARPETA ---${CLR_RESET}"
            read -p "Ingresa el nombre de la subcarpeta: " sub_name
            if [ -n "$sub_name" ]; then
                mkdir -p "$cur_dir/$sub_name"
                local rel_sub
                rel_sub="$(realpath --relative-to="$ruta_base" "$cur_dir/$sub_name" 2>/dev/null || echo "$sub_name")"
                obtener_politica_volumen "$vol_name" "$rel_sub"
                aplicar_permisos "$cur_dir/$sub_name" "$POL_OWNER:$POL_GROUP" "$POL_MODE_DIR" "$POL_SELINUX"
                msg_success "Subcarpeta creada y asegurada: $cur_dir/$sub_name"
            fi
            read -p "Presiona Enter para continuar..." dummy
        fi
    done
}

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
        ruta_base="$(realpath "$target_input")"
    else
        local base_paths=(
            "$PATH_HDD_SERVICIOS/$target_input"
            "$PATH_NVME_FAST/$target_input"
            "$PATH_HDD_COMPARTIDO/$target_input"
            "$PATH_HDD_SISTEMA/$target_input"
        )
        for path in "${base_paths[@]}"; do
            if [ -d "$path" ]; then
                ruta_base="$(realpath "$path")"
                break
            fi
        done
    fi

    if [ -z "$ruta_base" ] || [ ! -d "$ruta_base" ]; then
        msg_error "El servicio o directorio '$target_input' no existe."
        return 1
    fi

    local vol_name
    vol_name="$(basename "$ruta_base")"

    local explorer_mode="${CFG_EXPLORER_MODE:-experimental}"

    if [ "$explorer_mode" = "experimental" ]; then
        if command -v fzf >/dev/null 2>&1; then
            explorar_fzf_lazy "$ruta_base" "$vol_name"
            return $?
        else
            msg_warning "fzf no está disponible en este servidor. Conmutando a modo 'stable'..."
            explorar_cli_lazy "$ruta_base" "$vol_name"
            return $?
        fi
    else
        explorar_cli_lazy "$ruta_base" "$vol_name"
        return $?
    fi
}
