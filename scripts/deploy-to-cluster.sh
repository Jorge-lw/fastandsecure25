#!/bin/bash

# Script to deploy vulnerable images to the EKS cluster

set -e

# Colors for output
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

echo -e "${GREEN}Configuring kubectl for cluster: $CLUSTER_NAME${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

echo -e "${GREEN}Verifying cluster connection...${NC}"
kubectl cluster-info

# Create namespace for vulnerable applications
echo -e "${GREEN}Creating namespace for vulnerable applications...${NC}"
kubectl create namespace vulnerable-apps --dry-run=client -o yaml | kubectl apply -f -

# List of applications to deploy (app_name:port)
APPS=(
    "vulnerable-web-app:3000"
    "vulnerable-api:5000"
    "vulnerable-database:3306"
    "vulnerable-legacy-app:8080"
)

for APP_INFO in "${APPS[@]}"; do
    APP_NAME="${APP_INFO%%:*}"
    PORT="${APP_INFO##*:}"
    ECR_IMAGE="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$APP_NAME:latest"
    
    echo -e "\n${YELLOW}Deploying: $APP_NAME${NC}"
    
    # Create deployment
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
        # Vulnerability: No restrictive security context
        securityContext:
          runAsUser: 0
          privileged: true
        # Vulnerability: No strict resource limits
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

    echo -e "${GREEN}✓ $APP_NAME deployed${NC}"
done

echo -e "\n${GREEN}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app -n vulnerable-apps --timeout=300s || true

echo -e "\n${GREEN}Deployment status:${NC}"
kubectl get deployments -n vulnerable-apps

echo -e "\n${GREEN}Pod status:${NC}"
kubectl get pods -n vulnerable-apps

echo -e "\n${GREEN}Service status:${NC}"
kubectl get services -n vulnerable-apps

echo -e "\n${YELLOW}To access applications from the bastion:${NC}"
echo -e "${GREEN}kubectl port-forward -n vulnerable-apps svc/vulnerable-web-app 3000:3000${NC}"
echo -e "${GREEN}kubectl port-forward -n vulnerable-apps svc/vulnerable-api 5000:5000${NC}"
