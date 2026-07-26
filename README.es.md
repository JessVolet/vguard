# VGUARD (Guardia de Almacenamiento y Motor de Políticas de Infraestructura)

VGUARD es una herramienta CLI de automatización modular y declarativa diseñada para aplicar, auditar y mantener las políticas de almacenamiento, asignación de volúmenes LVM, permisos POSIX y contextos de seguridad SELinux en entornos de servidor Linux (familia Fedora Server / RHEL).

Esta herramienta está diseñada específicamente para automatizar y hacer cumplir las políticas de infraestructura establecidas en la especificación [ServerInfraestructureDockers](https://gitlab.com/sowtarez/ServerInfraestructureDockers).

Traducciones de documentación:
- [Documentación en Inglés (README.md)](file:///home/vsynlo/Proyectos/Self/vguard/README.md)

---

## Visión General de Infraestructura y Políticas

VGUARD actúa como un motor de políticas automatizado para el almacenamiento del host y las cargas de trabajo contenedorizadas ejecutadas en Fedora Server (arquitectura Lenovo ThinkCentre M920s).

### 1. Topología de Almacenamiento y Capas Híbridas

- **Capa de Alto Rendimiento / IOPS (NVMe SSD):**
  - Volumen Lógico `fedora_server-root` (15 GiB, XFS): Sistema operativo e instalación base de paquetes aislados.
  - Volumen Lógico `fedora_server-containers` (50 GiB, XFS): Dedicado a `/var/lib/containers` para capas de imágenes de contenedores y estados efímeros.
  - Reserva en Volume Group (`fedora_server`, ~409 GiB): Espacio retenido para la asignación dinámica Just-In-Time (JIT) de Volúmenes Lógicos independientes (`vguard create lvm_nvme_fast`) dedicados a bases de datos relacionales (MySQL, PostgreSQL, Redis).

- **Capa de Alta Capacidad (SATA HDD):**
  - Partición `/dev/sda1` montada en `/mnt/sda1` (ext4): Reservada para cargas de almacenamiento masivo, respaldos fríos, repositorios Git (Gitea) y archivos de usuario en WebDAV.
  - Segregación estricta de directorios: `/mnt/sda1/servicios/`, `/mnt/sda1/compartido/`, `/mnt/sda1/sistema/`.

### 2. Reglas de Contenedorización y Seguridad

- **Prohibición de Volúmenes Anónimos:** Todos los contenedores en Podman/Docker deben utilizar Bind Mounts explícitos apuntando a rutas físicas del host. Los volúmenes nombrados anónimos en `/var/lib/containers/storage/volumes/` están estrictamente prohibidos.
- **Cumplimiento de SELinux:** Las rutas asignadas deben estar etiquetadas con los contextos de seguridad correspondientes (`container_file_t` para contenedores, `samba_share_t` para carpetas compartidas SMB/NFS).
- **Aislamiento de Red:** Los microservicios se comunican mediante una red bridge dedicada (`frontend_proxy`). No se exponen puertos directos al host a menos que sea estrictamente necesario para servicios de infraestructura fija (ej. DNS o SSH).

---

## Arquitectura del Repositorio

```text
vguard/
├── README.md               # Documentación principal (Inglés)
├── README.es.md            # Documentación secundaria (Español)
├── install.sh              # Script de instalación global (/usr/local/bin o ~/.local/bin)
├── vguard                  # Ejecutable principal y enrutador de comandos
├── config/
│   └── vguard.conf.example # Configuración por defecto de políticas de infraestructura
└── src/
    ├── ui.sh               # Formato de terminal y utilidades de salida
    ├── config.sh           # Gestor de configuración y procesador de políticas
    ├── create.sh           # Aprovisionamiento de volúmenes, montaje y LVM
    ├── heal.sh             # Motor de auditoría y autocuración (Self-Healing)
    ├── status.sh           # Inventario global e inspección de desviaciones
    └── snap.sh             # Gestión de ciclo de vida de Snapshots LVM y Rollback
```

---

## Configuración (`vguard.conf`)

Las políticas globales del sistema se declaran en `/etc/vguard/vguard.conf` (o en la ruta de usuario `$HOME/.config/vguard/vguard.conf`):

```bash
# Volume Group LVM
VG_NAME="fedora_server"

# Puntos de Montaje de Infraestructura
PATH_HDD_SERVICIOS="/mnt/sda1/servicios"
PATH_HDD_COMPARTIDO="/mnt/sda1/compartido"
PATH_HDD_SISTEMA="/mnt/sda1/sistema"
PATH_NVME_FAST="/mnt/nvme_fast"

# Propietario por Defecto y Metadatos
VGUARD_OWNER="vsynlo:vsynlo"
META_FILE=".vguard_meta"

# Contextos SELinux Predeterminados
SELINUX_CONTAINER="container_file_t"
SELINUX_NETWORK="samba_share_t"
SELINUX_SYSTEM="systemd_system_unit_t"

# Permisos POSIX
PERM_POSIX_CONTAINER="770"
PERM_POSIX_NETWORK="775"
PERM_POSIX_SYSTEM="750"
```

---

## Estado Declarativo (`.vguard_meta`)

Durante la creación, VGUARD inyecta un archivo de metadatos protegido (`chmod 600 root:root`) en la raíz de la carpeta de almacenamiento gestionada:

```env
# Archivo de Estado Declarativo - VGUARD
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

## Instalación y Referencia de Comandos

### Instalación

Ejecuta el script de instalación para vincular el ejecutable y crear los archivos de política:

```bash
git clone https://github.com/sowtarez/vguard.git
cd vguard
chmod +x install.sh
sudo ./install.sh
```

### Resumen de Comandos CLI

| Comando | Descripción |
| :--- | :--- |
| `vguard` | Inicia el menú interactivo guiado. |
| `vguard init` | Inicializa la configuración por defecto en `/etc/vguard/vguard.conf`. |
| `vguard create [tier] [nombre] [tamaño]` | Aprovisiona carpetas de servicio o Volúmenes Lógicos LVM. |
| `vguard status` | Escanea los volúmenes gestionados y muestra el estado de salud y uso en disco. |
| `vguard audit <ruta>` | Evalúa desviaciones de permisos respecto a `.vguard_meta` sin modificar archivos. |
| `vguard heal <ruta>` | **Autocuración:** Restablece propietario, permisos POSIX y SELinux declarados. |
| `vguard rename <target> <nuevo_nombre>` | **Renombrar:** Modifica nombre de carpeta, volumen LVM, `/etc/fstab` y `.vguard_meta`. |
| `vguard resize <target> <tamaño>` | **Extensión en Caliente:** Amplía un volumen LVM NVMe y su sistema de archivos XFS. |
| `vguard mkdir <target> <subcarpeta>` | **Subcarpeta con Herencia:** Crea subdirectorios aplicando propietario y SELinux padre. |
| `vguard remove <target>` | **Eliminación Segura:** Desmonta, elimina entradas fstab/LVM y carpetas previa doble confirmación. |
| `vguard snap <servicio> [tamaño]` | Crea un snapshot LVM instantáneo previo a actualizaciones de contenedores. |
| `vguard snap-list` | Lista los snapshots LVM activos en el Volume Group. |
| `vguard rollback <snap_nombre>` | Fusiona un snapshot LVM para revertir el estado del volumen de datos. |
| `vguard update` | **Auto-Actualización:** Ejecuta `git pull` y actualiza binarios y plantillas del sistema. |
| `vguard uninstall` | **Desinstalador:** Remueve el ejecutable VGUARD del sistema y limpia configuraciones. |

---

## Flujos de Trabajo Operativos

### Aprovisionar Almacenamiento NVMe Rápido para Bases de Datos
```bash
sudo vguard create lvm_nvme_fast mysql_prod 10G
```
*Crea `/dev/fedora_server/mysql_prod_data`, fomatea con XFS, registra en `/etc/fstab`, monta en `/mnt/nvme_fast/mysql_prod`, aplica el contexto SELinux `container_file_t`, asigna propietario `vsynlo:vsynlo` y escribe `.vguard_meta`.*

### Auditar y Reparar Desviaciones de Permisos
```bash
vguard audit /mnt/sda1/servicios/gitea
vguard heal /mnt/sda1/servicios/gitea
```

### Crear Snapshots LVM Previos a Migraciones
```bash
sudo vguard snap mysql_prod 5G
```
