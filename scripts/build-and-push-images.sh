#!/bin/bash

# Script para construir y subir imágenes vulnerables a ECR

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Obtener variables de Terraform outputs
if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}AWS_REGION no está definida. Usando us-east-1 por defecto${NC}"
    AWS_REGION="us-east-1"
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${YELLOW}Obteniendo AWS Account ID...${NC}"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

echo -e "${GREEN}Configurando Docker para ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Directorio base de imágenes
IMAGES_DIR="docker-images"

# Lista de imágenes a construir
IMAGES=(
    "vulnerable-web-app"
    "vulnerable-api"
    "vulnerable-database"
    "vulnerable-legacy-app"
)

echo -e "${GREEN}Iniciando construcción y push de imágenes...${NC}"

for IMAGE in "${IMAGES[@]}"; do
    echo -e "\n${YELLOW}Procesando: $IMAGE${NC}"
    
    IMAGE_DIR="$IMAGES_DIR/$IMAGE"
    
    if [ ! -d "$IMAGE_DIR" ]; then
        echo -e "${RED}Error: Directorio $IMAGE_DIR no existe${NC}"
        continue
    fi
    
    ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE"
    
    echo -e "${GREEN}Construyendo imagen: $IMAGE${NC}"
    docker build -t $IMAGE:latest $IMAGE_DIR/
    
    echo -e "${GREEN}Taggeando imagen para ECR${NC}"
    docker tag $IMAGE:latest $ECR_REPO:latest
    
    echo -e "${GREEN}Subiendo imagen a ECR: $ECR_REPO${NC}"
    docker push $ECR_REPO:latest
    
    echo -e "${GREEN}✓ Imagen $IMAGE subida exitosamente${NC}"
done

echo -e "\n${GREEN}✓ Todas las imágenes han sido construidas y subidas a ECR${NC}"
echo -e "${YELLOW}Repositorios ECR:${NC}"
for IMAGE in "${IMAGES[@]}"; do
    echo "  - $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE:latest"
done

