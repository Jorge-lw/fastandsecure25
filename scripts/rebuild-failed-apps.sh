#!/bin/bash

# Script to rebuild and redeploy failed applications

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${GREEN}=== Rebuilding Failed Applications ===${NC}\n"

# Get Terraform outputs
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}Error: Terraform has not been applied${NC}"
    exit 1
fi

# Use AWS profile if available
AWS_PROFILE="${AWS_PROFILE:-your-aws-profile}"
if [ -n "$AWS_PROFILE" ] && [ "$AWS_PROFILE" != "your-aws-profile" ]; then
    export AWS_PROFILE
fi

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "eu-central-1")
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null || echo "")
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "lab-cluster")

export AWS_REGION
export AWS_ACCOUNT_ID
export CLUSTER_NAME
if [ -z "${AWS_PROFILE:-}" ] || [ "$AWS_PROFILE" = "your-aws-profile" ]; then
    echo -e "${YELLOW}AWS_PROFILE not set. Using default credentials.${NC}"
    echo -e "${YELLOW}Set AWS_PROFILE environment variable to use a specific profile.${NC}"
else
    export AWS_PROFILE
    echo -e "${GREEN}Using AWS Profile: $AWS_PROFILE${NC}"
fi
echo -e "${GREEN}Region: $AWS_REGION${NC}"
echo -e "${GREEN}Account ID: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}Cluster: $CLUSTER_NAME${NC}\n"

cd "$PROJECT_ROOT"

# Login to ECR
echo -e "${YELLOW}Logging in to ECR...${NC}"
AWS_PROFILE_FLAG=""
if [ -n "${AWS_PROFILE:-}" ] && [ "$AWS_PROFILE" != "your-aws-profile" ]; then
    AWS_PROFILE_FLAG="--profile $AWS_PROFILE"
fi
aws ecr get-login-password --region $AWS_REGION $AWS_PROFILE_FLAG | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Rebuild vulnerable-api
echo -e "\n${YELLOW}Rebuilding vulnerable-api...${NC}"
cd docker-images/vulnerable-api
docker build --platform linux/amd64 -t vulnerable-api:latest .
docker tag vulnerable-api:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-api:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-api:latest
echo -e "${GREEN}✓ vulnerable-api rebuilt and pushed${NC}"

# Rebuild vulnerable-legacy-app
cd "$PROJECT_ROOT"
echo -e "\n${YELLOW}Rebuilding vulnerable-legacy-app...${NC}"
cd docker-images/vulnerable-legacy-app
docker build --platform linux/amd64 -t vulnerable-legacy-app:latest .
docker tag vulnerable-legacy-app:latest $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-legacy-app:latest
docker push $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/vulnerable-legacy-app:latest
echo -e "${GREEN}✓ vulnerable-legacy-app rebuilt and pushed${NC}"

# Update deployments in Kubernetes
cd "$PROJECT_ROOT"
echo -e "\n${YELLOW}Updating deployments in Kubernetes...${NC}"
kubectl rollout restart deployment/vulnerable-api -n vulnerable-apps
kubectl rollout restart deployment/vulnerable-legacy-app -n vulnerable-apps

echo -e "\n${YELLOW}Waiting for pods to be ready...${NC}"
kubectl wait --for=condition=ready pod -l app=vulnerable-api -n vulnerable-apps --timeout=300s || echo -e "${YELLOW}⚠ vulnerable-api may still be starting${NC}"
kubectl wait --for=condition=ready pod -l app=vulnerable-legacy-app -n vulnerable-apps --timeout=300s || echo -e "${YELLOW}⚠ vulnerable-legacy-app may still be starting${NC}"

echo -e "\n${GREEN}=== Rebuild Complete ===${NC}"
echo -e "${YELLOW}Checking pod status...${NC}"
kubectl get pods -n vulnerable-apps

