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
    "allow_subfolder_overrides": True
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

def main():
    if len(sys.argv) < 2:
        sys.exit(1)

    cmd = sys.argv[1]
    if cmd == "get-vars" and len(sys.argv) >= 3:
        get_config_vars(sys.argv[2])
    elif cmd == "get-policy" and len(sys.argv) >= 4:
        subfolder = sys.argv[4] if len(sys.argv) >= 5 else None
        get_volume_policy(sys.argv[2], sys.argv[3], subfolder)
    elif cmd == "set-lang" and len(sys.argv) >= 4:
        set_config_lang(sys.argv[2], sys.argv[3])
    elif cmd == "set-explorer-mode" and len(sys.argv) >= 4:
        set_config_explorer_mode(sys.argv[2], sys.argv[3])
    elif cmd == "set-policy" and len(sys.argv) >= 9:
        # set-policy <config_path> <volume_name> <owner> <group> <mode_dir> <mode_file> <selinux> [allow_sub]
        allow_sub = sys.argv[9].lower() == "true" if len(sys.argv) >= 10 else True
        set_volume_policy(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], allow_sub)
    elif cmd == "set-subfolder-policy" and len(sys.argv) >= 9:
        # set-subfolder-policy <config_path> <volume_name> <subfolder> <owner> <group> <mode_dir> <mode_file> <selinux>
        set_subfolder_policy(sys.argv[2], sys.argv[3], sys.argv[4], sys.argv[5], sys.argv[6], sys.argv[7], sys.argv[8], sys.argv[9])

if __name__ == "__main__":
    main()
