#!/bin/bash
# ==============================================================================
# VGUARD - SCRIPT DE DESINSTALACIÓN Y LIMPIEZA
# ==============================================================================

set -e

echo "========================================================"
echo "          DESINSTALADOR DE VGUARD-S (v1.0)"
echo "========================================================"

INSTALL_BIN_ROOT="/usr/local/bin/vguard"
CONFIG_DIR_ROOT="/etc/vguard"

INSTALL_BIN_USER="$HOME/.local/bin/vguard"
CONFIG_DIR_USER="$HOME/.config/vguard"

echo "[!] Esta acción desinstalará la herramienta CLI VGUARD de tu sistema."
echo "[!] Los datos y volúmenes de almacenamiento gestionados (/mnt/sda1, /mnt/nvme_fast) NO serán eliminados."
echo ""

read -p "¿Deseas continuar con la desinstalación de VGUARD? (s/N): " confirm
if [[ ! "$confirm" =~ ^[sS]$ ]]; then
    echo "[*] Desinstalación cancelada."
    exit 0
fi

# Eliminar binarios
if [ -f "$INSTALL_BIN_ROOT" ] || [ -L "$INSTALL_BIN_ROOT" ]; then
    if [ "$EUID" -eq 0 ]; then
        echo "[*] Eliminando ejecutable en $INSTALL_BIN_ROOT..."
        rm -f "$INSTALL_BIN_ROOT"
    else
        echo "[!] Se requiere ejecutarse con sudo para eliminar $INSTALL_BIN_ROOT."
    fi
fi

if [ -f "$INSTALL_BIN_USER" ] || [ -L "$INSTALL_BIN_USER" ]; then
    echo "[*] Eliminando ejecutable en $INSTALL_BIN_USER..."
    rm -f "$INSTALL_BIN_USER"
fi

# Preguntar por archivos de configuración
echo ""
read -p "¿Deseas eliminar también los archivos de configuración (/etc/vguard o ~/.config/vguard)? (s/N): " confirm_config

if [[ "$confirm_config" =~ ^[sS]$ ]]; then
    if [ "$EUID" -eq 0 ] && [ -d "$CONFIG_DIR_ROOT" ]; then
        echo "[*] Eliminando directorio de configuración $CONFIG_DIR_ROOT..."
        rm -rf "$CONFIG_DIR_ROOT"
    fi

    if [ -d "$CONFIG_DIR_USER" ]; then
        echo "[*] Eliminando directorio de configuración $CONFIG_DIR_USER..."
        rm -rf "$CONFIG_DIR_USER"
    fi
    echo "[OK] Archivos de configuración eliminados."
else
    echo "[*] Archivos de configuración preservados."
fi

echo "========================================================"
echo "[OK] Desinstalación de VGUARD completada."
echo "========================================================"
