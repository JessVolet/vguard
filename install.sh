#!/bin/bash
# ==============================================================================
# VGUARD - SCRIPT DE INSTALACIÓN Y ACTUALIZACIÓN GLOBAL
# ==============================================================================

set -e

# ANSI Colors
CLR_RESET='\033[0m'
CLR_BOLD='\033[1m'
CLR_BLUE='\033[0;34m'
CLR_CYAN='\033[0;36m'
CLR_GREEN='\033[0;32m'
CLR_YELLOW='\033[0;33m'

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

echo -e "${CLR_BLUE}========================================================${CLR_RESET}"
echo -e "${CLR_BOLD}     🚀 INSTALADOR / ACTUALIZADOR DE VGUARD (v3.1.0)${CLR_RESET}"
echo -e "${CLR_BLUE}========================================================${CLR_RESET}"

# Determinar rutas de instalación
if [ "$EUID" -eq 0 ]; then
    INSTALL_BIN="/usr/local/bin/vguard"
    CONFIG_DIR="/etc/vguard"
else
    INSTALL_BIN="$HOME/.local/bin/vguard"
    CONFIG_DIR="$HOME/.config/vguard"
    mkdir -p "$HOME/.local/bin"
fi

# Detectar instalación previa
if [ -f "$INSTALL_BIN" ] || [ -L "$INSTALL_BIN" ]; then
    echo -e "${CLR_CYAN}[*] Detectada instalación previa de VGUARD en: $INSTALL_BIN${CLR_RESET}"
    echo -e "${CLR_CYAN}[*] Actualizando ejecutable y renovando enlace simbólico...${CLR_RESET}"
    rm -f "$INSTALL_BIN"
else
    echo -e "${CLR_CYAN}[*] Instalando VGUARD por primera vez en: $INSTALL_BIN${CLR_RESET}"
fi

chmod +x "$SCRIPT_DIR/vguard"
ln -sf "$SCRIPT_DIR/vguard" "$INSTALL_BIN"

# Preparar y verificar configuración
echo -e "${CLR_CYAN}[*] Verificando directorio de configuración y políticas en: $CONFIG_DIR${CLR_RESET}"
mkdir -p "$CONFIG_DIR/policies"

if [ ! -f "$CONFIG_DIR/vguard.conf" ]; then
    echo -e "${CLR_GREEN}[+] Copiando plantilla inicial vguard.conf v3.1.0...${CLR_RESET}"
    cp "$SCRIPT_DIR/config/vguard.conf.example" "$CONFIG_DIR/vguard.conf"
else
    echo -e "${CLR_YELLOW}[*] El archivo de configuración $CONFIG_DIR/vguard.conf ya existe. Se mantendrá tu configuración actual.${CLR_RESET}"
fi

if [ -d "$SCRIPT_DIR/config/policies" ]; then
    cp -r "$SCRIPT_DIR/config/policies"/* "$CONFIG_DIR/policies/" 2>/dev/null || true
fi

echo -e "${CLR_BLUE}========================================================${CLR_RESET}"
echo -e "${CLR_GREEN}[OK] Instalación / Actualización completada con éxito.${CLR_RESET}"
echo -e "   - Ejecutable: ${CLR_BOLD}$INSTALL_BIN${CLR_RESET}"
echo -e "   - Configuración: ${CLR_BOLD}$CONFIG_DIR/vguard.conf${CLR_RESET}"
echo ""
echo -e "Ejecuta '${CLR_CYAN}vguard --version${CLR_RESET}' o '${CLR_CYAN}vguard${CLR_RESET}' para verificar el sistema."
echo -e "${CLR_BLUE}========================================================${CLR_RESET}"
