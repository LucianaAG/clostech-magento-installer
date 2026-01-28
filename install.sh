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
    echo -e "${BLUE}" >&2
    echo "╔═══════════════════════════════════════════════════════════════╗" >&2
    echo "║                                                               ║" >&2
    echo "║              CLOSTECH - Instalador de Módulo                  ║" >&2
    echo "║                      para Magento 2                           ║" >&2
    echo "║                                                               ║" >&2
    echo "╚═══════════════════════════════════════════════════════════════╝" >&2
    echo -e "${NC}" >&2
}

print_success() {
    echo -e "${GREEN}✔ $1${NC}" >&2
}

print_error() {
    echo -e "${RED}✖ $1${NC}" >&2
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}" >&2
}

print_info() {
    echo -e "${BLUE}➜ $1${NC}" >&2
}

check_magento() {
    print_info "Verificando instalación de Magento..."
    
    if [ ! -f "bin/magento" ]; then
        print_error "No se encontró Magento en el directorio actual."
        print_warning "Ejecutá este script desde la raíz de tu instalación de Magento."
        print_warning "Ejemplo: cd /var/www/html/magento && curl -s $MODULE_URL | bash"
        exit 1
    fi
    
    print_success "Magento encontrado"
}

check_permissions() {
    print_info "Verificando permisos..."
    
    if [ ! -w "src/app/code" ]; then
        print_error "No tenés permisos de escritura en app/code"
        print_warning "Ejecutá el script con sudo o verificá los permisos."
        exit 1
    fi
    
    print_success "Permisos correctos"
}

download_module() {
    print_info "Copiando módulo desde archivo local..."
    
    # Crear directorio temporal
    TMP_DIR=$(mktemp -d)
    TMP_FILE="$TMP_DIR/clostech-module.zip"
    
    # Para testing: copiar desde /tmp en lugar de descargar
    if [ -f "/tmp/clostech-module.zip" ]; then
        cp /tmp/clostech-module.zip "$TMP_FILE"
    else
        print_error "No se encontró el archivo /tmp/clostech-module.zip"
        print_warning "Asegúrate de crear el ZIP primero."
        exit 1
    fi
    
    print_success "Módulo copiado desde /tmp/clostech-module.zip"
    echo "$TMP_FILE"
}

install_module() {
    local ZIP_FILE=$1
    
    print_info "Instalando módulo..."
    
    # Crear directorio si no existe
    mkdir -p "src/app/code/Clostech"
    
    # Descomprimir
    if command -v unzip &> /dev/null; then
        unzip -q "$ZIP_FILE" -d "src/app/code/Clostech/"
    else
        print_error "Se necesita unzip para instalar el módulo."
        exit 1
    fi
    
    # Verificar que se instaló
    if [ ! -d "$MODULE_PATH" ]; then
        print_error "Error al instalar el módulo."
        exit 1
    fi
    
    print_success "Módulo instalado en $MODULE_PATH"
}

run_magento_commands() {
    print_info "Ejecutando comandos de Magento..."
    
    print_info "  → setup:upgrade"
    bin/magento setup:upgrade --quiet
    
    print_info "  → cache:flush"
    bin/magento cache:flush --quiet
    
    print_success "Comandos ejecutados correctamente"
}

cleanup() {
    print_info "Limpiando archivos temporales..."
    rm -rf "$TMP_DIR"
    print_success "Limpieza completada"
}

print_footer() {
    echo "" >&2
    echo -e "${GREEN}" >&2
    echo "╔═══════════════════════════════════════════════════════════════╗" >&2
    echo "║                                                               ║" >&2
    echo "║           ¡Módulo instalado correctamente!                    ║" >&2
    echo "║                                                               ║" >&2
    echo "╚═══════════════════════════════════════════════════════════════╝" >&2
    echo -e "${NC}" >&2
    echo "" >&2
    print_info "Próximo paso: Completá el onboarding en:"
    echo -e "    ${BLUE}$ONBOARDING_URL${NC}" >&2
    echo "" >&2
}

#-------------------------------------------------------------------------------
# Main
#-------------------------------------------------------------------------------
main() {
    print_header
    
    check_magento
    check_permissions
    
    ZIP_FILE=$(download_module)
    install_module "$ZIP_FILE"
    run_magento_commands
    cleanup
    
    print_footer
}

# Ejecutar
main