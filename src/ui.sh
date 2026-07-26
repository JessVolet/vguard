#!/bin/bash
# ==============================================================================
# VGUARD - MÓDULO DE INTERFAZ DE USUARIO Y FORMATO (UI)
# ==============================================================================

# Definición de Colores ANSI
if [ -t 1 ]; then
    CLR_RESET='\030[0m'
    CLR_BOLD='\033[1m'
    CLR_DIM='\033[2m'
    
    CLR_RED='\033[0;31m'
    CLR_GREEN='\033[0;32m'
    CLR_YELLOW='\033[0;33m'
    CLR_BLUE='\033[0;34m'
    CLR_MAGENTA='\033[0;35m'
    CLR_CYAN='\033[0;36m'

    CLR_BRIGHT_GREEN='\033[1;32m'
    CLR_BRIGHT_CYAN='\033[1;36m'
    CLR_BRIGHT_RED='\033[1;31m'
    CLR_BRIGHT_YELLOW='\033[1;33m'
else
    CLR_RESET=''
    CLR_BOLD=''
    CLR_DIM=''
    CLR_RED=''
    CLR_GREEN=''
    CLR_YELLOW=''
    CLR_BLUE=''
    CLR_MAGENTA=''
    CLR_CYAN=''
    CLR_BRIGHT_GREEN=''
    CLR_BRIGHT_CYAN=''
    CLR_BRIGHT_RED=''
    CLR_BRIGHT_YELLOW=''
fi

# Fix typo ANSI reset code if needed
CLR_RESET='\033[0m'

print_banner() {
    echo -e "${CLR_BRIGHT_CYAN}"
    echo "  ██╗   ██╗██████╗ ██╗  ██╗ █████╗ ██████╗ ██████╗ "
    echo "  ██║   ██║██╔════╝██║  ██║██╔══██╗██╔══██╗██╔══██╗"
    echo "  ██║   ██║██║  ███╗██║  ██║███████║██████╔╝██║  ██║"
    echo "  ╚██╗ ██╔╝██║   ██║██║  ██║██╔══██║██╔══██╗██║  ██║"
    echo "   ╚████╔╝ ╚██████╔╝╚█████╔╝██║  ██║██║  ██║██████╔╝"
    echo "    ╚═══╝   ╚═════╝  ╚════╝ ╚═╝  ╚═╝╚═╝  ╚═╝╚═════╝ "
    echo -e "         ${CLR_DIM}Guardia & Gestión de Almacenamiento v1.0${CLR_RESET}\n"
}

msg_info() {
    echo -e "${CLR_CYAN}[*]${CLR_RESET} $1"
}

msg_success() {
    echo -e "${CLR_BRIGHT_GREEN}[✓]${CLR_RESET} $1"
}

msg_warning() {
    echo -e "${CLR_BRIGHT_YELLOW}[!]${CLR_RESET} $1"
}

msg_error() {
    echo -e "${CLR_BRIGHT_RED}[✗] ${CLR_BOLD}$1${CLR_RESET}" >&2
}

msg_section() {
    echo -e "\n${CLR_BOLD}${CLR_BRIGHT_CYAN}=== $1 ===${CLR_RESET}"
}

draw_separator() {
    echo -e "${CLR_DIM}--------------------------------------------------------------------------------${CLR_RESET}"
}
