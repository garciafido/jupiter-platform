#!/bin/bash
# Script para desplegar la configuración Hybrid (con monitoreo) en el VPS
# Versión: 1.0

set -e  # Exit on error

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuración
PROJECT_NAME="jupiter"
VPS_USER="deploy"  # Usuario dedicado para despliegues
VPS_HOST="$PROJECT_NAME.ar"  # O la IP/dominio de tu VPS
DEPLOY_PATH="/opt/$PROJECT_NAME"  # Ruta en el VPS donde se desplegará

echo -e "${BLUE}===========================================================${NC}"
echo -e "${BLUE}Desplegando configuración Hybrid para $PROJECT_NAME en $VPS_HOST${NC}"
echo -e "${BLUE}===========================================================${NC}"

# ADVERTENCIA: Este script puede sobrescribir datos en producción
echo -e "${RED}===========================================================${NC}"
echo -e "${RED}                   ¡ADVERTENCIA!                           ${NC}"
echo -e "${RED}===========================================================${NC}"
echo -e "${YELLOW}Este script sobrescribirá configuraciones y podría afectar datos existentes.${NC}"
echo -e "${YELLOW}Si el servidor ya tiene datos en producción, considera usar update-hybrid.sh.${NC}"
echo -e "${RED}===========================================================${NC}"
read -p "¿Confirmas que quieres continuar? (escribe 'yes' para confirmar): " CONFIRMATION

if [[ "$CONFIRMATION" != "yes" ]]; then
    echo -e "${YELLOW}Operación cancelada.${NC}"
    exit 0
fi

# 1. Verificar que se ejecuta desde la carpeta raíz del proyecto
if [ ! -d "./apps/$PROJECT_NAME" ]; then
  echo -e "${RED}Error: Este script debe ejecutarse desde la carpeta raíz del proyecto${NC}"
  echo -e "${YELLOW}Ejemplo: bash ./apps/$PROJECT_NAME/vps-infrastructure/deployment/scripts/deploy-hybrid.sh${NC}"
  exit 1
fi

# 2. Verificar que el proyecto está generado correctamente
echo -e "${YELLOW}Verificando estructura del proyecto...${NC}"
if [ ! -d "./apps/$PROJECT_NAME/vps-infrastructure/hybrid" ]; then
  echo -e "${RED}Error: No se encontró la estructura de hybrid${NC}"
  echo -e "${YELLOW}Asegúrate de haber generado el proyecto con: nx g project:create $PROJECT_NAME${NC}"
  exit 1
fi

# 3. Verificar que podemos conectar con el VPS
echo -e "${YELLOW}Verificando conexión con el VPS...${NC}"
if ! ssh -q "$VPS_USER@$VPS_HOST" exit; then
  echo -e "${RED}Error: No se puede conectar al VPS${NC}"
  exit 1
fi

# 4. Construir imágenes base localmente (esto es necesario para los builds)
echo -e "${YELLOW}Construyendo imágenes base localmente...${NC}"
cd "./apps/$PROJECT_NAME/bin" && bash build-base-images.sh && cd ../../..

# 5. Construir las imágenes usando docker-compose.local-prod.yml
echo -e "${YELLOW}Construyendo imágenes de servicio para despliegue...${NC}"
cd ./apps/$PROJECT_NAME
docker compose -f docker-compose.local-prod.yml build
cd ../..

# 6. Crear directorio temporal para los archivos a transferir
TEMP_DIR=$(mktemp -d)
mkdir -p "$TEMP_DIR/deploy"
echo -e "${YELLOW}Directorio temporal creado: $TEMP_DIR${NC}"

# 7. Copiar archivos necesarios al directorio temporal
echo -e "${YELLOW}Preparando archivos para despliegue...${NC}"

