#!/bin/bash
# Script para configurar la autenticación de las herramientas de monitoreo
# Versión: 1.0

set -e  # Exit on error

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_NAME="jupiter"

echo -e "${BLUE}==========================================================${NC}"
echo -e "${BLUE}Configurando autenticación para herramientas de monitoreo${NC}"
echo -e "${BLUE}==========================================================${NC}"

# Verificar si estamos ejecutando como root o con sudo
if [ "$(id -u)" -ne 0 ]; then
    echo -e "${RED}Este script debe ejecutarse como root o con sudo${NC}"
    exit 1
fi

# Verificar que Nginx está instalado
if ! command -v nginx &> /dev/null; then
    echo -e "${RED}Error: Nginx no está instalado${NC}"
    exit 1
fi

# Verificar que htpasswd está disponible
if ! command -v htpasswd &> /dev/null; then
    echo -e "${YELLOW}Instalando apache2-utils para obtener htpasswd...${NC}"
    apt-get update
    apt-get install -y apache2-utils
fi

# Función para crear o actualizar archivo .htpasswd
create_or_update_htpasswd() {
    local htpasswd_file="/etc/nginx/.htpasswd"
    local username="$1"
    local password="$2"

    # Verificar si el archivo .htpasswd ya existe
    if [ -f "$htpasswd_file" ]; then
        # Verificar si el usuario ya existe
        if htpasswd -v "$htpasswd_file" "$username" &> /dev/null; then
            # Actualizar usuario existente
            htpasswd -b "$htpasswd_file" "$username" "$password"
            echo -e "${GREEN}Usuario '$username' actualizado${NC}"
        else
            # Añadir nuevo usuario
            htpasswd -b "$htpasswd_file" "$username" "$password"
            echo -e "${GREEN}Usuario '$username' añadido${NC}"
        fi
    else
        # Crear nuevo archivo .htpasswd
        htpasswd -c -b "$htpasswd_file" "$username" "$password"
        echo -e "${GREEN}Archivo .htpasswd creado con usuario '$username'${NC}"
    fi

    # Establecer permisos correctos
    chmod 644 "$htpasswd_file"
    chown www-data:www-data "$htpasswd_file"
}

# Solicitar credenciales
read -p "Ingrese nombre de usuario para acceso a monitoreo: " MONITOR_USER
if [ -z "$MONITOR_USER" ]; then
    MONITOR_USER="admin"
    echo -e "${YELLOW}Usando nombre de usuario predeterminado: $MONITOR_USER${NC}"
fi

MONITOR_PASSWORD=""
while [ -z "$MONITOR_PASSWORD" ]; do
    read -s -p "Ingrese contraseña para el usuario $MONITOR_USER: " MONITOR_PASSWORD
    echo
    if [ -z "$MONITOR_PASSWORD" ]; then
        echo -e "${RED}La contraseña no puede estar vacía.${NC}"
    fi
done

# Crear archivo .htpasswd para autenticación básica
echo -e "${YELLOW}Configurando autenticación básica...${NC}"
create_or_update_htpasswd "$MONITOR_USER" "$MONITOR_PASSWORD"

# Verificar que los archivos de configuración de Nginx existen
NGINX_CONF_DIR="/etc/nginx/conf.d"
if [ ! -d "$NGINX_CONF_DIR" ]; then
    echo -e "${RED}Error: Directorio de configuración de Nginx no encontrado${NC}"
    exit 1
fi

# Crear configuración SSL params si no existe
SSL_PARAMS_FILE="$NGINX_CONF_DIR/ssl-params.conf"
if [ ! -f "$SSL_PARAMS_FILE" ]; then
    echo -e "${YELLOW}Creando archivo de parámetros SSL...${NC}"
    cat > "$SSL_PARAMS_FILE" << 'EOF'
# Configuración optimizada de SSL
ssl_protocols TLSv1.2 TLSv1.3;
ssl_prefer_server_ciphers on;
ssl_ciphers ECDHE-ECDSA-AES128-GCM-SHA256:ECDHE-RSA-AES128-GCM-SHA256:ECDHE-ECDSA-AES256-GCM-SHA384:ECDHE-RSA-AES256-GCM-SHA384:ECDHE-ECDSA-CHACHA20-POLY1305:ECDHE-RSA-CHACHA20-POLY1305:DHE-RSA-AES128-GCM-SHA256:DHE-RSA-AES256-GCM-SHA384;
ssl_session_cache shared:SSL:10m;
ssl_session_timeout 1d;
ssl_session_tickets off;
ssl_stapling on;
ssl_stapling_verify on;
resolver 8.8.8.8 8.8.4.4 valid=300s;
resolver_timeout 5s;
add_header Strict-Transport-Security "max-age=63072000; includeSubdomains; preload";
add_header X-Frame-Options DENY;
add_header X-Content-Type-Options nosniff;
add_header X-XSS-Protection "1; mode=block";
EOF
    echo -e "${GREEN}Archivo ssl-params.conf creado${NC}"
fi

# Crear o actualizar zona de caché para Grafana
NGINX_CACHE_CONF="/etc/nginx/conf.d/cache-zones.conf"
if [ ! -f "$NGINX_CACHE_CONF" ]; then
    echo -e "${YELLOW}Creando configuración de caché para Nginx...${NC}"
    cat > "$NGINX_CACHE_CONF" << 'EOF'
# Definición de zonas de caché
proxy_cache_path /var/cache/nginx/grafana levels=1:2 keys_zone=grafana_cache:10m max_size=1g inactive=60m use_temp_path=off;
EOF
    echo -e "${GREEN}Archivo cache-zones.conf creado${NC}"

    # Crear directorio de caché si no existe
    mkdir -p /var/cache/nginx/grafana
    chown -R www-data:www-data /var/cache/nginx
fi

# Recargar configuración de Nginx
echo -e "${YELLOW}Recargando configuración de Nginx...${NC}"
nginx -t && systemctl reload nginx
if [ $? -eq 0 ]; then
    echo -e "${GREEN}Configuración de Nginx recargada correctamente${NC}"
else
    echo -e "${RED}Error al recargar configuración de Nginx${NC}"
    exit 1
fi

echo -e "${GREEN}==========================================================${NC}"
echo -e "${GREEN}Configuración de autenticación completada${NC}"
echo -e "${GREEN}==========================================================${NC}"
echo ""
echo -e "Acceda a las herramientas de monitoreo con:"
echo -e "Usuario: ${YELLOW}$MONITOR_USER${NC}"
echo -e "Contraseña: ${YELLOW}[La contraseña que ingresó]${NC}"
echo ""
echo -e "URLs de acceso:"
echo -e "- Grafana: ${BLUE}https://grafana.vps.$PROJECT_NAME.ar${NC}"
echo -e "- Prometheus: ${BLUE}https://prometheus.vps.$PROJECT_NAME.ar${NC}"
echo -e "- AlertManager: ${BLUE}https://alertmanager.vps.$PROJECT_NAME.ar${NC}"
