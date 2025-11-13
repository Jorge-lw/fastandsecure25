#!/bin/bash

# Script completo para construir, subir y desplegar todas las imágenes

set -e

# Colores
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${GREEN}=== Despliegue Completo de Infraestructura Vulnerable ===${NC}\n"

# Paso 1: Obtener outputs de Terraform
echo -e "${YELLOW}Paso 1: Obteniendo información de Terraform...${NC}"
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: Terraform no ha sido aplicado. Ejecuta 'terraform apply' primero."
    exit 1
fi

AWS_REGION=$(terraform output -raw aws_region)
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
BASTION_IP=$(terraform output -raw bastion_public_ip)

export AWS_REGION
export AWS_ACCOUNT_ID
export CLUSTER_NAME

echo -e "${GREEN}✓ Región: $AWS_REGION${NC}"
echo -e "${GREEN}✓ Account ID: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}✓ Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}✓ Bastión IP: $BASTION_IP${NC}"

cd "$PROJECT_ROOT"

# Paso 2: Construir y subir imágenes
echo -e "\n${YELLOW}Paso 2: Construyendo y subiendo imágenes a ECR...${NC}"
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh

# Paso 3: Desplegar en el cluster
echo -e "\n${YELLOW}Paso 3: Desplegando aplicaciones en el cluster...${NC}"
chmod +x scripts/deploy-to-cluster.sh
/opt/homebrew/bin/bash ./scripts/deploy-to-cluster.sh

echo -e "\n${GREEN}=== Despliegue Completado ===${NC}"
echo -e "${YELLOW}Para conectarte al bastión:${NC}"
echo -e "ssh -p 22222 -i <tu-clave> ubuntu@$BASTION_IP"
echo -e "\n${YELLOW}Desde el bastión, puedes:${NC}"
echo -e "1. Configurar kubectl: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
echo -e "2. Ver pods: kubectl get pods -n vulnerable-apps"
echo -e "3. Port-forward: kubectl port-forward -n vulnerable-apps svc/vulnerable-web-app 3000:3000"