# Estructura básica de directorios
mkdir -p "$TEMP_DIR/deploy/monitoring/prometheus/rules"
mkdir -p "$TEMP_DIR/deploy/monitoring/alertmanager"
mkdir -p "$TEMP_DIR/deploy/monitoring/grafana/provisioning/datasources"
mkdir -p "$TEMP_DIR/deploy/monitoring/grafana/provisioning/dashboards"
mkdir -p "$TEMP_DIR/deploy/monitoring/grafana/dashboards"
mkdir -p "$TEMP_DIR/deploy/nginx/conf.d"

# Copiar archivos de vps-infrastructure/hybrid
cp -r ./apps/$PROJECT_NAME/vps-infrastructure/hybrid/* "$TEMP_DIR/deploy/"

# Copiar archivos comunes de monitoreo
cp -r ./apps/$PROJECT_NAME/vps-infrastructure/common/monitoring/* "$TEMP_DIR/deploy/monitoring/"
cp ./apps/$PROJECT_NAME/vps-infrastructure/common/docker-compose.monitoring.yml.template "$TEMP_DIR/deploy/docker-compose.monitoring.yml"

# Copiar scripts específicos
cp ./apps/$PROJECT_NAME/vps-infrastructure/scripts/setup-monitoring-auth.sh.template "$TEMP_DIR/deploy/setup-monitoring-auth.sh"
cp ./apps/$PROJECT_NAME/vps-infrastructure/scripts/setup-monitoring-mode.sh.template "$TEMP_DIR/deploy/setup-monitoring-mode.sh"

# Copiar archivos de configuración
cp ./apps/$PROJECT_NAME/docker-compose.prod.yml "$TEMP_DIR/deploy/docker-compose.yml"

# 8. Reemplazar variables en los archivos
echo -e "${YELLOW}Reemplazando variables en los archivos...${NC}"
find "$TEMP_DIR/deploy" -type f -exec sed -i "s/jupiter/$PROJECT_NAME/g" {} \;
find "$TEMP_DIR/deploy" -type f -exec sed -i "s/app-server/app-server/g" {} \;
find "$TEMP_DIR/deploy" -type f -exec sed -i "s/worker-sample/worker-sample/g" {} \;
find "$TEMP_DIR/deploy" -type f -exec sed -i "s/web-app/web-app/g" {} \;

# 9. Preparar archivo .env para producción
echo -e "${YELLOW}Generando archivo .env para producción...${NC}"
cat > "$TEMP_DIR/deploy/.env" << EOF
# Variables de entorno para producción
POSTGRES_USER=postgres
POSTGRES_PASSWORD=postgres_${PROJECT_NAME}_prod
POSTGRES_DB=${PROJECT_NAME}
RABBITMQ_DEFAULT_USER=rabbitmq
RABBITMQ_DEFAULT_PASS=rabbitmq_${PROJECT_NAME}_prod

# Variables para monitoreo
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=admin_${PROJECT_NAME}_grafana
ALERT_EMAIL_TO=admin@${PROJECT_NAME}.ar

# Configuración de health checks
HEALTH_CHECK_INTERVAL=30s
HEALTH_CHECK_TIMEOUT=10s
HEALTH_CHECK_RETRIES=3
HEALTH_CHECK_START_PERIOD=30s
EOF

# 10. Exportar imágenes Docker
echo -e "${YELLOW}Exportando imágenes Docker...${NC}"

# Definir nombres de imágenes
APP_SERVER_IMG="$PROJECT_NAME-app-server:prod"
WEBAPP_IMG="$PROJECT_NAME-webapp:prod"
WORKER_IMG="$PROJECT_NAME-worker-sample:prod"
NODE_BASE_IMG="$PROJECT_NAME-node-base:prod"
NGINX_BASE_IMG="$PROJECT_NAME-nginx-base:prod"

# Obtener los nombres de las imágenes construidas y etiquetarlas
APP_SERVER_ACTUAL=$(docker compose -f ./apps/$PROJECT_NAME/docker-compose.local-prod.yml images app-server -q)
WEBAPP_ACTUAL=$(docker compose -f ./apps/$PROJECT_NAME/docker-compose.local-prod.yml images web-app -q)
WORKER_ACTUAL=$(docker compose -f ./apps/$PROJECT_NAME/docker-compose.local-prod.yml images worker-sample -q)

if [ ! -z "$APP_SERVER_ACTUAL" ]; then
  docker tag $APP_SERVER_ACTUAL $APP_SERVER_IMG
fi

if [ ! -z "$WEBAPP_ACTUAL" ]; then
  docker tag $WEBAPP_ACTUAL $WEBAPP_IMG
fi

if [ ! -z "$WORKER_ACTUAL" ]; then
  docker tag $WORKER_ACTUAL $WORKER_IMG
fi

# Crear lista de imágenes para exportar
IMAGE_LIST=(
  "$APP_SERVER_IMG"
  "$WEBAPP_IMG"
  "$WORKER_IMG"
  "$NODE_BASE_IMG"
  "$NGINX_BASE_IMG"
)

# Exportar imágenes a un archivo tar
echo -e "${YELLOW}Exportando imágenes a archivo tar...${NC}"
echo -e "${YELLOW}Esto puede tomar varios minutos dependiendo del tamaño de las imágenes...${NC}"
docker save -o "$TEMP_DIR/$PROJECT_NAME-images.tar" ${IMAGE_LIST[@]}
if [ $? -ne 0 ]; then
  echo -e "${RED}Error: Falló la exportación de imágenes${NC}"
  exit 1
fi

# 11. Transferir archivos al VPS
echo -e "${YELLOW}Transfiriendo archivos al VPS... Esto puede tardar varios minutos...${NC}"
echo -e "${YELLOW}Tamaño del archivo de imágenes: $(du -h "$TEMP_DIR/$PROJECT_NAME-images.tar" | cut -f1)${NC}"

# Asegurarse de que el directorio existe en el VPS
ssh "$VPS_USER@$VPS_HOST" "mkdir -p $DEPLOY_PATH"

# Verificar si es una instalación existente
if ssh "$VPS_USER@$VPS_HOST" "[ -f $DEPLOY_PATH/docker-compose.yml ]"; then
    echo -e "${YELLOW}Detectada instalación existente.${NC}"
    echo -e "${YELLOW}Haciendo backup de archivos importantes...${NC}"

    # Crear respaldo de archivos cruciales
    BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
    ssh "$VPS_USER@$VPS_HOST" "cd $DEPLOY_PATH && mkdir -p backups && \
        cp docker-compose.yml backups/docker-compose.yml.$BACKUP_DATE && \
        cp .env backups/.env.$BACKUP_DATE 2>/dev/null || true && \
        cp -r nginx backups/nginx.$BACKUP_DATE 2>/dev/null || true"
fi

# Transferir todos los archivos excepto las imágenes (más rápido)
echo -e "${YELLOW}Transfiriendo archivos de configuración...${NC}"
rsync -avz --exclude="$PROJECT_NAME-images.tar" "$TEMP_DIR/deploy/" "$VPS_USER@$VPS_HOST:$DEPLOY_PATH/"

# Transferir el archivo de imágenes (puede tardar más)
echo -e "${YELLOW}Transfiriendo archivo de imágenes Docker...${NC}"
rsync -avz "$TEMP_DIR/$PROJECT_NAME-images.tar" "$VPS_USER@$VPS_HOST:$DEPLOY_PATH/"

# 12. Ejecutar el despliegue en el VPS
echo -e "${YELLOW}Ejecutando despliegue en el VPS...${NC}"

# Crear script de despliegue en el VPS
cat > "$TEMP_DIR/deploy-vps.sh" << 'EOF'
#!/bin/bash
# Script para ejecutar el despliegue en el VPS

# Colores para output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

PROJECT_NAME=$(basename $(pwd))

echo -e "${BLUE}===========================================================${NC}"
echo -e "${BLUE}Desplegando $PROJECT_NAME en el VPS${NC}"
echo -e "${BLUE}===========================================================${NC}"

# Verificar que existe el archivo de imágenes
if [ ! -f "$PROJECT_NAME-images.tar" ]; then
    echo -e "${RED}Error: No se encontró el archivo de imágenes${NC}"
    exit 1
fi

# Cargar imágenes Docker
echo -e "${YELLOW}Cargando imágenes Docker...${NC}"
docker load -i $PROJECT_NAME-images.tar

# Detener servicios existentes
if docker compose ps -q 2>/dev/null | grep -q .; then
    echo -e "${YELLOW}Deteniendo servicios existentes...${NC}"
    docker compose down || true
fi

# Iniciar servicios principales
echo -e "${YELLOW}Iniciando servicios principales...${NC}"
docker compose -f docker-compose.yml up -d

# Verificar estado
echo -e "${YELLOW}Verificando estado de los servicios...${NC}"
docker compose ps

# Configurar permisos para scripts
chmod +x setup-monitoring-auth.sh setup-monitoring-mode.sh

echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}Despliegue básico completado${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo -e "${YELLOW}Para configurar el monitoreo:${NC}"
echo -e "1. Ejecuta: ${BLUE}sudo ./setup-monitoring-auth.sh${NC}"
echo -e "2. Inicia los servicios: ${BLUE}docker compose -f docker-compose.monitoring.yml up -d${NC}"
echo -e "   o usa el script de modo: ${BLUE}./setup-monitoring-mode.sh [off|light|full]${NC}"
EOF

# Transferir y ejecutar script
rsync -avz "$TEMP_DIR/deploy-vps.sh" "$VPS_USER@$VPS_HOST:$DEPLOY_PATH/"
ssh "$VPS_USER@$VPS_HOST" "cd $DEPLOY_PATH && chmod +x deploy-vps.sh && ./deploy-vps.sh"

# 13. Configurar Nginx
echo -e "${YELLOW}Configurando Nginx...${NC}"
ssh "$VPS_USER@$VPS_HOST" "cd $DEPLOY_PATH && sudo cp ./nginx/conf.d/*.conf /etc/nginx/conf.d/ && sudo nginx -t && sudo systemctl reload nginx"

# 14. Instrucciones finales
echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}Despliegue de configuración Hybrid completado${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo -e "${YELLOW}Acciones finales necesarias:${NC}"
echo -e "1. Configura los registros DNS para los subdominios de monitoreo:"
echo -e "   - grafana.vps.$PROJECT_NAME.ar"
echo -e "   - prometheus.vps.$PROJECT_NAME.ar"
echo -e "   - alertmanager.vps.$PROJECT_NAME.ar"
echo -e ""
echo -e "2. Conéctate al VPS y configura la autenticación para monitoreo:"
echo -e "   ${BLUE}ssh $VPS_USER@$VPS_HOST${NC}"
echo -e "   ${BLUE}cd $DEPLOY_PATH${NC}"
echo -e "   ${BLUE}sudo ./setup-monitoring-auth.sh${NC}"
echo -e ""
echo -e "3. Inicia los servicios de monitoreo:"
echo -e "   ${BLUE}cd $DEPLOY_PATH${NC}"
echo -e "   ${BLUE}./setup-monitoring-mode.sh full${NC}"
echo -e ""
echo -e "${YELLOW}Los servicios deberían estar disponibles en:${NC}"
echo -e "- Frontend: ${BLUE}https://$PROJECT_NAME.ar${NC}"
echo -e "- API: ${BLUE}https://$PROJECT_NAME.ar/api${NC}"
echo -e "- Admin RabbitMQ: ${BLUE}https://$PROJECT_NAME.ar/rabbitmq${NC}"
echo -e "- Grafana: ${BLUE}https://grafana.vps.$PROJECT_NAME.ar${NC} (después de configurar)"
echo -e "- Prometheus: ${BLUE}https://prometheus.vps.$PROJECT_NAME.ar${NC} (después de configurar)"
echo -e "- AlertManager: ${BLUE}https://alertmanager.vps.$PROJECT_NAME.ar${NC} (después de configurar)"

# 15. Limpiar archivos temporales
rm -rf "$TEMP_DIR"
