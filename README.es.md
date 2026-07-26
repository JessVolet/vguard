# VGUARD v2.0 (Guardia de Almacenamiento y Motor de Políticas de Infraestructura)

VGUARD v2.0 es una herramienta CLI de automatización modular, declarativa y con estado (**Stateful Workspace Context**) diseñada para aplicar, auditar y mantener las políticas de almacenamiento, asignación de volúmenes LVM, permisos POSIX y contextos de seguridad SELinux en entornos de servidor Linux (familia Fedora Server / RHEL).

VGUARD v2.0 introduce una arquitectura de **Contexto de Sesión Activo** (`vguard select`, `vguard selected`), permitiendo a los administradores fijar un objetivo de volumen activo y ejecutar operaciones consecutivas sin necesidad de reescribir rutas o nombres en cada comando.

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

---

## Arquitectura de Contexto de Sesión Activo (`/run/vguard/context.json`)

VGUARD v2.0 gestiona el contexto activo guardándolo en `/run/vguard/context.json` (o en `$HOME/.config/vguard/context.json` si no hay root):

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

## Instalación y Referencia de Comandos CLI

### Instalación

Ejecuta el script de instalación para vincular el ejecutable y crear los archivos de política:

```bash
git clone https://github.com/tu-usuario/vguard.git
cd vguard
chmod +x install.sh
sudo ./install.sh
```

### Resumen de Comandos CLI

| Categoría | Comando | Descripción |
| :--- | :--- | :--- |
| **Contexto** | `vguard select [<tier>] <volumen>` | Marca un volumen gestionado como objetivo activo del Workspace. |
| **Contexto** | `vguard context` \| `vguard selected` | Muestra detalles del objetivo activo, uso en disco, SELinux y salud. |
| **Contexto** | `vguard unselect` \| `vguard clear` | Limpia la selección de contexto activo. |
| **Selected** | `vguard selected status` | Audita y muestra el informe completo del objetivo activo. |
| **Selected** | `vguard selected resize <tamaño>` | Extiende en caliente el volumen LVM y XFS del objetivo activo. |
| **Selected** | `vguard selected rename <nuevo>` | Renombra directorio, LVM LV, fstab y metadatos del objetivo activo. |
| **Selected** | `vguard selected heal` | Restablece propietario, permisos POSIX y SELinux del objetivo activo. |
| **Selected** | `vguard selected audit` | Evalúa desviaciones de permisos del objetivo activo sin modificar archivos. |
| **Selected** | `vguard selected snap [tamaño]` | Crea un snapshot LVM instantáneo del objetivo activo. |
| **Selected** | `vguard selected mkdir <subcarpeta>` | Crea una subcarpeta heredando políticas en el objetivo activo. |
| **Selected** | `vguard selected delete` | Elimina el objetivo activo previa doble confirmación de seguridad. |
| **Global** | `vguard list` \| `vguard ls` \| `vguard status` | Lista volúmenes gestionados resaltando la marca `[ACTIVE]`. |
| `Global` | `vguard create <tier> <nombre> [tam]` | Aprovisiona un nuevo volumen y lo marca como activo automáticamente. |
| `Global` | `vguard heal-all` | Audita y sana todos los volúmenes del sistema. |
| `Global` | `vguard update` | Auto-actualiza el código vía Git pull y re-instala binarios. |
| `Global` | `vguard uninstall` | Lanza el asistente de desinstalación de VGUARD. |

---

## Flujo de Trabajo Rápido v2.0

```bash
# 1. Seleccionar objetivo activo en el Workspace
sudo vguard select nvme_fast redis_prod

# 2. Inspeccionar estado del objetivo activo
sudo vguard selected status

# 3. Extender volumen activo en +10G
sudo vguard selected resize +10G

# 4. Restaurar permisos y SELinux en volumen activo
sudo vguard selected heal
```
