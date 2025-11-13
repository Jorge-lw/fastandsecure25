#!/bin/bash

# Script para agregar el rol del bastión al ConfigMap aws-auth del cluster EKS

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Agregando Bastión al Cluster EKS ===${NC}\n"

# Obtener información de Terraform
cd terraform 2>/dev/null || { echo "Error: Ejecuta este script desde el directorio raíz del proyecto"; exit 1; }

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}No se encontró terraform.tfstate${NC}"
    exit 1
fi

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "lab-cluster")
BASTION_ROLE_ARN=$(terraform output -raw bastion_role_arn 2>/dev/null || echo "")

if [ -z "$BASTION_ROLE_ARN" ]; then
    # Intentar obtener el ARN del rol desde Terraform state
    BASTION_ROLE_ARN=$(terraform state show aws_iam_role.bastion 2>/dev/null | grep "arn:" | head -1 | awk '{print $3}' || echo "")
fi

if [ -z "$BASTION_ROLE_ARN" ]; then
    echo -e "${RED}No se pudo obtener el ARN del rol del bastión${NC}"
    echo -e "${YELLOW}Obteniendo desde AWS directamente...${NC}"
    BASTION_ROLE_ARN=$(aws iam get-role --role-name bastion-role --query 'Role.Arn' --output text 2>/dev/null || echo "")
fi

if [ -z "$BASTION_ROLE_ARN" ]; then
    echo -e "${RED}No se pudo obtener el ARN del rol del bastión${NC}"
    exit 1
fi

echo -e "${GREEN}Región: $AWS_REGION${NC}"
echo -e "${GREEN}Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Bastion Role ARN: $BASTION_ROLE_ARN${NC}"
echo ""

# Configurar kubectl
echo -e "${YELLOW}[1] Configurando kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" 2>/dev/null && \
    echo -e "${GREEN}✓ kubectl configurado${NC}" || \
    { echo -e "${RED}✗ Error configurando kubectl${NC}"; exit 1; }

# Verificar que el cluster está accesible
echo -e "\n${YELLOW}[2] Verificando acceso al cluster...${NC}"
kubectl cluster-info > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ Cluster accesible${NC}" || \
    { echo -e "${RED}✗ No se puede acceder al cluster${NC}"; exit 1; }

# Obtener el ConfigMap aws-auth actual
echo -e "\n${YELLOW}[3] Obteniendo ConfigMap aws-auth actual...${NC}"
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth.yaml 2>/dev/null && \
    echo -e "${GREEN}✓ ConfigMap obtenido${NC}" || \
    { echo -e "${RED}✗ No se pudo obtener el ConfigMap${NC}"; exit 1; }

# Verificar si el rol ya está en el ConfigMap
if grep -q "$BASTION_ROLE_ARN" /tmp/aws-auth.yaml; then
    echo -e "${YELLOW}⚠ El rol del bastión ya está en el ConfigMap${NC}"
    exit 0
fi

# Agregar el rol del bastión al ConfigMap
echo -e "\n${YELLOW}[4] Agregando rol del bastión al ConfigMap...${NC}"

# Obtener el contenido actual del mapRoles
CURRENT_MAPROLES=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' 2>/dev/null || echo "")

if [ -z "$CURRENT_MAPROLES" ]; then
    # Si no existe mapRoles, crear uno nuevo
    NEW_MAPROLES="- rolearn: $BASTION_ROLE_ARN
  username: bastion-user
  groups:
    - system:masters"
else
    # Agregar el nuevo rol al mapRoles existente
    NEW_MAPROLES="$CURRENT_MAPROLES
- rolearn: $BASTION_ROLE_ARN
  username: bastion-user
  groups:
    - system:masters"
fi

# Obtener mapUsers si existe
CURRENT_MAPUSERS=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapUsers}' 2>/dev/null || echo "")

# Crear el patch
cat > /tmp/aws-auth-patch.yaml <<EOF
data:
  mapRoles: |
$(echo "$NEW_MAPROLES" | sed 's/^/    /')
EOF

if [ -n "$CURRENT_MAPUSERS" ]; then
    echo "  mapUsers: |" >> /tmp/aws-auth-patch.yaml
    echo "$CURRENT_MAPUSERS" | sed 's/^/    /' >> /tmp/aws-auth-patch.yaml
fi

# Aplicar el patch
kubectl patch configmap aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yaml)" && \
    echo -e "${GREEN}✓ Rol del bastión agregado al ConfigMap${NC}" || \
    { echo -e "${RED}✗ Error agregando el rol. Intentando con kubectl apply...${NC}"; \
      kubectl get configmap aws-auth -n kube-system -o yaml | \
        sed "/mapRoles: |/a\\
    - rolearn: $BASTION_ROLE_ARN\\
      username: bastion-user\\
      groups:\\
        - system:masters" | \
        kubectl apply -f - && \
        echo -e "${GREEN}✓ Rol agregado usando apply${NC}" || \
        { echo -e "${RED}✗ Error. Por favor, agrega manualmente el rol al ConfigMap${NC}"; exit 1; } }

# Limpiar archivos temporales
rm -f /tmp/aws-auth.yaml /tmp/aws-auth-patch.yaml

echo -e "\n${GREEN}=== Bastión agregado al cluster EKS ===${NC}"
echo -e "${YELLOW}Ahora puedes usar kubectl desde el bastión${NC}"
