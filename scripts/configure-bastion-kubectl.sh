#!/bin/bash

# Script to configure kubectl on the bastion host
# This should be run after the EKS cluster is created and the bastion is added to aws-auth

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Configuring kubectl on Bastion ===${NC}\n"

# Get Terraform information
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

cd "$PROJECT_ROOT/terraform" 2>/dev/null || { 
    echo -e "${RED}Error: Run this script from the project root directory${NC}"
    exit 1
}

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}terraform.tfstate not found${NC}"
    exit 1
fi

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "lab-cluster")
BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ]; then
    echo -e "${RED}Could not get bastion IP${NC}"
    exit 1
fi

echo -e "${GREEN}Region: $AWS_REGION${NC}"
echo -e "${GREEN}Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Bastion IP: $BASTION_IP${NC}\n"

# Check if we can connect to bastion
echo -e "${YELLOW}[1] Testing SSH connection to bastion...${NC}"
if ! ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 -p 22222 ubuntu@$BASTION_IP "echo 'Connected'" > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot connect to bastion${NC}"
    echo -e "${YELLOW}Make sure you can SSH to the bastion:${NC}"
    echo -e "ssh -p 22222 ubuntu@$BASTION_IP"
    exit 1
fi
echo -e "${GREEN}✓ SSH connection successful${NC}"

# Configure kubectl on bastion
echo -e "\n${YELLOW}[2] Configuring kubectl on bastion...${NC}"
ssh -p 22222 ubuntu@$BASTION_IP <<EOF
    set -e
    
    # Update kubeconfig
    aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME || {
        echo "Error: Could not update kubeconfig"
        exit 1
    }
    
    # Fix API version in kubeconfig (replace v1alpha1 with v1beta1)
    if [ -f ~/.kube/config ]; then
        sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' ~/.kube/config
        echo "✓ Fixed API version in kubeconfig"
    fi
    
    # Verify kubectl works
    echo "Testing kubectl..."
    kubectl cluster-info > /dev/null 2>&1 && echo "✓ kubectl configured correctly" || {
        echo "✗ kubectl configuration failed"
        exit 1
    }
    
    # Test access to pods
    kubectl get pods -n vulnerable-apps > /dev/null 2>&1 && echo "✓ Can access cluster resources" || {
        echo "⚠ Cannot access cluster resources (may need to add bastion to aws-auth)"
    }
EOF

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}=== kubectl configured successfully on bastion ===${NC}"
    echo -e "${YELLOW}You can now use kubectl from the bastion:${NC}"
    echo -e "ssh -p 22222 ubuntu@$BASTION_IP"
    echo -e "kubectl get pods -n vulnerable-apps"
else
    echo -e "\n${RED}=== Error configuring kubectl ===${NC}"
    echo -e "${YELLOW}Make sure:${NC}"
    echo -e "1. The bastion role is added to EKS aws-auth ConfigMap"
    echo -e "2. Run: ./scripts/add-bastion-to-eks.sh"
    exit 1
fi

