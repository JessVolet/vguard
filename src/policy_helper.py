#!/usr/bin/env python3
# ==============================================================================
# VGUARD v3.0 - HELPER PYTHON PARA POLÍTICAS Y CONFIGURACIÓN JSON
# ==============================================================================

import sys
import os
import json

DEFAULT_POLICY = {
    "owner": "vsynlo",
    "group": "vsynlo",
    "mode_dir": "0770",
    "mode_file": "0660",
    "selinux_context": "container_file_t",
    "allow_subfolder_overrides": True,
    "container_managed": False
}

PROFILES = {
    "datastore": {
        "mode_dir": "0770",
        "mode_file": "0660",
        "selinux_context": "container_file_t",
        "container_managed": True,
        "description": "Bases de datos, backups, logs privados (Strict 0770/0660)"
    },
    "webapp": {
        "mode_dir": "0755",
        "mode_file": "0644",
        "selinux_context": "container_file_t",
        "container_managed": True,
        "description": "Nginx, PHP, Node.js, Web Servers (0755/0644 con storage 0775)"
    },
    "shared-app": {
        "mode_dir": "0775",
        "mode_file": "0664",
        "selinux_context": "container_file_t",
        "container_managed": False,
        "description": "Contenedores compartidos mediante GID comun (0775/0664)"
    }
}

def load_json_config(config_path):
    if not os.path.isfile(config_path):
        return {}
    try:
        with open(config_path, "r", encoding="utf-8") as f:
            return json.load(f)
    except Exception as e:
        sys.stderr.write(f"Error cargando JSON {config_path}: {e}\n")
        return {}

def save_json_config(config_path, data):
    os.makedirs(os.path.dirname(os.path.abspath(config_path)), exist_ok=True)
    with open(config_path, "w", encoding="utf-8") as f:
        json.dump(data, f, indent=2)

def get_config_vars(config_path):
    data = load_json_config(config_path)
    paths = data.get("paths", {})
    vg_name = data.get("vg_name", "fedora_server")
    p_hdd_servicios = paths.get("hdd_servicios", "/mnt/sda1/servicios")
    p_hdd_compartido = paths.get("hdd_compartido", "/mnt/sda1/compartido")
    p_hdd_sistema = paths.get("hdd_sistema", "/mnt/sda1/sistema")
    p_nvme_fast = paths.get("nvme_fast", "/mnt/nvme_fast")
    default_owner = data.get("default_owner", "vsynlo")
    default_group = data.get("default_group", "vsynlo")
    meta_file = data.get("meta_file", ".vguard_meta")
    language = data.get("language", "")
    explorer_mode = data.get("explorer_mode", "experimental")

    print(f'VG_NAME="{vg_name}"')
    print(f'PATH_HDD_SERVICIOS="{p_hdd_servicios}"')
    print(f'PATH_HDD_COMPARTIDO="{p_hdd_compartido}"')
    print(f'PATH_HDD_SISTEMA="{p_hdd_sistema}"')
    print(f'PATH_NVME_FAST="{p_nvme_fast}"')
    print(f'VGUARD_OWNER="{default_owner}:{default_group}"')
    print(f'META_FILE="{meta_file}"')
    print(f'CFG_LANGUAGE="{language}"')
    print(f'CFG_EXPLORER_MODE="{explorer_mode}"')

def set_config_lang(config_path, lang):
    data = load_json_config(config_path)
    data["language"] = lang
    save_json_config(config_path, data)

def set_config_explorer_mode(config_path, mode):
    data = load_json_config(config_path)
    data["explorer_mode"] = mode
    save_json_config(config_path, data)

