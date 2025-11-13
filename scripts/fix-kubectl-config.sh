#!/bin/bash

# Script para arreglar la configuración de kubectl con la versión correcta de la API

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Arreglando configuración de kubectl...${NC}"

# Obtener región y cluster name
if [ -z "$AWS_REGION" ]; then
    export AWS_REGION=$(aws configure get region || echo "us-east-1")
fi

if [ -z "$CLUSTER_NAME" ]; then
    export CLUSTER_NAME="lab-cluster"
fi

# Actualizar kubeconfig con la versión correcta de la API
echo -e "${YELLOW}Actualizando kubeconfig...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Verificar y arreglar la configuración si es necesario
KUBECONFIG_FILE="$HOME/.kube/config"

if [ -f "$KUBECONFIG_FILE" ]; then
    # Reemplazar v1alpha1 con v1beta1 si existe
    if grep -q "client.authentication.k8s.io/v1alpha1" "$KUBECONFIG_FILE"; then
        echo -e "${YELLOW}Reemplazando v1alpha1 con v1beta1...${NC}"
        sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' "$KUBECONFIG_FILE"
        echo -e "${GREEN}✓ Configuración actualizada${NC}"
    fi
    
    # También verificar si hay v1beta1 y asegurarse de que está correcto
    if ! grep -q "client.authentication.k8s.io/v1beta1" "$KUBECONFIG_FILE"; then
        echo -e "${YELLOW}No se encontró v1beta1, actualizando configuración...${NC}"
        # Buscar y reemplazar cualquier versión antigua
        sed -i.bak 's/apiVersion:.*client\.authentication/apiVersion: client.authentication.k8s.io\/v1beta1/g' "$KUBECONFIG_FILE"
    fi
fi

# Verificar que funciona
echo -e "${YELLOW}Verificando acceso al cluster...${NC}"
kubectl cluster-info && \
    echo -e "${GREEN}✓ kubectl configurado correctamente${NC}" || \
    echo -e "${RED}✗ Error verificando acceso${NC}"

