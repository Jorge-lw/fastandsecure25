#!/bin/bash

# Script para limpiar repositorios ECR antes de hacer terraform destroy

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Limpiando repositorios ECR...${NC}"

# Obtener información de Terraform
cd terraform 2>/dev/null || { echo "Error: Ejecuta este script desde el directorio raíz del proyecto"; exit 1; }

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}No se encontró terraform.tfstate. Los repositorios pueden no existir.${NC}"
    exit 0
fi

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null || echo "")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}No se pudo obtener el AWS Account ID${NC}"
    exit 1
fi

echo -e "${GREEN}Región: $AWS_REGION${NC}"
echo -e "${GREEN}Account ID: $AWS_ACCOUNT_ID${NC}"

# Lista de repositorios (puedes obtenerlos de terraform output o hardcodearlos)
REPOS=(
    "vulnerable-web-app"
    "vulnerable-api"
    "vulnerable-database"
    "vulnerable-legacy-app"
)

for REPO in "${REPOS[@]}"; do
    echo -e "\n${YELLOW}Procesando repositorio: $REPO${NC}"
    
    # Verificar si el repositorio existe
    if aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" &>/dev/null; then
        # Obtener todas las imágenes
        IMAGE_COUNT=$(aws ecr list-images \
            --repository-name "$REPO" \
            --region "$AWS_REGION" \
            --query 'length(imageIds)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}Eliminando $IMAGE_COUNT imagen(es) de $REPO...${NC}"
            
            # Obtener todas las imágenes y eliminarlas
            IMAGES_JSON=$(aws ecr list-images \
                --repository-name "$REPO" \
                --region "$AWS_REGION" \
                --query 'imageIds[*]' \
                --output json 2>/dev/null || echo "[]")
            
            if [ "$IMAGES_JSON" != "[]" ] && [ -n "$IMAGES_JSON" ]; then
                # Eliminar usando batch-delete-image
                echo "$IMAGES_JSON" | aws ecr batch-delete-image \
                    --repository-name "$REPO" \
                    --region "$AWS_REGION" \
                    --image-ids file:///dev/stdin \
                    2>&1 | grep -v "does not exist" || true
                
                # Verificar que se eliminaron
                sleep 2
                REMAINING=$(aws ecr list-images \
                    --repository-name "$REPO" \
                    --region "$AWS_REGION" \
                    --query 'length(imageIds)' \
                    --output text 2>/dev/null || echo "0")
                
                if [ "$REMAINING" -eq "0" ]; then
                    echo -e "${GREEN}✓ Todas las imágenes eliminadas de $REPO${NC}"
                else
                    echo -e "${YELLOW}⚠ Quedan $REMAINING imagen(es) en $REPO${NC}"
                    # Intentar eliminar el repositorio completo con force
                    echo -e "${YELLOW}Intentando eliminar repositorio con force...${NC}"
                    aws ecr delete-repository \
                        --repository-name "$REPO" \
                        --region "$AWS_REGION" \
                        --force \
                        2>&1 || echo -e "${RED}No se pudo eliminar $REPO${NC}"
                fi
            fi
        else
            echo -e "${GREEN}✓ $REPO ya está vacío${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ $REPO no existe${NC}"
    fi
done

echo -e "\n${GREEN}✓ Limpieza de ECR completada${NC}"
echo -e "${YELLOW}Ahora puedes ejecutar: terraform destroy${NC}"

