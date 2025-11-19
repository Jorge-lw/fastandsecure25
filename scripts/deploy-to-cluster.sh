#!/bin/bash

# Script to deploy vulnerable images to the EKS cluster

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Use AWS profile if available
AWS_PROFILE="${AWS_PROFILE:-}"
AWS_PROFILE_FLAG=""
if [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE_FLAG="--profile $AWS_PROFILE"
    export AWS_PROFILE
fi

# Variables
if [ -z "${AWS_REGION:-}" ]; then
    if [ -f "terraform/terraform.tfstate" ]; then
        AWS_REGION=$(cd terraform && terraform output -raw aws_region 2>/dev/null || echo "eu-central-1")
    else
        AWS_REGION="eu-central-1"
    fi
fi

if [ -z "${CLUSTER_NAME:-}" ]; then
    if [ -f "terraform/terraform.tfstate" ]; then
        CLUSTER_NAME=$(cd terraform && terraform output -raw eks_cluster_name 2>/dev/null || echo "lab-cluster")
    else
        CLUSTER_NAME="lab-cluster"
    fi
fi

if [ -z "${AWS_ACCOUNT_ID:-}" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity $AWS_PROFILE_FLAG --query Account --output text)
fi

export AWS_REGION
export CLUSTER_NAME
export AWS_ACCOUNT_ID

echo -e "${GREEN}Configuring kubectl for cluster: $CLUSTER_NAME${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME $AWS_PROFILE_FLAG

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
    "blog-app:8080"
    "ecommerce-app:8080"
    "voting-app:8080"
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
EOF

    # Create service (handle multiple apps on same port)
    if [ "$APP_NAME" = "blog-app" ] || [ "$APP_NAME" = "ecommerce-app" ]; then
        # Use different service port for apps sharing container port 8080
        if [ "$APP_NAME" = "blog-app" ]; then
            SERVICE_PORT=8081
        else
            SERVICE_PORT=8082
        fi
    else
        SERVICE_PORT=$PORT
    fi
    
    # VULNERABILITY: Expose services directly to internet using LoadBalancer
    # This allows direct access from attacker's machine without needing port-forward
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Service
metadata:
  name: $APP_NAME
  namespace: vulnerable-apps
  labels:
    app: $APP_NAME
spec:
  type: LoadBalancer
  ports:
  - port: $SERVICE_PORT
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

echo -e "\n${YELLOW}Services exposed via LoadBalancer (accessible from internet):${NC}"
echo -e "${GREEN}Get LoadBalancer URLs with: kubectl get svc -n vulnerable-apps${NC}"
echo -e "${YELLOW}Note: Services are now directly accessible from your local machine${NC}"
echo -e "${YELLOW}Wait a few minutes for LoadBalancer IPs to be assigned${NC}"
