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
                *) echo "$key" ;;
            esac
            ;;
    esac
}
