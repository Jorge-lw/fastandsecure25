#!/bin/bash

# Script para verificar el estado del bastión

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Verificando estado del bastión...${NC}"

# Obtener información de Terraform
cd terraform 2>/dev/null || { echo "Error: No estás en el directorio correcto"; exit 1; }

BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
INSTANCE_ID=$(terraform output -raw bastion_instance_id 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ]; then
    echo -e "${RED}No se pudo obtener la IP del bastión desde Terraform${NC}"
    echo "Verificando instancias EC2 directamente..."
    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=bastion-host" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
        echo -e "${RED}No se encontró la instancia del bastión${NC}"
        exit 1
    fi
    
    BASTION_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")
fi

echo -e "${GREEN}IP del bastión: $BASTION_IP${NC}"
echo -e "${GREEN}Instance ID: $INSTANCE_ID${NC}"

# Verificar estado de la instancia
echo -e "\n${YELLOW}Estado de la instancia:${NC}"
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0]' --output json

# Verificar security groups
echo -e "\n${YELLOW}Security Groups:${NC}"
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' --output table

# Verificar reglas de seguridad
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

echo -e "\n${YELLOW}Reglas de entrada del Security Group:${NC}"
aws ec2 describe-security-groups --group-ids $SG_ID \
    --query 'SecurityGroups[0].IpPermissions' --output json

# Verificar logs de user-data (si es posible)
echo -e "\n${YELLOW}Intentando verificar user-data logs...${NC}"
echo "Para ver los logs, conéctate a la instancia y ejecuta:"
echo "  sudo cat /var/log/user-data.log"
echo "  sudo cat /var/log/cloud-init-output.log"

# Test de conectividad
echo -e "\n${YELLOW}Probando conectividad:${NC}"
echo "Puerto 22:"
timeout 3 bash -c "echo > /dev/tcp/$BASTION_IP/22" 2>/dev/null && echo -e "${GREEN}✓ Puerto 22 accesible${NC}" || echo -e "${RED}✗ Puerto 22 no accesible${NC}"

echo "Puerto 22222:"
timeout 3 bash -c "echo > /dev/tcp/$BASTION_IP/22222" 2>/dev/null && echo -e "${GREEN}✓ Puerto 22222 accesible${NC}" || echo -e "${RED}✗ Puerto 22222 no accesible${NC}"

echo -e "\n${YELLOW}Comando para conectarse:${NC}"
echo "ssh -i ~/.ssh/bastion_key ubuntu@$BASTION_IP"
echo "ssh -p 22222 -i ~/.ssh/bastion_key ubuntu@$BASTION_IP"

