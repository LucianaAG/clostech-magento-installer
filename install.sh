#!/bin/bash

#===============================================================================
# Clostech Magento Module Installer
# Version: 1.0.0
#===============================================================================

set -e

#-------------------------------------------------------------------------------
# Colores para mensajes
#-------------------------------------------------------------------------------
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # Sin color

#-------------------------------------------------------------------------------
# Configuración
#-------------------------------------------------------------------------------
MODULE_URL="https://clostech.ai/downloads/magento-module.zip"
MODULE_PATH="src/app/code/Clostech/Integration"
ONBOARDING_URL="https://clostech.ai/onboarding/magento"

#-------------------------------------------------------------------------------
# Funciones
#-------------------------------------------------------------------------------
print_header() {
    echo -e "${BLUE}Clostech Magento Module Installer v1.0${NC}" >&2
    echo "" >&2
}

print_success() {
    echo -e "${GREEN}[OK]${NC} $1" >&2
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

print_info() {
    echo -e "${BLUE}[INFO]${NC} $1" >&2
}

check_magento() {
    print_info "Checking Magento installation..."
    
    if [ ! -f "bin/magento" ]; then
        print_error "Magento not found in current directory"
        print_warning "Run this script from your Magento root directory"
        print_warning "Example: cd /var/www/html/magento && curl -s https://clostech.ai/install.sh | bash"
        exit 1
    fi
    
    print_success "Magento found"
}

check_permissions() {
    print_info "Checking permissions..."
    
    if [ ! -w "src/app/code" ]; then
        print_error "No write permissions on src/app/code"
        print_warning "Run with sudo or check permissions"
        exit 1
    fi
    
    print_success "Permissions verified"
}

check_existing_installation() {
    print_info "Checking for existing installation..."
    
    if [ -d "$MODULE_PATH" ]; then
        print_warning "Module already installed at $MODULE_PATH"
        echo -n "Reinstall? This will overwrite existing files. (y/n): "
        read -r choice
        
        if [ "$choice" != "y" ] && [ "$choice" != "Y" ]; then
            print_info "Installation cancelled"
            exit 0
        fi
        
        print_info "Proceeding with reinstallation..."
    else
        print_success "No previous installation found"
    fi
}

create_backup() {
    if [ -d "$MODULE_PATH" ]; then
        print_info "Creating backup..."
        BACKUP_PATH="/tmp/clostech-backup-$(date +%Y%m%d-%H%M%S)"
        cp -r "$MODULE_PATH" "$BACKUP_PATH"
        print_success "Backup created at $BACKUP_PATH"
        echo "$BACKUP_PATH"
    else
        echo ""
    fi
}

restore_backup() {
    local BACKUP_PATH=$1
    
    if [ -n "$BACKUP_PATH" ] && [ -d "$BACKUP_PATH" ]; then
        print_warning "Restoring backup..."
        rm -rf "$MODULE_PATH"
        cp -r "$BACKUP_PATH" "$MODULE_PATH"
        print_success "Backup restored"
        rm -rf "$BACKUP_PATH"
    fi
}

download_module() {
    print_info "Downloading module..."
    
    # Crear directorio temporal
    TMP_DIR=$(mktemp -d)
    TMP_FILE="$TMP_DIR/clostech-module.zip"
    
    # Para testing: copiar desde /tmp en lugar de descargar
    if [ -f "/tmp/clostech-module.zip" ]; then
        cp /tmp/clostech-module.zip "$TMP_FILE"
    else
        print_error "File not found: /tmp/clostech-module.zip"
        exit 1
    fi
    
    print_success "Module downloaded"
    echo "$TMP_FILE"
}

install_module() {
    local ZIP_FILE=$1
    
    print_info "Installing module..."
    
    # Crear directorio si no existe
    mkdir -p "src/app/code/Clostech"
    
    # Descomprimir
    if command -v unzip &> /dev/null; then
        unzip -q "$ZIP_FILE" -d "src/app/code/Clostech/"
    else
        print_error "unzip command not found"
        exit 1
    fi
    
    # Verificar que se instaló
    if [ ! -d "$MODULE_PATH" ]; then
        print_error "Module installation failed"
        exit 1
    fi
    
    print_success "Module installed at $MODULE_PATH"
}

run_magento_commands() {
    print_info "Running Magento commands..."
    
    print_info "Running setup:upgrade..."
    bin/magento setup:upgrade --quiet
    
    print_info "Flushing cache..."
    bin/magento cache:flush --quiet
    
    # Verificar que el módulo se habilitó
    print_info "Verifying module status..."
    if bin/magento module:status | grep -q "Clostech_Integration"; then
        print_success "Module enabled successfully"
    else
        print_error "Module not enabled"
        print_warning "Check var/log/ for details"
        exit 1
    fi
    
    print_success "Magento commands completed"
}

cleanup() {
    print_info "Cleaning up temporary files..."
    rm -rf "$TMP_DIR"
    print_success "Cleanup completed"
}

print_footer() {
    echo "" >&2
    print_success "Installation completed successfully" >&2
    echo "" >&2
    print_info "Next step: Complete onboarding at:" >&2
    echo -e "  ${BLUE}${ONBOARDING_URL}${NC}" >&2
    echo "" >&2
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    print_header
    
    check_magento
    check_permissions
    check_existing_installation
    
    # Crear backup antes de instalar
    BACKUP_PATH=$(create_backup)
    
    # Intentar instalación
    if ! ZIP_FILE=$(download_module); then
        restore_backup "$BACKUP_PATH"
        exit 1
    fi
    
    if ! install_module "$ZIP_FILE"; then
        restore_backup "$BACKUP_PATH"
        cleanup
        exit 1
    fi
    
    if ! run_magento_commands; then
        restore_backup "$BACKUP_PATH"
        cleanup
        exit 1
    fi
    
    # Si todo salió bien, eliminar backup
    [ -n "$BACKUP_PATH" ] && rm -rf "$BACKUP_PATH"
    
    cleanup
    print_footer
}

# Ejecutar
main