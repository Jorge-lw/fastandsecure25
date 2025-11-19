#!/bin/bash

# Complete script to build, push and deploy all images

set -euo pipefail

# Use AWS profile if available
if [ -n "${AWS_PROFILE:-}" ]; then
    export AWS_PROFILE
fi

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

# Step 4: Add bastion to EKS aws-auth
echo -e "\n${YELLOW}Step 4: Adding bastion to EKS cluster...${NC}"
chmod +x scripts/add-bastion-to-eks.sh
./scripts/add-bastion-to-eks.sh || echo -e "${YELLOW}⚠ Could not add bastion to EKS (may already be added)${NC}"

# Step 5: Configure kubectl on bastion
echo -e "\n${YELLOW}Step 5: Configuring kubectl on bastion...${NC}"
chmod +x scripts/configure-bastion-kubectl.sh
./scripts/configure-bastion-kubectl.sh || echo -e "${YELLOW}⚠ Could not configure kubectl on bastion (may need manual setup)${NC}"

# Step 6: Upload scripts and install vulnerable packages on bastion
echo -e "\n${YELLOW}Step 6: Uploading scripts to bastion...${NC}"
ssh -p 22222 ubuntu@$BASTION_IP "mkdir -p ~/scripts ~/voting-app ~/exploitation" 2>/dev/null || true
scp -P 22222 docker-images/voting-app/* ubuntu@$BASTION_IP:~/voting-app/ 2>/dev/null || echo -e "${YELLOW}⚠ Could not upload voting app files${NC}"
scp -P 22222 scripts/deploy-voting-app-bastion.sh scripts/setup-port-forwards.sh scripts/generate-legitimate-traffic.sh scripts/setup-complete-environment.sh scripts/install-vulnerable-packages.sh ubuntu@$BASTION_IP:~/scripts/ 2>/dev/null || true
scp -P 22222 exploitation/*.sh ubuntu@$BASTION_IP:~/exploitation/ 2>/dev/null || true

# Step 7: Install vulnerable packages on bastion
echo -e "\n${YELLOW}Step 7: Installing vulnerable packages on bastion...${NC}"
ssh -p 22222 ubuntu@$BASTION_IP "chmod +x ~/scripts/install-vulnerable-packages.sh 2>/dev/null; sudo ~/scripts/install-vulnerable-packages.sh 2>&1 | tail -30" || echo -e "${YELLOW}⚠ Could not install vulnerable packages (may need manual execution)${NC}"

# Step 8: Setup complete environment on bastion
echo -e "\n${YELLOW}Step 8: Setting up complete environment on bastion...${NC}"
ssh -p 22222 ubuntu@$BASTION_IP "chmod +x ~/scripts/*.sh ~/exploitation/*.sh 2>/dev/null; cd ~ && chmod +x deploy-voting-app-bastion.sh 2>/dev/null; ~/scripts/setup-complete-environment.sh 2>&1" || echo -e "${YELLOW}⚠ Could not setup complete environment (may need manual execution)${NC}"

echo -e "\n${GREEN}=== Deployment Completed ===${NC}"
echo -e "${YELLOW}To connect to the bastion:${NC}"
echo -e "ssh -p 22222 ubuntu@$BASTION_IP"
echo -e "\n${YELLOW}From the bastion, you can now:${NC}"
echo -e "1. View pods: kubectl get pods -n vulnerable-apps"
echo -e "2. View services: kubectl get services -n vulnerable-apps"
echo -e "3. Access voting app: http://localhost:8080"
echo -e "4. Check legitimate traffic: tail -f /tmp/legitimate-traffic.log"
echo -e "5. Check port-forwards: ps aux | grep port-forward"
echo -e "\n${YELLOW}Applications deployed:${NC}"
echo -e "  - vulnerable-web-app (port 3000, LoadBalancer)"
echo -e "  - vulnerable-api (port 5000, LoadBalancer)"
echo -e "  - vulnerable-database (port 3306, LoadBalancer)"
echo -e "  - vulnerable-legacy-app (port 8080, LoadBalancer)"
echo -e "  - blog-app (port 8081, LoadBalancer)"
echo -e "  - ecommerce-app (port 8082, LoadBalancer)"
echo -e "  - voting-app (port 8080, LoadBalancer)"
echo -e "\n${YELLOW}All applications are accessible from internet via LoadBalancer${NC}"
echo -e "${YELLOW}Get URLs with: kubectl get svc -n vulnerable-apps${NC}"
