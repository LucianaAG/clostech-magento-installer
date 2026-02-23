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
MODULE_URL="https://raw.githubusercontent.com/LucianaAG/clostech-magento-installer/master/clostech-module.zip"

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

detect_magento_structure() {
    print_info "Detecting Magento directory structure..."
    
    # Detectar estructura de directorios
    if [ -d "src/app/code" ]; then
        APP_PATH="src/app/code"
        print_success "Found Docker-style structure (src/app/code)"
    elif [ -d "app/code" ]; then
        APP_PATH="app/code"
        print_success "Found standard structure (app/code)"
    else
        print_error "Magento app/code directory not found"
        print_warning "Make sure you're in Magento root directory"
        exit 1
    fi
    
    MODULE_PATH="$APP_PATH/Clostech/Integration"
}

detect_web_user() {
    print_info "Detecting web server user..."
    
    # Intentar detectar el usuario del servidor web
    if id "www-data" &>/dev/null; then
        WEB_USER="www-data"
        WEB_GROUP="www-data"
    elif id "apache" &>/dev/null; then
        WEB_USER="apache"
        WEB_GROUP="apache"
    elif id "nginx" &>/dev/null; then
        WEB_USER="nginx"
        WEB_GROUP="nginx"
    else
        WEB_USER=""
        WEB_GROUP=""
        print_warning "Could not detect web server user (www-data/apache/nginx)"
    fi
    
    if [ -n "$WEB_USER" ]; then
        print_success "Detected web server user: $WEB_USER"
    fi
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
    
    if [ ! -w "$APP_PATH" ]; then
        print_error "No write permissions on $APP_PATH"
        print_warning "Run with sudo or check permissions"
        exit 1
    fi
    
    print_success "Permissions verified"
}

check_existing_installation() {
    print_info "Checking for existing installation..."
    
    if [ -d "$MODULE_PATH" ]; then
        print_warning "Module already installed at $MODULE_PATH"
        echo -n "Reinstall? This will overwrite existing files. (y/n): " >&2
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
    
    # Descargar con curl o wget
    if command -v curl &> /dev/null; then
        curl -sL "$MODULE_URL" -o "$TMP_FILE"
    elif command -v wget &> /dev/null; then
        wget -q "$MODULE_URL" -O "$TMP_FILE"
    else
        print_error "curl or wget required"
        exit 1
    fi
    
    # Verificar que se descargó
    if [ ! -f "$TMP_FILE" ]; then
        print_error "Failed to download module"
        exit 1
    fi
    
    print_success "Module downloaded"
    echo "$TMP_FILE"
}

install_module() {
    local ZIP_FILE=$1
    
    print_info "Installing module..."
    
    # Descomprimir directamente en app/code (el ZIP ya contiene Clostech/)
    if command -v unzip &> /dev/null; then
        unzip -q "$ZIP_FILE" -d "$APP_PATH/"
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

fix_permissions() {
    print_info "Fixing file permissions..."
    
    if [ -n "$WEB_USER" ] && [ -n "$WEB_GROUP" ]; then
        # Intentar cambiar dueño con sudo si está disponible
        if command -v sudo &>/dev/null && sudo -n true 2>/dev/null; then
            sudo chown -R "$WEB_USER:$WEB_GROUP" "$MODULE_PATH" 2>/dev/null || true
            sudo chmod -R 755 "$MODULE_PATH" 2>/dev/null || true
            print_success "Permissions fixed for web server user: $WEB_USER"
        else
            # Sin sudo, intentar sin él
            chown -R "$WEB_USER:$WEB_GROUP" "$MODULE_PATH" 2>/dev/null || {
                print_warning "Could not change file ownership. If you encounter permission errors, run:"
                print_warning "  sudo chown -R $WEB_USER:$WEB_GROUP $MODULE_PATH"
                print_warning "  sudo chmod -R 755 $MODULE_PATH"
            }
        fi
    else
        chmod -R 755 "$MODULE_PATH" 2>/dev/null || true
        print_warning "Web server user not detected. If you encounter errors, fix permissions manually"
    fi
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
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    print_header
    
    check_magento
    detect_magento_structure
    detect_web_user
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
    
    # Ajustar permisos
    fix_permissions
    
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