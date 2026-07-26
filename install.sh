#!/bin/bash
# ==============================================================================
# VGUARD - SCRIPT DE INSTALACIÓN Y CONFIGURACIÓN GLOBAL
# ==============================================================================

set -e

SCRIPT_DIR="$(dirname "$(realpath "${BASH_SOURCE[0]}")")"

echo "========================================================"
echo "           INSTALADOR DE VGUARD-S (v1.0)"
echo "========================================================"

# Verificar donde instalar el ejecutable
if [ "$EUID" -eq 0 ]; then
    INSTALL_BIN="/usr/local/bin/vguard"
    CONFIG_DIR="/etc/vguard"
else
    INSTALL_BIN="$HOME/.local/bin/vguard"
    CONFIG_DIR="$HOME/.config/vguard"
    mkdir -p "$HOME/.local/bin"
fi

echo "[*] Instalando ejecutable vguard en: $INSTALL_BIN"
ln -sf "$SCRIPT_DIR/vguard" "$INSTALL_BIN"
chmod +x "$SCRIPT_DIR/vguard"

echo "[*] Preparando directorio de configuración en: $CONFIG_DIR"
mkdir -p "$CONFIG_DIR"

if [ ! -f "$CONFIG_DIR/vguard.conf" ]; then
    echo "[+] Copiando plantilla inicial vguard.conf..."
    cp "$SCRIPT_DIR/config/vguard.conf.example" "$CONFIG_DIR/vguard.conf"
else
    echo "[!] El archivo $CONFIG_DIR/vguard.conf ya existe. Preservando archivo actual."
fi

echo "========================================================"
echo "[OK] Instalación completada con éxito."
echo "   - Comando: vguard"
echo "   - Configuración: $CONFIG_DIR/vguard.conf"
echo ""
echo "Ejecuta 'vguard --help' o 'vguard' para empezar a usarlo."
echo "========================================================"
