#!/bin/bash
# Script para crear respaldos completos de jupiter en el VPS
# Versión: 1.0 - Respaldo completo de configuración y datos

# Colores para consola
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuración
PROJECT_NAME="jupiter"
VPS_USER="deploy"  # Usuario dedicado para despliegues
VPS_HOST="$PROJECT_NAME.ar"  # O la IP/dominio de tu VPS
DEPLOY_PATH="/opt/$PROJECT_NAME"  # Ruta en el VPS donde está desplegado
LOCAL_BACKUP_PATH="./backups"  # Ruta local para almacenar respaldos

# Crear directorio local de respaldo si no existe
mkdir -p "$LOCAL_BACKUP_PATH"

echo -e "${BLUE}===========================================================${NC}"
echo -e "${BLUE}Creando respaldo completo de $PROJECT_NAME desde $VPS_HOST${NC}"
echo -e "${BLUE}===========================================================${NC}"

# Verificar conexión con el VPS
echo -e "${YELLOW}Verificando conexión con el VPS...${NC}"
if ! ssh -q "$VPS_USER@$VPS_HOST" exit; then
  echo -e "${RED}Error: No se puede conectar al VPS${NC}"
  exit 1
fi

# Verificar que existe una instalación en el VPS
echo -e "${YELLOW}Verificando instalación en el VPS...${NC}"
if ! ssh "$VPS_USER@$VPS_HOST" "[ -d $DEPLOY_PATH ]"; then
  echo -e "${RED}Error: No se encontró una instalación en $DEPLOY_PATH${NC}"
  exit 1
fi

# Crear nombre para el respaldo
BACKUP_DATE=$(date +"%Y%m%d_%H%M%S")
BACKUP_NAME="$PROJECT_NAME-backup-$BACKUP_DATE"
BACKUP_FOLDER="$LOCAL_BACKUP_PATH/$BACKUP_NAME"
mkdir -p "$BACKUP_FOLDER"

# 1. Respaldar configuración
echo -e "${YELLOW}Respaldando archivos de configuración...${NC}"
ssh "$VPS_USER@$VPS_HOST" "cd $DEPLOY_PATH && tar -czf /tmp/config-backup.tar.gz docker-compose.yml .env nginx setup-*.sh" || true
scp "$VPS_USER@$VPS_HOST:/tmp/config-backup.tar.gz" "$BACKUP_FOLDER/"
ssh "$VPS_USER@$VPS_HOST" "rm /tmp/config-backup.tar.gz"

# 2. Respaldar la base de datos
echo -e "${YELLOW}Respaldando base de datos...${NC}"
ssh "$VPS_USER@$VPS_HOST" "cd $DEPLOY_PATH && docker compose exec -T postgres pg_dump -U postgres $PROJECT_NAME > /tmp/database-backup.sql" || true
scp "$VPS_USER@$VPS_HOST:/tmp/database-backup.sql" "$BACKUP_FOLDER/"
ssh "$VPS_USER@$VPS_HOST" "rm /tmp/database-backup.sql"

# 3. Respaldar datos de RabbitMQ (mensajes pendientes)
echo -e "${YELLOW}Respaldando configuración de RabbitMQ...${NC}"
ssh "$VPS_USER@$VPS_HOST" "cd $DEPLOY_PATH && docker compose exec -T rabbitmq rabbitmqctl export_definitions /tmp/rabbitmq-definitions.json && docker compose cp rabbitmq:/tmp/rabbitmq-definitions.json /tmp/" || true
scp "$VPS_USER@$VPS_HOST:/tmp/rabbitmq-definitions.json" "$BACKUP_FOLDER/" 2>/dev/null || echo -e "${YELLOW}No se pudo respaldar configuración de RabbitMQ${NC}"
ssh "$VPS_USER@$VPS_HOST" "rm /tmp/rabbitmq-definitions.json" 2>/dev/null || true

# 4. Crear archivo de información
cat > "$BACKUP_FOLDER/backup-info.txt" << EOF
Respaldo de $PROJECT_NAME
Fecha: $BACKUP_DATE
Servidor: $VPS_HOST
Ruta de despliegue: $DEPLOY_PATH

Contenido del respaldo:
- config-backup.tar.gz: Archivos de configuración
- database-backup.sql: Volcado de la base de datos PostgreSQL
- rabbitmq-definitions.json: Definiciones de RabbitMQ (si está disponible)

Para restaurar:
1. Descomprimir config-backup.tar.gz en el servidor destino
2. Restaurar la BD: cat database-backup.sql | docker compose exec -T postgres psql -U postgres $PROJECT_NAME
3. Restaurar RabbitMQ: docker compose cp rabbitmq-definitions.json rabbitmq:/tmp/ && docker compose exec rabbitmq rabbitmqctl import_definitions /tmp/rabbitmq-definitions.json
EOF

# 5. Crear archivo único de respaldo (opcional)
echo -e "${YELLOW}Creando archivo único de respaldo...${NC}"
cd "$LOCAL_BACKUP_PATH"
tar -czf "$BACKUP_NAME.tar.gz" "$BACKUP_NAME"

echo -e "${GREEN}===========================================================${NC}"
echo -e "${GREEN}Respaldo completado${NC}"
echo -e "${GREEN}===========================================================${NC}"
echo ""
echo -e "${YELLOW}Archivos de respaldo disponibles en:${NC}"
echo "- Directorio: $BACKUP_FOLDER"
echo "- Archivo: $LOCAL_BACKUP_PATH/$BACKUP_NAME.tar.gz"
