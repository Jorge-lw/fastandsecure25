#!/bin/bash

# Script to fix kubectl configuration with correct API version

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Fixing kubectl configuration...${NC}"

# Get region and cluster name
if [ -z "$AWS_REGION" ]; then
    export AWS_REGION=$(aws configure get region || echo "us-east-1")
fi

if [ -z "$CLUSTER_NAME" ]; then
    export CLUSTER_NAME="lab-cluster"
fi

# Update kubeconfig with correct API version
echo -e "${YELLOW}Updating kubeconfig...${NC}"
aws eks update-kubeconfig --region "$AWS_REGION" --name "$CLUSTER_NAME"

# Verify and fix configuration if necessary
KUBECONFIG_FILE="$HOME/.kube/config"

if [ -f "$KUBECONFIG_FILE" ]; then
    # Replace v1alpha1 with v1beta1 if exists
    if grep -q "client.authentication.k8s.io/v1alpha1" "$KUBECONFIG_FILE"; then
        echo -e "${YELLOW}Replacing v1alpha1 with v1beta1...${NC}"
        sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' "$KUBECONFIG_FILE"
        echo -e "${GREEN}✓ Configuration updated${NC}"
    fi
    
    # Also verify if v1beta1 exists and ensure it is correct
    if ! grep -q "client.authentication.k8s.io/v1beta1" "$KUBECONFIG_FILE"; then
        echo -e "${YELLOW}v1beta1 not found, updating configuration...${NC}"
        # Search and replace any old version
        sed -i.bak 's/apiVersion:.*client\.authentication/apiVersion: client.authentication.k8s.io\/v1beta1/g' "$KUBECONFIG_FILE"
    fi
fi

# Verify it works
echo -e "${YELLOW}Verifying cluster access...${NC}"
kubectl cluster-info && \
    echo -e "${GREEN}✓ kubectl configured correctly${NC}" || \
    echo -e "${RED}✗ Error verifying access${NC}"

