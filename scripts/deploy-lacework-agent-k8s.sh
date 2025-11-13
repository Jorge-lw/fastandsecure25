#!/bin/bash

# Script to deploy Lacework agent in Kubernetes cluster

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Lacework configuration
LACEWORK_ACCESS_TOKEN="${LACEWORK_ACCESS_TOKEN:-9b12ddd5c28fe9939c3a1f7948c073d989c6a8c37f100df0df5f3aaa}"
LACEWORK_SERVER_URL="${LACEWORK_SERVER_URL:-https://api.fra.lacework.net}"
KUBERNETES_CLUSTER="${KUBERNETES_CLUSTER:-lab-cluster}"
LACEWORK_NAMESPACE="${LACEWORK_NAMESPACE:-lacework}"
HELM_REPO_NAME="lacework"
HELM_REPO_URL="https://lacework.github.io/helm-charts"
HELM_RELEASE_NAME="lacework-agent"

echo -e "${BLUE}=== Deploying Lacework Agent to Kubernetes ===${NC}\n"

# Verify kubectl is available
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}✗ kubectl is not installed${NC}"
    exit 1
fi

# Verify helm is available
if ! command -v helm &> /dev/null; then
    echo -e "${YELLOW}Helm is not installed. Installing...${NC}"
    
    # Install Helm
    curl https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
    
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}✗ Error installing Helm${NC}"
        exit 1
    fi
    echo -e "${GREEN}✓ Helm installed${NC}"
fi

# Verify cluster access
echo -e "${YELLOW}[1] Verifying cluster access...${NC}"
if ! kubectl cluster-info > /dev/null 2>&1; then
    echo -e "${RED}✗ Cannot access cluster${NC}"
    echo -e "${YELLOW}   Configure kubectl first:${NC}"
    echo -e "   ${GREEN}aws eks update-kubeconfig --region <region> --name $KUBERNETES_CLUSTER${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Cluster access verified${NC}"

# Add Helm repository
echo -e "\n${YELLOW}[2] Adding Lacework Helm repository...${NC}"
if helm repo list | grep -q "$HELM_REPO_NAME"; then
    echo -e "${YELLOW}   Repository already exists, updating...${NC}"
    helm repo update "$HELM_REPO_NAME"
else
    helm repo add "$HELM_REPO_NAME" "$HELM_REPO_URL"
    helm repo update
fi
echo -e "${GREEN}✓ Repository added${NC}"

# Verify configuration values
echo -e "\n${YELLOW}[3] Configuration:${NC}"
echo -e "   Access Token: ${LACEWORK_ACCESS_TOKEN:0:20}..."
echo -e "   Server URL: $LACEWORK_SERVER_URL"
echo -e "   Cluster: $KUBERNETES_CLUSTER"
echo -e "   Namespace: $LACEWORK_NAMESPACE"

read -p "Continue with deployment? (y/n): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    exit 0
fi

# Deploy agent
echo -e "\n${YELLOW}[4] Deploying Lacework agent...${NC}"
helm upgrade --install \
    --namespace "$LACEWORK_NAMESPACE" \
    --create-namespace \
    --set laceworkConfig.accessToken="$LACEWORK_ACCESS_TOKEN" \
    --set laceworkConfig.serverUrl="$LACEWORK_SERVER_URL" \
    --set laceworkConfig.kubernetesCluster="$KUBERNETES_CLUSTER" \
    "$HELM_RELEASE_NAME" \
    "$HELM_REPO_NAME/lacework-agent"

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Agent deployed successfully${NC}"
else
    echo -e "${RED}✗ Error deploying agent${NC}"
    exit 1
fi

# Verify deployment
echo -e "\n${YELLOW}[5] Verifying deployment...${NC}"
sleep 5

# Verify namespace
if kubectl get namespace "$LACEWORK_NAMESPACE" > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Namespace created${NC}"
else
    echo -e "${RED}✗ Namespace not found${NC}"
fi

# Verify DaemonSet
echo -e "\n${YELLOW}DaemonSet status:${NC}"
kubectl get daemonset -n "$LACEWORK_NAMESPACE" 2>/dev/null || echo -e "${YELLOW}   Waiting for DaemonSet to be created...${NC}"

# Verify pods
echo -e "\n${YELLOW}Agent pods:${NC}"
kubectl get pods -n "$LACEWORK_NAMESPACE" -l app="$HELM_RELEASE_NAME" 2>/dev/null || echo -e "${YELLOW}   Waiting for pods to be created...${NC}"

# Wait a bit more and show status
sleep 10
echo -e "\n${YELLOW}Detailed status:${NC}"
kubectl get all -n "$LACEWORK_NAMESPACE" 2>/dev/null || true

echo -e "\n${BLUE}=== Deployment Completed ===${NC}"
echo -e "${YELLOW}To check status:${NC}"
echo -e "  ${GREEN}kubectl get pods -n $LACEWORK_NAMESPACE${NC}"
echo -e "  ${GREEN}kubectl get daemonset -n $LACEWORK_NAMESPACE${NC}"
echo -e ""
echo -e "${YELLOW}To view logs:${NC}"
echo -e "  ${GREEN}kubectl logs -n $LACEWORK_NAMESPACE -l app=$HELM_RELEASE_NAME${NC}"
echo -e ""
echo -e "${YELLOW}To uninstall:${NC}"
echo -e "  ${GREEN}helm uninstall $HELM_RELEASE_NAME -n $LACEWORK_NAMESPACE${NC}"
