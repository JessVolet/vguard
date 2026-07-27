#!/bin/bash
# ==============================================================================
# VGUARD - SCRIPT DE INSTALACIÓN Y ACTUALIZACIÓN GLOBAL
# ==============================================================================

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

echo "========================================================"
echo "         INSTALADOR / ACTUALIZADOR DE VGUARD-S (v1.0)"
echo "========================================================"

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
    echo "[*] Detectada instalación previa de VGUARD en: $INSTALL_BIN"
    echo "[*] Actualizando ejecutable y renovando enlace simbólico..."
    rm -f "$INSTALL_BIN"
else
    echo "[*] Instalando VGUARD por primera vez en: $INSTALL_BIN"
fi

chmod +x "$SCRIPT_DIR/vguard"
ln -sf "$SCRIPT_DIR/vguard" "$INSTALL_BIN"

# Preparar y verificar configuración
echo "[*] Verificando directorio de configuración y políticas en: $CONFIG_DIR"
mkdir -p "$CONFIG_DIR/policies"

if [ ! -f "$CONFIG_DIR/vguard.conf" ]; then
    echo "[+] Copiando plantilla inicial vguard.conf v3.0..."
    cp "$SCRIPT_DIR/config/vguard.conf.example" "$CONFIG_DIR/vguard.conf"
else
    echo "[*] El archivo de configuración $CONFIG_DIR/vguard.conf ya existe. Se mantendrá tu configuración actual."
fi

if [ -d "$SCRIPT_DIR/config/policies" ]; then
    cp -r "$SCRIPT_DIR/config/policies"/* "$CONFIG_DIR/policies/" 2>/dev/null || true
fi

echo "========================================================"
echo "[OK] Instalación / Actualización completada con éxito."
echo "   - Ejecutable: $INSTALL_BIN"
echo "   - Configuración: $CONFIG_DIR/vguard.conf"
echo ""
echo "Ejecuta 'vguard --help' o 'vguard' para verificar el sistema."
echo "========================================================"