def get_volume_policy(config_path, volume_name_or_path, subfolder_relpath=None):
    data = load_json_config(config_path)
    managed = data.get("managed_volumes", {})

    target_vol = None
    for name, vol_info in managed.items():
        if name == volume_name_or_path or vol_info.get("path") == volume_name_or_path or os.path.basename(vol_info.get("path", "")) == volume_name_or_path:
            target_vol = vol_info
            break

    policy = dict(DEFAULT_POLICY)
    if target_vol and "policy" in target_vol:
        policy.update(target_vol["policy"])

    if target_vol and "profile" in target_vol:
        policy["profile"] = target_vol["profile"]
    else:
        policy["profile"] = "datastore"

    if subfolder_relpath and target_vol and target_vol.get("policy", {}).get("allow_subfolder_overrides", True):
        sub_policies = target_vol.get("subfolder_policies", {})
        subfolder_relpath = subfolder_relpath.strip("/")
        # Buscar la coincidencia más específica de subcarpeta
        matched_path = None
        for sub_p in sub_policies:
            clean_p = sub_p.strip("/")
            if subfolder_relpath == clean_p or subfolder_relpath.startswith(clean_p + "/"):
                if matched_path is None or len(clean_p) > len(matched_path):
                    matched_path = clean_p

        if matched_path:
            policy.update(sub_policies[matched_path])

    print(json.dumps(policy))

def set_volume_profile(config_path, volume_name, profile_name):
    if profile_name not in PROFILES:
        sys.stderr.write(f"Perfil invalido '{profile_name}'. Opciones: {list(PROFILES.keys())}\n")
        sys.exit(1)

    data = load_json_config(config_path)
    managed = data.setdefault("managed_volumes", {})

    target_vol_key = None
    for name, vol_info in managed.items():
        if name == volume_name or vol_info.get("path") == volume_name or os.path.basename(vol_info.get("path", "")) == volume_name:
            target_vol_key = name
            break

    if not target_vol_key:
        target_vol_key = volume_name
        managed[target_vol_key] = {
            "tier": "custom",
            "path": f"/mnt/sda1/servicios/{volume_name}",
            "policy": dict(DEFAULT_POLICY),
            "subfolder_policies": {}
        }

    vol_dict = managed[target_vol_key]
    vol_dict["profile"] = profile_name

    prof = PROFILES[profile_name]
    vol_dict.setdefault("policy", {})
    vol_dict["policy"]["mode_dir"] = prof["mode_dir"]
    vol_dict["policy"]["mode_file"] = prof["mode_file"]
    vol_dict["policy"]["selinux_context"] = prof["selinux_context"]

    if profile_name == "webapp":
        sub_p = vol_dict.setdefault("subfolder_policies", {})
        curr_owner = vol_dict["policy"].get("owner", "vsynlo")
        curr_group = vol_dict["policy"].get("group", "vsynlo")
        if "storage" not in sub_p:
            sub_p["storage"] = {
                "owner": curr_owner,
                "group": "33",
                "mode_dir": "0775",
                "mode_file": "0664",
                "selinux_context": "container_file_t"
            }
        if "bootstrap/cache" not in sub_p:
            sub_p["bootstrap/cache"] = {
                "owner": curr_owner,
                "group": "33",
                "mode_dir": "0775",
                "mode_file": "0664",
                "selinux_context": "container_file_t"
            }

    save_json_config(config_path, data)

def set_volume_policy(config_path, volume_name, owner, group, mode_dir, mode_file, selinux_context, allow_subfolder_overrides=True):
    data = load_json_config(config_path)
    if "managed_volumes" not in data:
        data["managed_volumes"] = {}

    if volume_name not in data["managed_volumes"]:
        data["managed_volumes"][volume_name] = {
            "tier": "custom",
            "path": f"/mnt/sda1/servicios/{volume_name}",
            "policy": {},
            "subfolder_policies": {}
        }

    data["managed_volumes"][volume_name]["policy"] = {
        "owner": str(owner),
        "group": str(group),
        "mode_dir": str(mode_dir),
        "mode_file": str(mode_file),
        "selinux_context": str(selinux_context),
        "allow_subfolder_overrides": bool(allow_subfolder_overrides)
    }
    save_json_config(config_path, data)

