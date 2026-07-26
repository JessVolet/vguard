# VGUARD v2.0 (Volume Guard & Infrastructure Policy Engine)

VGUARD v2.0 is a modular, declarative, stateful CLI automation tool designed to enforce, audit, and maintain storage, volume allocation, POSIX permissions, and SELinux security contexts on Linux server environments (Fedora Server / RHEL family).

VGUARD v2.0 introduces a **Stateful Workspace Context** architecture (`vguard select`, `vguard selected`), allowing administrators to lock onto an active storage volume and execute operational tasks without re-typing target paths.

This tool is specifically engineered to enforce and maintain the infrastructure policies established in the [ServerInfraestructureDockers](https://gitlab.com/sowtarez/ServerInfraestructureDockers) specification.

Language translations:
- [Spanish Documentation (README.es.md)](file:///home/vsynlo/Proyectos/Self/vguard/README.es.md)

---

## Infrastructure Overview and Policies

VGUARD operates as an automated policy engine for host storage and containerized workloads running on Fedora Server (Lenovo ThinkCentre M920s architecture).

### 1. Storage Topology & Hybrid Tiering

- **High-IOPS Tier (NVMe SSD):**
  - Logical Volume `fedora_server-root` (15 GiB, XFS): Isolated operating system and system packages.
  - Logical Volume `fedora_server-containers` (50 GiB, XFS): Dedicated to `/var/lib/containers` for container image layers and ephemeral states.
  - Unallocated Volume Group Reserve (`fedora_server`, ~409 GiB): Retained for Just-In-Time (JIT) dynamic allocation of independent Logical Volumes (`vguard create lvm_nvme_fast`) dedicated to relational databases (MySQL, PostgreSQL, Redis).

- **High-Capacity Tier (SATA HDD):**
  - Partition `/dev/sda1` mounted at `/mnt/sda1` (ext4): Reserved for mass storage workloads, cold backups, Git repositories (Gitea), and WebDAV user file stores.
  - Strict directory segregation: `/mnt/sda1/servicios/`, `/mnt/sda1/compartido/`, `/mnt/sda1/sistema/`.

### 2. Containerization and Security Rules

- **Prohibition of Anonymous Volumes:** All Podman/Docker containers must use explicit bind mounts targeting host paths. Managed volumes under `/var/lib/containers/storage/volumes/` are strictly prohibited.
- **SELinux Enforcement:** Target paths must be labeled with appropriate security contexts (`container_file_t` for container storage, `samba_share_t` for SMB/NFS network shares).
- **Network Ingress:** Microservices communicate via an isolated external bridge network (`frontend_proxy`). Application ports are not exposed to the host network interface unless explicitly required for fixed infrastructure (e.g., DNS or SSH).

---

## Stateful Workspace Architecture (`/run/vguard/context.json`)

VGUARD v2.0 manages active session context stored in `/run/vguard/context.json` (or user fallback `~/.config/vguard/context.json`).

```json
{
  "service_name": "redis_prod",
  "tier": "lvm_nvme_fast",
  "mount_point": "/mnt/nvme_fast/redis_prod",
  "lv_path": "/dev/fedora_server/redis_prod_data",
  "owner": "vsynlo:vsynlo",
  "posix": "770",
  "selinux": "container_file_t",
  "selected_at": "2026-07-25T23:55:00Z"
}
```

---

## Repository Architecture

```text
vguard/
├── README.md               # Main documentation (English)
├── README.es.md            # Secondary documentation (Spanish)
├── install.sh              # Global installer script (/usr/local/bin or ~/.local/bin)
├── vguard                  # Main CLI entrypoint and command router
├── config/
│   └── vguard.conf.example # Default infrastructure policy configuration
└── src/
    ├── ui.sh               # Terminal formatting and output utilities
    ├── config.sh           # Configuration loader and policy parser
    ├── create.sh           # Volume allocation, LVM provisioning, and mounting
    ├── heal.sh             # Audit engine and self-healing restoration
    ├── status.sh           # Global inventory and permission drift inspection
    └── snap.sh             # LVM snapshot lifecycle and rollback management
```

---

## Configuration (`vguard.conf`)

Global system policies are declared in `/etc/vguard/vguard.conf` (or user fallback `~/.config/vguard/vguard.conf`):

```bash
# LVM Volume Group
VG_NAME="fedora_server"

# Infrastructure Mount Points
PATH_HDD_SERVICIOS="/mnt/sda1/servicios"
PATH_HDD_COMPARTIDO="/mnt/sda1/compartido"
PATH_HDD_SISTEMA="/mnt/sda1/sistema"
PATH_NVME_FAST="/mnt/nvme_fast"

# Default Ownership and Metadata Tagging
VGUARD_OWNER="vsynlo:vsynlo"
META_FILE=".vguard_meta"

# SELinux Policy Defaults
SELINUX_CONTAINER="container_file_t"
SELINUX_NETWORK="samba_share_t"
SELINUX_SYSTEM="systemd_system_unit_t"

# POSIX Permission Modes
PERM_POSIX_CONTAINER="770"
PERM_POSIX_NETWORK="775"
PERM_POSIX_SYSTEM="750"
```

---

## Declarative Metadata (`.vguard_meta`)

Upon creation, VGUARD injects a protected metadata file (`chmod 600 root:root`) into the root of the managed storage directory:

```env
# Declarative State Metadata - VGUARD
VGUARD_VERSION="1.0"
VGUARD_SERVICE_NAME="mysql_prod"
VGUARD_TIER="lvm_nvme_fast"
VGUARD_OWNER="vsynlo:vsynlo"
VGUARD_POSIX="770"
VGUARD_SELINUX="container_file_t"
VGUARD_MOUNT_POINT="/mnt/nvme_fast/mysql_prod"
VGUARD_LV_PATH="/dev/fedora_server/mysql_prod_data"
VGUARD_CREATED_AT="2026-07-25T22:00:00-06:00"
```

---

## Installation and Command Reference

### Installation

Execute the installer script to symlink the executable and create policy files:

```bash
git clone https://github.com/tu-usuario/vguard.git
cd vguard
chmod +x install.sh
sudo ./install.sh
```

### CLI Command Summary

| Category | Command | Description |
| :--- | :--- | :--- |
| **Context** | `vguard select [<tier>] <volume>` | Marks a managed storage volume as the active workspace target. |
| **Context** | `vguard context` \| `vguard selected` | Displays active workspace details, disk usage, SELinux, and health. |
| **Context** | `vguard unselect` \| `vguard clear` | Clears active workspace context. |
| **Selected** | `vguard selected status` | Audits and prints full status for the currently active target. |
| **Selected** | `vguard selected resize <size>` | Hot-extends LVM volume and XFS filesystem of active target. |
| **Selected** | `vguard selected rename <new_name>` | Renames directory, LVM LV, fstab, and metadata of active target. |
| **Selected** | `vguard selected heal` | Enforces declared ownership, POSIX permissions, and SELinux on active target. |
| **Selected** | `vguard selected audit` | Evaluates permission drift on active target without altering files. |
| **Selected** | `vguard selected snap [size]` | Provisions point-in-time LVM snapshot for active target. |
| **Selected** | `vguard selected mkdir <subfolder>` | Creates subfolder inheriting parent policy on active target. |
| **Selected** | `vguard selected delete` | Safe removal of active target with double verification. |
| **Global** | `vguard list` \| `vguard ls` \| `vguard status` | Lists all managed volumes, highlighting `[ACTIVE]` volume. |
| `Global` | `vguard create <tier> <name> [size]` | Provisions new volume and automatically marks it as active target. |
| `Global` | `vguard heal-all` | Audits and heals all managed storage volumes system-wide. |
| `Global` | `vguard update` | Self-updates VGUARD codebase via Git pull and reinstalls links. |
| `Global` | `vguard uninstall` | Launches VGUARD uninstaller. |

---

## Example v2.0 Stateful Workflow

```bash
# 1. Select active volume context
sudo vguard select nvme_fast redis_prod

# 2. Inspect active target status
sudo vguard selected status

# 3. Hot-extend active volume by +10G
sudo vguard selected resize +10G

# 4. Heal permissions and SELinux on active volume
sudo vguard selected heal
```

