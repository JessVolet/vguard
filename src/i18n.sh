#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE INTERNACIONALIZACIÓN (I18N: ENGLISH / ESPAÑOL)
# ==============================================================================

detect_language() {
    if [ -n "$VGUARD_LANG" ]; then
        CURRENT_LANG="$VGUARD_LANG"
        return
    fi

    if [ -n "$CFG_LANGUAGE" ]; then
        CURRENT_LANG="$CFG_LANGUAGE"
        return
    fi

    local sys_locale="${LANG:-${LC_ALL:-${LC_MESSAGES:-en}}}"
    if [[ "$sys_locale" =~ ^es ]]; then
        CURRENT_LANG="es"
    else
        CURRENT_LANG="en"
    fi
}

get_banner_subtitle() {
    if [ "$CURRENT_LANG" = "es" ]; then
        echo "Guardia & Gestión de Almacenamiento v3.0 (TUI & Políticas por Volumen)"
    else
        echo "Volume Guard & Storage Infrastructure Engine v3.0 (TUI & Per-Volume Policies)"
    fi
}

# Traduce claves sencillas según el idioma activo
t() {
    local key="$1"
    local arg1="$2"
    case "$CURRENT_LANG" in
        es)
            case "$key" in
                USAGE) echo "USO:" ;;
                CORE_COMMANDS) echo "COMANDOS PRINCIPALES / CORE:" ;;
                HELP_MORE) echo "Para ver opciones detalladas de un subcomando, usa:" ;;
                SELECTED_HELP_TITLE) echo "COMANDOS SOBRE EL OBJETIVO ACTIVO (SELECTED WORKSPACE):" ;;
                MAIN_MENU_TITLE) echo "Menú Interactivo Principal" ;;
                CAT_WORKSPACE) echo "1) Gestión de Workspace y Contexto Activo" ;;
                CAT_SELECTED) echo "2) Operaciones sobre el Objetivo Activo (Selected)" ;;
                CAT_GLOBAL) echo "3) Aprovisionamiento, Auditoría y Almacenamiento Global" ;;
                CAT_SYSTEM) echo "4) Configuración y Mantenimiento del Sistema" ;;
                CAT_EXIT) echo "5) Salir" ;;
                SELECT_OPTION) echo "Selecciona una opción" ;;
                CANCELLED) echo "Operación cancelada." ;;
                INVALID_OPTION) echo "Opción inválida." ;;
                LANG_CHANGED) echo "Idioma de VGUARD cambiado a:" ;;
                UPDATE_CHECKING) echo "Comprobando actualizaciones de VGUARD (Local: $arg1)..." ;;
                UPDATE_CONN_ERROR) echo "No se pudo conectar con el servidor de actualizaciones o la respuesta es inválida." ;;
                UPDATE_NEW_VERSION) echo "NUEVA VERSIÓN DISPONIBLE: $arg1" ;;
                UPDATE_CURRENT_VER) echo "Estás usando la versión $arg1." ;;
                UPDATE_INSTRUCTION) echo "Ejecuta 'sudo vguard update' para instalar la última versión." ;;
                UPDATE_SILENT_NEW) echo "Hay una nueva actualización de VGUARD disponible ($arg1). Ejecuta 'sudo vguard update'." ;;
                UPDATE_LATEST) echo "Estás utilizando la última versión de VGUARD ($arg1)." ;;
                UPDATE_ALREADY) echo "VGUARD ya está actualizado a la última versión disponible." ;;
                UPDATE_FETCHING) echo "Buscando actualizaciones en el repositorio remoto..." ;;
                UPDATE_NO_CONN) echo "No se pudo conectar con el repositorio remoto." ;;
                UPDATE_DL) echo "Nuevos cambios detectados. Descargando actualización..." ;;
                UPDATE_SUCCESS) echo "Código fuente actualizado exitosamente." ;;
                UPDATE_PULL_ERR) echo "Error al aplicar 'git pull'. Revisa cambios locales pendientes." ;;
                UPDATE_REINSTALL) echo "Reinstalando accesos directos y permisos de VGUARD..." ;;
                UPDATE_DONE) echo "VGUARD ha sido actualizado exitosamente a la última versión." ;;
                UPDATE_NOT_GIT) echo "El directorio $arg1 no es un repositorio Git válido. No se puede ejecutar 'git pull'." ;;
                UPDATE_TITLE) echo "ACTUALIZACIÓN DE VGUARD" ;;
                UPDATE_DIR_DETECTED) echo "Directorio de repositorio detectado: $arg1" ;;
                *) echo "$key" ;;
            esac
            ;;
        *)
            case "$key" in
                USAGE) echo "USAGE:" ;;
                CORE_COMMANDS) echo "CORE COMMANDS:" ;;
                HELP_MORE) echo "To view detailed options for a subcommand, use:" ;;
                SELECTED_HELP_TITLE) echo "ACTIVE TARGET OPERATIONS (SELECTED WORKSPACE):" ;;
                MAIN_MENU_TITLE) echo "Main Interactive Menu" ;;
                CAT_WORKSPACE) echo "1) Workspace & Active Context Management" ;;
                CAT_SELECTED) echo "2) Active Target Operations (Selected)" ;;
                CAT_GLOBAL) echo "3) Provisioning, Audit & Global Storage" ;;
                CAT_SYSTEM) echo "4) System Configuration & Maintenance" ;;
                CAT_EXIT) echo "5) Exit" ;;
                SELECT_OPTION) echo "Select an option" ;;
                CANCELLED) echo "Operation cancelled." ;;
                INVALID_OPTION) echo "Invalid option." ;;
                LANG_CHANGED) echo "VGUARD language set to:" ;;
                UPDATE_CHECKING) echo "Checking for VGUARD updates (Local: $arg1)..." ;;
                UPDATE_CONN_ERROR) echo "Could not connect to update server or response is invalid." ;;
                UPDATE_NEW_VERSION) echo "NEW VERSION AVAILABLE: $arg1" ;;
                UPDATE_CURRENT_VER) echo "You are using version $arg1." ;;
                UPDATE_INSTRUCTION) echo "Run 'sudo vguard update' to install the latest version." ;;
                UPDATE_SILENT_NEW) echo "A new VGUARD update is available ($arg1). Run 'sudo vguard update'." ;;
                UPDATE_LATEST) echo "You are using the latest version of VGUARD ($arg1)." ;;
                UPDATE_ALREADY) echo "VGUARD is already up to date with the latest available version." ;;
                UPDATE_FETCHING) echo "Checking for updates in the remote repository..." ;;
                UPDATE_NO_CONN) echo "Could not connect to the remote repository." ;;
                UPDATE_DL) echo "New changes detected. Downloading update..." ;;
                UPDATE_SUCCESS) echo "Source code updated successfully." ;;
                UPDATE_PULL_ERR) echo "Error applying 'git pull'. Check pending local changes." ;;
                UPDATE_REINSTALL) echo "Reinstalling VGUARD shortcuts and permissions..." ;;
                UPDATE_DONE) echo "VGUARD has been successfully updated to the latest version." ;;
                UPDATE_NOT_GIT) echo "The directory $arg1 is not a valid Git repository. Cannot run 'git pull'." ;;
                UPDATE_TITLE) echo "VGUARD UPDATE" ;;
                UPDATE_DIR_DETECTED) echo "Repository directory detected: $arg1" ;;
                *) echo "$key" ;;
            esac
            ;;
    esac
}
