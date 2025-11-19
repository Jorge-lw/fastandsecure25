#!/bin/bash

# Script to add bastion role to EKS cluster aws-auth ConfigMap

set -euo pipefail

# Use AWS profile if available
AWS_PROFILE="${AWS_PROFILE:-}"
AWS_PROFILE_FLAG=""
if [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE_FLAG="--profile $AWS_PROFILE"
    export AWS_PROFILE
fi

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Adding Bastion to EKS Cluster ===${NC}\n"

# Get Terraform information
cd terraform 2>/dev/null || { echo "Error: Run this script from the project root directory"; exit 1; }

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}terraform.tfstate not found${NC}"
    exit 1
fi

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
CLUSTER_NAME=$(terraform output -raw eks_cluster_name 2>/dev/null || echo "lab-cluster")
BASTION_ROLE_ARN=$(terraform output -raw bastion_role_arn 2>/dev/null || echo "")

if [ -z "$BASTION_ROLE_ARN" ]; then
    # Try to get role ARN from Terraform state
    BASTION_ROLE_ARN=$(terraform state show aws_iam_role.bastion 2>/dev/null | grep "arn:" | head -1 | awk '{print $3}' || echo "")
fi

if [ -z "$BASTION_ROLE_ARN" ]; then
    echo -e "${RED}Could not get bastion role ARN${NC}"
    echo -e "${YELLOW}Getting from AWS directly...${NC}"
    BASTION_ROLE_ARN=$(aws iam get-role --role-name bastion-role $AWS_PROFILE_FLAG --query 'Role.Arn' --output text 2>/dev/null || echo "")
fi

if [ -z "$BASTION_ROLE_ARN" ]; then
    echo -e "${RED}Could not get bastion role ARN${NC}"
    exit 1
fi

echo -e "${GREEN}Region: $AWS_REGION${NC}"
echo -e "${GREEN}Cluster: $CLUSTER_NAME${NC}"
echo -e "${GREEN}Bastion Role ARN: $BASTION_ROLE_ARN${NC}"
echo ""

# Configure kubectl
echo -e "${YELLOW}[1] Configuring kubectl...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME" $AWS_PROFILE_FLAG 2>/dev/null && \
    echo -e "${GREEN}✓ kubectl configured${NC}" || \
    { echo -e "${RED}✗ Error configuring kubectl${NC}"; exit 1; }

# Fix API version in kubeconfig (replace v1alpha1 with v1beta1)
if [ -f ~/.kube/config ]; then
    sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' ~/.kube/config 2>/dev/null || true
    echo -e "${GREEN}✓ Fixed API version in kubeconfig${NC}"
fi

# Verify cluster is accessible
echo -e "\n${YELLOW}[2] Verifying cluster access...${NC}"
kubectl cluster-info > /dev/null 2>&1 && \
    echo -e "${GREEN}✓ Cluster accessible${NC}" || \
    { echo -e "${RED}✗ Cannot access cluster${NC}"; exit 1; }

# Get current aws-auth ConfigMap
echo -e "\n${YELLOW}[3] Getting current aws-auth ConfigMap...${NC}"
kubectl get configmap aws-auth -n kube-system -o yaml > /tmp/aws-auth.yaml 2>/dev/null && \
    echo -e "${GREEN}✓ ConfigMap obtained${NC}" || \
    { echo -e "${RED}✗ Could not get ConfigMap${NC}"; exit 1; }

# Verify if role is already in ConfigMap
if grep -q "$BASTION_ROLE_ARN" /tmp/aws-auth.yaml; then
    echo -e "${YELLOW}⚠ Bastion role is already in ConfigMap${NC}"
    exit 0
fi

# Add bastion role to ConfigMap
echo -e "\n${YELLOW}[4] Adding bastion role to ConfigMap...${NC}"

# Get current mapRoles content
CURRENT_MAPROLES=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapRoles}' 2>/dev/null || echo "")

if [ -z "$CURRENT_MAPROLES" ]; then
    # If mapRoles doesn't exist, create a new one
    NEW_MAPROLES="- rolearn: $BASTION_ROLE_ARN
  username: bastion-user
  groups:
    - system:masters"
else
    # Add new role to existing mapRoles
    NEW_MAPROLES="$CURRENT_MAPROLES
- rolearn: $BASTION_ROLE_ARN
  username: bastion-user
  groups:
    - system:masters"
fi

# Get mapUsers if exists
CURRENT_MAPUSERS=$(kubectl get configmap aws-auth -n kube-system -o jsonpath='{.data.mapUsers}' 2>/dev/null || echo "")

# Create patch
cat > /tmp/aws-auth-patch.yaml <<EOF
data:
  mapRoles: |
$(echo "$NEW_MAPROLES" | sed 's/^/    /')
EOF

if [ -n "$CURRENT_MAPUSERS" ]; then
    echo "  mapUsers: |" >> /tmp/aws-auth-patch.yaml
    echo "$CURRENT_MAPUSERS" | sed 's/^/    /' >> /tmp/aws-auth-patch.yaml
fi

# Apply patch
kubectl patch configmap aws-auth -n kube-system --patch "$(cat /tmp/aws-auth-patch.yaml)" && \
    echo -e "${GREEN}✓ Bastion role added to ConfigMap${NC}" || \
    { echo -e "${RED}✗ Error adding role. Trying with kubectl apply...${NC}"; \
      kubectl get configmap aws-auth -n kube-system -o yaml | \
        sed "/mapRoles: |/a\\
    - rolearn: $BASTION_ROLE_ARN\\
      username: bastion-user\\
      groups:\\
        - system:masters" | \
        kubectl apply -f - && \
        echo -e "${GREEN}✓ Role added using apply${NC}" || \
        { echo -e "${RED}✗ Error. Please manually add role to ConfigMap${NC}"; exit 1; } }

# Clean temporary files
rm -f /tmp/aws-auth.yaml /tmp/aws-auth-patch.yaml

echo -e "\n${GREEN}=== Bastion added to EKS cluster ===${NC}"
echo -e "${YELLOW}You can now use kubectl from the bastion${NC}"
