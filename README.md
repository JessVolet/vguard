# VGUARD (Volume Guard & Infrastructure Policy Engine)

VGUARD is a modular, declarative CLI automation tool designed to enforce, audit, and maintain storage, volume allocation, POSIX permissions, and SELinux security contexts on Linux server environments (Fedora Server / RHEL family).

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
git clone https://github.com/sowtarez/vguard.git
cd vguard
chmod +x install.sh
sudo ./install.sh
```

### CLI Command Summary

| Command | Description |
| :--- | :--- |
| `vguard` | Launches the interactive wizard menu. |
| `vguard init` | Initializes default configuration in `/etc/vguard/vguard.conf`. |
| `vguard create [tier] [name] [size]` | Provisions new storage folders or LVM Logical Volumes. |
| `vguard status` | Scans all managed volumes and displays health status and disk usage. |
| `vguard audit <path>` | Evaluates permission drift against `.vguard_meta` without modifying files. |
| `vguard heal <path>` | **Self-Healing:** Enforces declared ownership, POSIX permissions, and SELinux contexts. |
| `vguard rename <target> <new_name>` | **Service Rename:** Renames directory, LVM LV, fstab entries, and `.vguard_meta`. |
| `vguard resize <target> <size>` | **Hot-Extend:** Extends NVMe LVM logical volume and XFS filesystem in place. |
| `vguard mkdir <target> <subfolder>` | **Inherited Subfolder:** Creates subdirectories inheriting parent policy & SELinux. |
| `vguard remove <target>` | **Safe Removal:** Unmounts, removes fstab/LVM volumes and directories with double verification. |
| `vguard snap <service> [size]` | Provisions a point-in-time LVM snapshot before container updates. |
| `vguard snap-list` | Lists active LVM snapshots in the Volume Group. |
| `vguard rollback <snap_name>` | Merges an LVM snapshot to revert data volume state. |
| `vguard update` | **Self-Update:** Pulls latest code from Git and updates symlinks and configuration. |

---

## Operational Workflows

### Provisioning Fast NVMe Storage for Databases
```bash
sudo vguard create lvm_nvme_fast mysql_prod 10G
```
*Creates `/dev/fedora_server/mysql_prod_data`, formats with XFS, registers `/etc/fstab`, mounts to `/mnt/nvme_fast/mysql_prod`, applies `container_file_t` SELinux context, sets ownership `vsynlo:vsynlo`, and writes `.vguard_meta`.*

### Auditing and Repairing Permission Drift
```bash
vguard audit /mnt/sda1/servicios/gitea
vguard heal /mnt/sda1/servicios/gitea
```

### Creating LVM Snapshots Before Schema Migrations
```bash
sudo vguard snap mysql_prod 5G
```
