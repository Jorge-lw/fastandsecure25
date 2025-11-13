#!/bin/bash

# Complete script to build, push and deploy all images

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT"

echo -e "${GREEN}=== Complete Deployment of Vulnerable Infrastructure ===${NC}\n"

# Step 1: Get Terraform outputs
echo -e "${YELLOW}Step 1: Getting Terraform information...${NC}"
cd terraform

if [ ! -f "terraform.tfstate" ]; then
    echo "Error: Terraform has not been applied. Run 'terraform apply' first."
    exit 1
fi

AWS_REGION=$(terraform output -raw aws_region)
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id)
CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
BASTION_IP=$(terraform output -raw bastion_public_ip)

export AWS_REGION
export AWS_ACCOUNT_ID
export CLUSTER_NAME

echo -e "${GREEN}✓ Region: $AWS_REGION${NC}"
echo -e "${GREEN}✓ Account ID: $AWS_ACCOUNT_ID${NC}"
echo -e "${GREEN}✓ Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}✓ Bastion IP: $BASTION_IP${NC}"

cd "$PROJECT_ROOT"

# Step 2: Build and push images
echo -e "\n${YELLOW}Step 2: Building and pushing images to ECR...${NC}"
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh

# Step 3: Deploy to cluster
echo -e "\n${YELLOW}Step 3: Deploying applications to cluster...${NC}"
chmod +x scripts/deploy-to-cluster.sh
./scripts/deploy-to-cluster.sh

# Step 4: Deploy Lacework agent in Kubernetes
echo -e "\n${YELLOW}Step 4: Deploying Lacework agent in Kubernetes...${NC}"
chmod +x scripts/deploy-lacework-agent-k8s.sh
./scripts/deploy-lacework-agent-k8s.sh || echo -e "${YELLOW}⚠ Error deploying Lacework (may require manual configuration)${NC}"

echo -e "\n${GREEN}=== Deployment Completed ===${NC}"
echo -e "${YELLOW}To connect to the bastion:${NC}"
echo -e "ssh -p 22222 -i <your-key> ubuntu@$BASTION_IP"
echo -e "\n${YELLOW}From the bastion, you can:${NC}"
echo -e "1. Configure kubectl: aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME"
echo -e "2. View pods: kubectl get pods -n vulnerable-apps"
echo -e "3. Port-forward: kubectl port-forward -n vulnerable-apps svc/vulnerable-web-app 3000:3000"