def set_subfolder_policy(config_path, volume_name, subfolder_relpath, owner, group, mode_dir, mode_file, selinux_context):
    data = load_json_config(config_path)
    managed = data.get("managed_volumes", {})

    target_vol_key = None
    for name, vol_info in managed.items():
        if name == volume_name or vol_info.get("path") == volume_name or os.path.basename(vol_info.get("path", "")) == volume_name:
            target_vol_key = name
            break

    if not target_vol_key:
        target_vol_key = volume_name
        data.setdefault("managed_volumes", {})[target_vol_key] = {
            "tier": "custom",
            "path": f"/mnt/sda1/servicios/{volume_name}",
            "policy": dict(DEFAULT_POLICY),
            "subfolder_policies": {}
        }

    vol_dict = data["managed_volumes"][target_vol_key]
    vol_dict.setdefault("subfolder_policies", {})

    clean_subfolder = subfolder_relpath.strip("/. ")

    # Si la subruta representa la raíz del volumen, redirigir a la política global del volumen
    if not clean_subfolder or clean_subfolder in [".", "/", ""]:
        set_volume_policy(config_path, target_vol_key, owner, group, mode_dir, mode_file, selinux_context)
        # Recargar para limpiar claves residuales en subfolder_policies
        data = load_json_config(config_path)
        sub_policies = data.get("managed_volumes", {}).get(target_vol_key, {}).get("subfolder_policies", {})
        for invalid_key in [".", "", "/"]:
            sub_policies.pop(invalid_key, None)
        save_json_config(config_path, data)
        return

    # Sanitizar y remover cualquier clave de flag mal parseada si existiera
    sub_policies = vol_dict["subfolder_policies"]
    for k in list(sub_policies.keys()):
        if k.startswith("-") or k in [".", "", "/"]:
            del sub_policies[k]

    sub_policies[clean_subfolder] = {
        "owner": str(owner),
        "group": str(group),
        "mode_dir": str(mode_dir),
        "mode_file": str(mode_file),
        "selinux_context": str(selinux_context)
    }
    save_json_config(config_path, data)

def check_owner_match(path, expected_owner):
    if not os.path.exists(path):
        print("false")
        return
    try:
        st = os.stat(path)
        actual_uid, actual_gid = st.st_uid, st.st_gid

        parts = str(expected_owner).split(":", 1) if ":" in str(expected_owner) else [expected_owner, expected_owner]
        exp_u, exp_g = parts[0], parts[1]

        import pwd, grp
        try:
            target_uid = int(exp_u)
        except ValueError:
            try:
                target_uid = pwd.getpwnam(exp_u).pw_uid
            except KeyError:
                target_uid = None

        try:
            target_gid = int(exp_g)
        except ValueError:
            try:
                target_gid = grp.getgrnam(exp_g).gr_gid
            except KeyError:
                target_gid = None

        u_ok = (target_uid is None) or (actual_uid == target_uid)
        g_ok = (target_gid is None) or (actual_gid == target_gid)

        if u_ok and g_ok:
            print("true")
        else:
            print("false")
    except Exception:
        print("false")

