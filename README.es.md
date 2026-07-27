# VGUARD v3.0 (Guardia de Almacenamiento y Motor de Políticas de Infraestructura)

VGUARD v3.0 es una herramienta de automatización modular, declarativa y con estado (**Stateful Workspace Context**) con soporte TUI (Interfaz de Usuario de Texto) e inspección en LECTURA PURA (Read-Only) diseñada para aplicar, auditar y mantener las políticas de almacenamiento, permisos POSIX personalizados por volumen/subcarpeta y contextos de seguridad SELinux en entornos de servidor Linux (familia Fedora Server / RHEL).

Traducciones de documentación:
- [Documentación en Inglés (README.md)](file:///home/vsynlo/Proyectos/Self/vguard/README.md)

---

## Los 4 Pilares de la Arquitectura VGUARD v3.0

### 1. Desacoplamiento Estricto de Lectura y Escritura (Audit Read-Only vs. Auto-Heal Explícito)
- **Operaciones 100% de Lectura (Read-Only):** Comandos como `vguard status`, `vguard list`, `vguard context`, `vguard audit` y `vguard selected tree` inspeccionan los atributos del sistema de archivos, montaje, uso en disco y desviaciones de seguridad. **Nunca** ejecutan `chmod`, `chown` o `restorecon` en segundo plano.
- **Operaciones de Escritura Explícitas:** Comandos como `vguard heal`, `vguard selected heal` y `vguard heal-all` aplanan y restauran permisos únicamente cuando el administrador ejecuta explícitamente el comando de reparación.

### 2. Motor de Políticas Personalizables por Volumen y Subcarpeta (`vguard.conf` y Políticas JSON)
En lugar de forzar permisos estáticos globales, VGUARD v3.0 permite declarar políticas granulares por volumen y subcarpeta en `/etc/vguard/vguard.conf` (o en `$HOME/.config/vguard/vguard.conf`):

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

Existen plantillas predefinidas en `/etc/vguard/policies/` (`default.json`, `container.json`, `database.json`, `share.json`).

### 3. Inspección en Árbol y Explorador Interactivo TUI (`tree` y `explore`)
- **Inspección en Árbol ASCII:** `vguard selected tree` renderiza una vista jerárquica de subcarpetas mostrando los atributos `[propietario:grupo modo selinux]` sin alterar ningún archivo.
- **Explorador Interactivo TUI:** `vguard selected explore` inicia un navegador visual interactivo basado en `whiptail` para recorrer subdirectorios, crear subcarpetas, editar políticas y ejecutar Auto-Heal.

### 4. Contexto de Sesión Activo (`/run/vguard/context.json`)
Selecciona un objetivo activo con `vguard select <volumen>` y ejecuta las acciones posteriores mediante `vguard selected <acción>` sin necesidad de repetir rutas.

---

## Referencia de Comandos CLI v3.0

| Categoría | Comando | Descripción |
| :--- | :--- | :--- |
| **Contexto** | `vguard select [<tier>] <volumen>` | Marca un volumen gestionado como objetivo activo del Workspace. |
| **Contexto** | `vguard context` \| `vguard selected` | Muestra detalles del objetivo activo, uso en disco, SELinux y salud. |
| **Contexto** | `vguard unselect` \| `vguard clear` | Limpia la selección de contexto activo. |
| **Selected** | `vguard selected status` | Audita el estado del objetivo activo (100% LECTURA PURA). |
| **Selected** | `vguard selected tree` | Muestra el árbol de subcarpetas en formato ASCII con atributos (LECTURA PURA). |
| **Selected** | `vguard selected explore` | Abre el explorador TUI interactivo de subcarpetas. |
| **Selected** | `vguard selected mkdir <subruta>` | Crea subcarpetas anidadas heredando políticas (ej. `onlyoffice/data/cache`). |
| **Selected** | `vguard selected set-policy <subruta>` | Establece política personalizada para una subcarpeta (`--owner 1000:1000 --mode 0775`). |
| **Selected** | `vguard selected heal` | Ejecuta auto-heal explícito per-volumen/subcarpeta en el objetivo activo. |
| **Selected** | `vguard selected audit` | Audita desviaciones de seguridad del objetivo activo (LECTURA PURA). |
| **Selected** | `vguard selected resize <tamaño>` | Extiende en caliente el volumen LVM y XFS del objetivo activo. |
| **Selected** | `vguard selected rename <nuevo>` | Renombra directorio, LVM LV, fstab y metadatos del objetivo activo. |
| **Selected** | `vguard selected snap [tamaño]` | Crea un snapshot LVM instantáneo del objetivo activo. |
| **Selected** | `vguard selected delete` | Elimina el objetivo activo previa doble confirmación de seguridad. |
| **Global** | `vguard list` \| `vguard ls` \| `vguard status` | Lista volúmenes gestionados en LECTURA PURA resaltando `[ACTIVE]`. |
| **Global** | `vguard tree [<target>]` | Muestra el árbol de subcarpetas de cualquier objetivo (LECTURA PURA). |
| **Global** | `vguard explore [<target>]` | Abre el explorador TUI interactivo para cualquier objetivo. |
| **Global** | `vguard create <tier> <nombre> [tam]` | Aprovisiona un nuevo volumen y lo marca como activo automáticamente. |
| **Global** | `vguard heal-all` | Ejecuta auto-heal explícito en todos los volúmenes del sistema. |
| **Global** | `vguard update` | Auto-actualiza el código vía Git pull y re-instala binarios. |
| **Global** | `vguard uninstall` | Lanza el asistente de desinstalación de VGUARD. |

---

## Flujo de Trabajo Operativo v3.0

```bash
# 1. Seleccionar objetivo activo en el Workspace
vguard select ocis_data

# 2. Inspeccionar el árbol en LECTURA PURA (Read-Only)
vguard selected tree

# 3. Crear estructura de subcarpetas anidadas
vguard selected mkdir onlyoffice/data/cache

# 4. Asignar política personalizada para subcarpeta
vguard selected set-policy onlyoffice --owner 1000:1000 --mode 0775

# 5. Navegar interactivamente por la TUI
vguard selected explore

# 6. Ejecutar Auto-Heal explícito para aplicar las políticas
sudo vguard selected heal
```
