#!/bin/bash

# Script to rebuild failed apps - run this from the bastion
# This script assumes you're already on the bastion with AWS credentials configured

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== Rebuilding Failed Applications from Bastion ===${NC}\n"

# Get AWS info
AWS_REGION=${AWS_REGION:-$(aws configure get region || echo "eu-central-1")}
AWS_ACCOUNT_ID=${AWS_ACCOUNT_ID:-$(aws sts get-caller-identity --query Account --output text)}
CLUSTER_NAME=${CLUSTER_NAME:-"lab-cluster"}

export AWS_REGION
export AWS_ACCOUNT_ID
export CLUSTER_NAME

echo -e "${GREEN}Region: $AWS_REGION${NC}"
echo -e "${GREEN}Account ID: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}Cluster: $CLUSTER_NAME${NC}\n"

# Clone or update the repo if needed
if [ ! -d "fastandsecure25" ]; then
    echo -e "${YELLOW}Cloning repository...${NC}"
    git clone https://github.com/Jorge-lw/fastandsecure25.git || {
        echo -e "${RED}Error: Could not clone repository${NC}"
        echo -e "${YELLOW}Please ensure the repository is accessible or copy the files manually${NC}"
        exit 1
    }
fi

cd fastandsecure25

# Login to ECR
echo -e "${YELLOW}Logging in to ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Rebuild vulnerable-api
echo -e "\n${YELLOW}Rebuilding vulnerable-api...${NC}"
cd docker-images/vulnerable-api
docker build --platform linux/amd64 -t vulnerable-api:latest .
docker tag vulnerable-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-api:latest
echo -e "${GREEN}✓ vulnerable-api rebuilt and pushed${NC}"

# Rebuild vulnerable-legacy-app
cd ../vulnerable-legacy-app
echo -e "\n${YELLOW}Rebuilding vulnerable-legacy-app...${NC}"
docker build --platform linux/amd64 -t vulnerable-legacy-app:latest .
docker tag vulnerable-legacy-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-legacy-app:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-legacy-app:latest
echo -e "${GREEN}✓ vulnerable-legacy-app rebuilt and pushed${NC}"

# Configure kubectl if needed
cd ../..
echo -e "\n${YELLOW}Configuring kubectl...${NC}"
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Update deployments
echo -e "\n${YELLOW}Updating deployments...${NC}"
kubectl rollout restart deployment/vulnerable-api -n vulnerable-apps
kubectl rollout restart deployment/vulnerable-legacy-app -n vulnerable-apps

echo -e "\n${YELLOW}Waiting for pods to be ready...${NC}"
sleep 10
kubectl wait --for=condition=ready pod -l app=vulnerable-api -n vulnerable-apps --timeout=300s || echo -e "${YELLOW}⚠ vulnerable-api may still be starting${NC}"
kubectl wait --for=condition=ready pod -l app=vulnerable-legacy-app -n vulnerable-apps --timeout=300s || echo -e "${YELLOW}⚠ vulnerable-legacy-app may still be starting${NC}"

echo -e "\n${GREEN}=== Rebuild Complete ===${NC}"
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vulnerable-apps