def save_disk_as_policy(config_path, volume_name, abs_path, subpath_rel=""):
    if not os.path.exists(abs_path):
        sys.stderr.write(f"Error: La ruta '{abs_path}' no existe en disco.\n")
        sys.exit(1)

    try:
        st = os.stat(abs_path)
        import pwd, grp
        try: user = pwd.getpwuid(st.st_uid).pw_name
        except KeyError: user = str(st.st_uid)
        try: group = grp.getgrgid(st.st_gid).gr_name
        except KeyError: group = str(st.st_gid)

        mode_dir = oct(st.st_mode & 0o7777)[2:].zfill(4)

        mode_file = "0664"
        if os.path.isdir(abs_path):
            try:
                with os.scandir(abs_path) as it:
                    for entry in it:
                        if entry.is_file(follow_symlinks=False):
                            fst = entry.stat(follow_symlinks=False)
                            mode_file = oct(fst.st_mode & 0o7777)[2:].zfill(4)
                            break
            except Exception:
                pass
        elif os.path.isfile(abs_path):
            mode_file = mode_dir
            mode_dir = "0775"

        selinux = "container_file_t"
        try:
            raw = os.getxattr(abs_path, "security.selinux").decode("utf-8", errors="ignore").strip("\x00")
            parts = raw.split(":")
            selinux = parts[2] if len(parts) >= 3 else raw
        except Exception:
            pass

        clean_sub = subpath_rel.strip("/. ")

        if not clean_sub or clean_sub in [".", "/", ""]:
            set_volume_policy(config_path, volume_name, user, group, mode_dir, mode_file, selinux)
            
            # SMART AUTO-DISCOVERY for exceptions
            exceptions_found = 0
            for r, dirs, files in os.walk(abs_path):
                dirs[:] = [d for d in dirs if d not in ['.git', 'node_modules', 'vendor']]
                new_dirs = []
                
                # Check directories
                for d in dirs:
                    dirpath = os.path.join(r, d)
                    try:
                        dst = os.stat(dirpath)
                        try: u = pwd.getpwuid(dst.st_uid).pw_name
                        except KeyError: u = str(dst.st_uid)
                        try: g = grp.getgrgid(dst.st_gid).gr_name
                        except KeyError: g = str(dst.st_gid)
                        dmode = oct(dst.st_mode & 0o7777)[2:].zfill(4)
                        
                        if u != user or g != group or dmode != mode_dir:
                            rel_ex = os.path.relpath(dirpath, abs_path)
                            set_subfolder_policy(config_path, volume_name, rel_ex, u, g, dmode, dmode, selinux)
                            exceptions_found += 1
                        else:
                            new_dirs.append(d)
                    except Exception:
                        pass
                dirs[:] = new_dirs  # Do not traverse into exception directories
                
                # Check files
                for f in files:
                    filepath = os.path.join(r, f)
                    try:
                        fst = os.stat(filepath)
                        try: u = pwd.getpwuid(fst.st_uid).pw_name
                        except KeyError: u = str(fst.st_uid)
                        try: g = grp.getgrgid(fst.st_gid).gr_name
                        except KeyError: g = str(fst.st_gid)
                        fmode = oct(fst.st_mode & 0o7777)[2:].zfill(4)
                        
                        if u != user or g != group or fmode != mode_file:
                            rel_ex = os.path.relpath(filepath, abs_path)
                            set_subfolder_policy(config_path, volume_name, rel_ex, u, g, mode_dir, fmode, selinux)
                            exceptions_found += 1
                    except Exception:
                        pass

            # Si se encontraron excepciones o es un contenedor probable, marcamos container_managed=true
            if exceptions_found > 0:
                data = load_json_config(config_path)
                data.setdefault("managed_volumes", {}).setdefault(volume_name, {}).setdefault("policy", {})["container_managed"] = True
                save_json_config(config_path, data)

        else:
            set_subfolder_policy(config_path, volume_name, clean_sub, user, group, mode_dir, mode_file, selinux)

        print(json.dumps({
            "target": clean_sub if clean_sub else ".",
            "owner": f"{user}:{group}",
            "mode_dir": mode_dir,
            "mode_file": mode_file,
            "selinux_context": selinux,
            "exceptions_discovered": exceptions_found if not clean_sub else 0
        }))

    except Exception as e:
        sys.stderr.write(f"Error al inspeccionar estado en disco: {e}\n")
        sys.exit(1)

def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "get-vars" and len(sys.argv) >= 3:
        get_config_vars(sys.argv[2])
    elif cmd == "check-owner" and len(sys.argv) >= 4:
        check_owner_match(sys.argv[2], sys.argv[3])
    elif cmd == "get-policy" and len(sys.argv) >= 4:
        subfolder = sys.argv[4] if len(sys.argv) >= 5 else None
        get_volume_policy(sys.argv[2], sys.argv[3], subfolder)
    elif cmd == "set-profile" and len(sys.argv) >= 4:
        set_volume_profile(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "get-profiles":
        print(json.dumps(PROFILES))
    elif cmd == "set-explorer-mode" and len(sys.argv) >= 4:
        set_config_explorer_mode(sys.argv[2], sys.argv[3])
    elif cmd == "save-policy" and len(sys.argv) >= 5:
        # save-policy <config_path> <volume_name> <abs_path> [subpath_rel]
        subpath_rel = sys.argv[5] if len(sys.argv) >= 6 else ""
        save_disk_as_policy(sys.argv[2], sys.argv[3], sys.argv[4], subpath_rel)
    elif cmd == "set-policy" and len(sys.argv) >= 9:
        # set-policy <config_path> <volume_name> <owner> <group> <mode_dir> <mode_file> <selinux> [allow_sub]
        allow_sub = sys.argv[9].lower() == "true" if len(sys.argv) >= 10 else True
        set_volume_policy(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], allow_sub)
    elif cmd == "set-subfolder-policy" and len(sys.argv) >= 9:
        # set-subfolder-policy <config_path> <volume_name> <subfolder> <owner> <group> <mode_dir> <mode_file> <selinux>
        set_subfolder_policy(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9])

if __name__ == "__main__":
    main()
