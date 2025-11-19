#!/bin/bash

# Script to update Kubernetes services from ClusterIP to LoadBalancer
# This exposes services directly to the internet

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

NAMESPACE="${1:-vulnerable-apps}"

echo -e "${GREEN}=== Updating services to LoadBalancer ===${NC}\n"

# List of services to update
SERVICES=(
    "vulnerable-web-app"
    "vulnerable-api"
    "vulnerable-legacy-app"
    "blog-app"
    "ecommerce-app"
)

for SERVICE in "${SERVICES[@]}"; do
    echo -e "${YELLOW}Updating $SERVICE...${NC}"
    if kubectl patch svc "$SERVICE" -n "$NAMESPACE" -p '{"spec":{"type":"LoadBalancer"}}' 2>/dev/null; then
        echo -e "${GREEN}  ✓ $SERVICE updated${NC}"
    else
        echo -e "${YELLOW}  ⚠ $SERVICE may already be LoadBalancer or doesn't exist${NC}"
    fi
done

echo -e "\n${GREEN}=== Waiting for LoadBalancer assignment (this may take 2-5 minutes) ===${NC}"
echo -e "${YELLOW}Checking status...${NC}\n"

sleep 5

kubectl get svc -n "$NAMESPACE" -o custom-columns=NAME:.metadata.name,TYPE:.spec.type,EXTERNAL-IP:.status.loadBalancer.ingress[0].hostname

echo -e "\n${YELLOW}Note: LoadBalancer IPs may take a few minutes to be assigned${NC}"
echo -e "${YELLOW}Run 'kubectl get svc -n $NAMESPACE' to check status${NC}"

