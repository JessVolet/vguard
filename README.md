# VGUARD v3.0 (Volume Guard & Infrastructure Policy Engine)

VGUARD v3.0 is a modular, declarative, stateful CLI and TUI automation tool designed to enforce, audit, and maintain storage, volume allocation, custom per-volume POSIX policies, and SELinux security contexts on Linux server environments (Fedora Server / RHEL family).

Language translations:
- [Spanish Documentation (README.es.md)](file:///home/vsynlo/Proyectos/Self/vguard/README.es.md)

---

## The 4 Pillars of VGUARD v3.0 Architecture

### 1. Strict Decoupling of Read & Write Operations (Read-Only Audit vs. Explicit Auto-Heal)
- **100% Read-Only Operations:** Commands like `vguard status`, `vguard list`, `vguard context`, `vguard audit`, and `vguard selected tree` read file system attributes, mounted status, disk usage, and permission drift. They **never** execute `chmod`, `chown`, or `restorecon` in the background.
- **Explicit Write Operations:** Commands like `vguard heal`, `vguard selected heal`, and `vguard heal-all` perform state restoration only when explicitly invoked by the administrator.

### 2. Custom Per-Volume & Subfolder Policy Engine (`vguard.conf` & `.json` Policies)
Instead of forcing static global permissions, VGUARD v3.0 allows declaring granular, custom per-volume and subfolder policies in `/etc/vguard/vguard.conf` (or `$HOME/.config/vguard/vguard.conf`):

```json
{
  "managed_volumes": {
    "ocis_data": {
      "tier": "contenedor_hdd",
      "path": "/mnt/sda1/servicios/ocis_data",
      "policy": {
        "owner": "1000",
        "group": "1000",
        "mode_dir": "0775",
        "mode_file": "0664",
        "selinux_context": "container_file_t",
        "allow_subfolder_overrides": true
      },
      "subfolder_policies": {
        "onlyoffice/data": {
          "owner": "1000",
          "group": "1000",
          "mode_dir": "0775",
          "mode_file": "0664",
          "selinux_context": "container_file_t"
        }
      }
    },
    "mysql": {
      "tier": "lvm_nvme_fast",
      "path": "/mnt/nvme_fast/mysql",
      "policy": {
        "owner": "27",
        "group": "27",
        "mode_dir": "0700",
        "mode_file": "0600",
        "selinux_context": "container_file_t",
        "allow_subfolder_overrides": false
      }
    }
  }
}
```

Predefined policy templates are available in `/etc/vguard/policies/` (`default.json`, `container.json`, `database.json`, `share.json`).

### 3. Tree Inspection & Interactive TUI Explorer (`tree` & `explore`)
- **ASCII Tree Inspection:** `vguard selected tree` renders an ASCII tree of nested subfolders displaying `[owner:group mode selinux]` attributes without altering files.
- **Interactive TUI Explorer:** `vguard selected explore` launches an interactive terminal navigator powered by `whiptail` to browse nested directories, create subfolders, configure policies, and run Auto-Heal.

### 4. Stateful Session Context (`/run/vguard/context.json`)
Lock onto an active target volume with `vguard select <volume>` and execute subsequent operations using `vguard selected <action>` without re-typing target paths.

---

## CLI v3.0 Command Reference

| Category | Command | Description |
| :--- | :--- | :--- |
| **Context** | `vguard select [<tier>] <volume>` | Marks a managed storage volume as the active workspace target. |
| **Context** | `vguard context` \| `vguard selected` | Displays active workspace details, disk usage, SELinux, and health. |
| **Context** | `vguard unselect` \| `vguard clear` | Clears active workspace context. |
| **Selected** | `vguard selected status` | Audits active target status (100% Read-Only). |
| **Selected** | `vguard selected tree` | Displays nested subfolder ASCII tree with attributes (Read-Only). |
| **Selected** | `vguard selected explore` | Opens the interactive TUI directory explorer. |
| **Selected** | `vguard selected mkdir <nested_path>` | Creates nested subdirectories inheriting policy (e.g. `onlyoffice/data/cache`). |
| **Selected** | `vguard selected set-policy <subpath>` | Sets custom subfolder policy (`--owner 1000:1000 --mode 0775`). |
| **Selected** | `vguard selected heal` | Explicitly restores POSIX permissions and SELinux on active target. |
| **Selected** | `vguard selected audit` | Evaluates permission drift on active target (Read-Only). |
| **Selected** | `vguard selected resize <size>` | Hot-extends LVM volume and XFS filesystem of active target. |
| **Selected** | `vguard selected rename <new_name>` | Renames directory, LVM LV, fstab, and metadata of active target. |
| **Selected** | `vguard selected snap [size]` | Provisions point-in-time LVM snapshot for active target. |
| **Selected** | `vguard selected delete` | Safe removal of active target with double verification. |
| **Global** | `vguard list` \| `vguard ls` \| `vguard status` | Lists all managed volumes (Read-Only), highlighting `[ACTIVE]` volume. |
| **Global** | `vguard tree [<target>]` | Displays nested subfolder ASCII tree for any target (Read-Only). |
| **Global** | `vguard explore [<target>]` | Opens TUI interactive explorer for any target. |
| **Global** | `vguard create <tier> <name> [size]` | Provisions new volume and automatically marks it as active target. |
| **Global** | `vguard heal-all` | Explicitly audits and heals all managed storage volumes system-wide. |
| **Global** | `vguard update` | Self-updates VGUARD codebase via Git pull and reinstalls links. |
| **Global** | `vguard uninstall` | Launches VGUARD uninstaller. |

---

## Example v3.0 Operational Workflow

```bash
# 1. Select active volume context
vguard select ocis_data

# 2. Inspect nested tree in 100% Read-Only mode
vguard selected tree

# 3. Create nested subfolder structure
vguard selected mkdir onlyoffice/data/cache

# 4. Set custom subfolder policy
vguard selected set-policy onlyoffice --owner 1000:1000 --mode 0775

# 5. Explore subfolders interactively via TUI
vguard selected explore

# 6. Explicitly run Auto-Heal to enforce policies
sudo vguard selected heal
```
