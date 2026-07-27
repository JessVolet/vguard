#!/bin/bash
# ==============================================================================
# VGUARD v3.0 - MÓDULO DE INSPECCIÓN DE ÁRBOL Y POLÍTICAS ANIDADAS (TREE)
# ==============================================================================

mostrar_arbol_volumen() {
    local target_input="$1"

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_MOUNT_POINT"
        else
            read -p "Ingresa la ruta o el nombre del servicio a inspeccionar: " target_input
        fi
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
        msg_error "El directorio o servicio '$target_input' no existe."
        return 1
    fi

    local volume_name
    volume_name="$(basename "$ruta_target")"

    draw_separator
    echo -e "${CLR_BOLD}${CLR_BRIGHT_CYAN} VGUARD TREE EXPLORER // $ruta_target ${CLR_RESET}"
    draw_separator

    # Inspección de árbol en LECTURA PURA (Read-Only)
    python3 - "$CONFIG_FILE" "$volume_name" "$ruta_target" << 'EOF'
import os
import sys
import json
import subprocess

config_file = sys.argv[1]
volume_name = sys.argv[2]
root_path = sys.argv[3]

py_helper = os.path.join(os.path.dirname(os.path.abspath(__file__)), "policy_helper.py")

def get_node_info(path, rel_path=""):
    try:
        st = os.stat(path)
        import pwd, grp
        try:
            user = pwd.getpwuid(st.st_uid).pw_name
        except KeyError:
            user = str(st.st_uid)
        try:
            group = grp.getgrgid(st.st_gid).gr_name
        except KeyError:
            group = str(st.st_gid)

        mode_octal = oct(st.st_mode & 0o7777)[2:].zfill(4)
        is_dir = os.path.isdir(path)

        # SELinux context
        selinux = "N/A"
        try:
            res = subprocess.run(["ls", "-Zd", path], stdout=subprocess.PIPE, stderr=subprocess.DEVNULL, text=True)
            if res.returncode == 0:
                parts = res.stdout.split()
                if parts:
                    selinux = parts[0].split(":")[2] if ":" in parts[0] else parts[0]
        except Exception:
            pass

        return {
            "owner": f"{user}:{group}",
            "uid_gid": f"{st.st_uid}:{st.st_gid}",
            "mode": mode_octal,
            "is_dir": is_dir,
            "selinux": selinux
        }
    except Exception as e:
        return {"owner": "???", "uid_gid": "???", "mode": "???", "is_dir": False, "selinux": "???"}

def walk_dir(path, prefix="", depth=0, max_depth=4):
    if depth > max_depth:
        return

    try:
        entries = sorted(os.listdir(path))
    except Exception:
        return

    # Filtrar metadatos ocultos en listado visual simple
    entries = [e for e in entries if e != ".git"]

    total = len(entries)
    for idx, entry in enumerate(entries):
        is_last = (idx == total - 1)
        connector = "└── " if is_last else "├── "
        child_prefix = "    " if is_last else "│   "

        full_path = os.path.join(path, entry)
        rel_path = os.path.relpath(full_path, root_path)

        info = get_node_info(full_path, rel_path)
        tag = "<DIR> " if info["is_dir"] else "      "
        
        info_str = f"[{info['owner']}  {info['mode']}  {info['selinux']}]"
        print(f"{prefix}{connector}{tag} {entry:<22} {info_str}")

        if info["is_dir"]:
            walk_dir(full_path, prefix + child_prefix, depth + 1, max_depth)

root_info = get_node_info(root_path)
print(f"<ROOT> {volume_name}/ [{root_info['owner']}  {root_info['mode']}  {root_info['selinux']}]")
walk_dir(root_path)

EOF
    draw_separator
    msg_info "Modo de Inspección 100% LECTURA (Read-Only). No se han modificado archivos."
}

establecer_politica_subcarpeta() {
    local target_input="$1"
    local subpath="$2"
    shift 2

    local owner=""
    local mode_dir=""
    local mode_file=""
    local selinux=""

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --owner)
                owner="$2"
                shift 2
                ;;
            --mode|--mode-dir)
                mode_dir="$2"
                shift 2
                ;;
            --mode-file)
                mode_file="$2"
                shift 2
                ;;
            --selinux)
                selinux="$2"
                shift 2
                ;;
            *)
                shift
                ;;
        esac
    done

    if [ -z "$target_input" ]; then
        if cargar_contexto >/dev/null 2>&1; then
            target_input="$CTX_SERVICE_NAME"
        else
            read -p "Ingresa el nombre del servicio objetivo: " target_input
        fi
    fi

    if [ -z "$subpath" ]; then
        read -p "Ingresa la ruta de la subcarpeta (ej. onlyoffice/data): " subpath
    fi

    if [ -z "$owner" ]; then
        read -p "Propietario (ej. 1000:1000 o vsynlo:vsynlo): " owner
    fi

    if [ -z "$mode_dir" ]; then
        read -p "Modo POSIX para directorio (ej. 0775, 0770): " mode_dir
    fi

    local uid group_gid
    if [[ "$owner" == *:* ]]; then
        uid="${owner%%:*}"
        group_gid="${owner#*:}"
    else
        uid="$owner"
        group_gid="$owner"
    fi

    mode_file="${mode_file:-0664}"
    selinux="${selinux:-container_file_t}"

    local py_helper
    py_helper="$(dirname "$(realpath "${BASH_SOURCE[0]}")")/policy_helper.py"

    python3 "$py_helper" set-subfolder-policy "$CONFIG_FILE" "$target_input" "$subpath" "$uid" "$group_gid" "$mode_dir" "$mode_file" "$selinux"

    msg_success "Política de subcarpeta guardada correctamente para '$target_input/$subpath':"
    echo "  - Propietario: $uid:$group_gid"
    echo "  - Modo Directorio: $mode_dir"
    echo "  - Modo Archivo: $mode_file"
    echo "  - Contexto SELinux: $selinux"
}
