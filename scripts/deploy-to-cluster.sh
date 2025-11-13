#!/bin/bash

# Script para desplegar imágenes vulnerables en el cluster EKS

set -e

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Variables
if [ -z "$AWS_REGION" ]; then
    AWS_REGION="us-east-1"
fi

if [ -z "$CLUSTER_NAME" ]; then
    CLUSTER_NAME="lab-cluster"
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

echo -e "${GREEN}Configurando kubectl para cluster: $CLUSTER_NAME${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

echo -e "${GREEN}Verificando conexión al cluster...${NC}"
kubectl cluster-info

# Crear namespace para aplicaciones vulnerables
echo -e "${GREEN}Creando namespace para aplicaciones vulnerables...${NC}"
kubectl create namespace vulnerable-apps --dry-run=client -o yaml | kubectl apply -f -

# Lista de aplicaciones a desplegar
declare -A APPS=(
    ["vulnerable-web-app"]="3000"
    ["vulnerable-api"]="5000"
    ["vulnerable-database"]="3306"
    ["vulnerable-legacy-app"]="8080"
)

for APP_NAME in "${!APPS[@]}"; do
    PORT="${APPS[$APP_NAME]}"
    ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME:latest"
    
    echo -e "\n${YELLOW}Desplegando: $APP_NAME${NC}"
    
    # Crear deployment
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: $APP_NAME
  namespace: vulnerable-apps
  labels:
    app: $APP_NAME
spec:
  replicas: 1
  selector:
    matchLabels:
      app: $APP_NAME
  template:
    metadata:
      labels:
        app: $APP_NAME
    spec:
      containers:
      - name: $APP_NAME
        image: $ECR_IMAGE
        ports:
        - containerPort: $PORT
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "512Mi"
            cpu: "500m"
        # Vulnerabilidad: Sin security context restrictivo
        securityContext:
          runAsUser: 0
          privileged: true
        # Vulnerabilidad: Sin límites de recursos estrictos
---
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  namespace: vulnerable-apps
  labels:
    app: $APP_NAME
spec:
  type: ClusterIP
  ports:
  - port: $PORT
    targetPort: $PORT
    protocol: TCP
  selector:
    app: $APP_NAME
EOF

    echo -e "${GREEN}✓ $APP_NAME desplegado${NC}"
done

echo -e "\n${GREEN}Esperando que los pods estén listos...${NC}"
kubectl wait --for=condition=ready pod -l app -n vulnerable-apps --timeout=300s || true

echo -e "\n${GREEN}Estado de los deployments:${NC}"
kubectl get deployments -n vulnerable-apps

echo -e "\n${GREEN}Estado de los pods:${NC}"
kubectl get pods -n vulnerable-apps

echo -e "\n${GREEN}Estado de los services:${NC}"
kubectl get services -n vulnerable-apps

echo -e "\n${YELLOW}Para acceder a las aplicaciones desde el bastión:${NC}"
echo -e "${GREEN}kubectl port-forward -n vulnerable-apps svc/vulnerable-web-app 3000:3000${NC}"
echo -e "${GREEN}kubectl port-forward -n vulnerable-apps svc/vulnerable-api 5000:5000${NC}"

