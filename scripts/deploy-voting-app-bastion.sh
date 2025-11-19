#!/bin/bash

# Script to deploy voting application on bastion host
# Connects to database in Kubernetes cluster

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Deploying Voting Application on Bastion ===${NC}\n"

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed${NC}"
    exit 1
fi

# Get cluster information
if [ -z "$AWS_REGION" ]; then
    AWS_REGION=$(aws configure get region || echo "eu-central-1")
fi

if [ -z "$CLUSTER_NAME" ]; then
    CLUSTER_NAME="lab-cluster"
fi

echo -e "${YELLOW}Region: $AWS_REGION${NC}"
echo -e "${YELLOW}Cluster: $CLUSTER_NAME${NC}"

# Get database service endpoint
echo -e "\n${YELLOW}[1] Configuring database connection...${NC}"

# Check if port-forward is already running
if ps aux | grep -q '[k]ubectl port-forward.*vulnerable-database.*3306'; then
    echo -e "${GREEN}✓ Port-forward already running${NC}"
    DB_HOST="localhost"
else
    echo -e "${YELLOW}Starting port-forward for database...${NC}"
    # Start port-forward in background
    kubectl port-forward -n vulnerable-apps svc/vulnerable-database 3306:3306 > /tmp/db-forward.log 2>&1 &
    PF_PID=$!
    sleep 3
    
    # Verify port-forward is running
    if ps -p $PF_PID > /dev/null 2>&1; then
        echo -e "${GREEN}✓ Port-forward started (PID: $PF_PID)${NC}"
        DB_HOST="localhost"
    else
        echo -e "${YELLOW}⚠ Port-forward failed, trying direct connection${NC}"
        DB_HOST=$(kubectl get svc vulnerable-database -n vulnerable-apps -o jsonpath='{.metadata.name}.{.metadata.namespace}.svc.cluster.local' 2>/dev/null || echo "vulnerable-database.vulnerable-apps.svc.cluster.local")
    fi
fi

echo -e "${GREEN}✓ Database host: $DB_HOST${NC}"

# Build Docker image
echo -e "\n${YELLOW}[2] Building voting application Docker image...${NC}"
cd ~
if [ ! -d "voting-app" ]; then
    echo -e "${RED}Error: voting-app directory not found in home directory${NC}"
    exit 1
fi

# Verify required files exist
if [ ! -f "voting-app/Dockerfile" ]; then
    echo -e "${RED}Error: Dockerfile not found${NC}"
    exit 1
fi

if [ ! -f "voting-app/requirements.txt" ]; then
    echo -e "${RED}Error: requirements.txt not found${NC}"
    exit 1
fi

# Note: app.py should be uploaded from local machine before running this script
# Or copy it manually to voting-app/ directory
if [ ! -f "voting-app/app.py" ]; then
    echo -e "${RED}Error: app.py not found in voting-app/ directory${NC}"
    echo -e "${YELLOW}Please upload app.py to voting-app/ directory first${NC}"
    echo -e "${YELLOW}From local machine: scp -P 22222 docker-images/voting-app/app.py ubuntu@\$BASTION_IP:~/voting-app/${NC}"
    exit 1
fi

# Build image
docker build -t voting-app:latest ./voting-app/ 2>&1 | tail -5

# Run container
echo -e "\n${YELLOW}[3] Starting voting application container...${NC}"
docker stop voting-app 2>/dev/null || true
docker rm voting-app 2>/dev/null || true

docker run -d \
    --name voting-app \
    -p 8080:8080 \
    -e DB_HOST="$DB_HOST" \
    -e DB_PORT=3306 \
    -e DB_USER=admin \
    -e DB_PASSWORD=admin123 \
    -e DB_NAME=vulnerable_db \
    --network host \
    voting-app:latest

echo -e "${GREEN}✓ Voting application started${NC}"

# Wait for container to start
sleep 5

# Check if container is running
if docker ps | grep -q voting-app; then
    echo -e "${GREEN}✓ Container is running${NC}"
    echo -e "\n${YELLOW}Voting application is available at:${NC}"
    echo -e "${GREEN}http://localhost:8080${NC}"
    echo -e "${GREEN}http://$(curl -s ifconfig.me):8080${NC}"
else
    echo -e "${RED}✗ Container failed to start${NC}"
    echo -e "${YELLOW}Checking logs...${NC}"
    docker logs voting-app | tail -20
    exit 1
fi

echo -e "\n${BLUE}=== Deployment Complete ===${NC}"

# Note about port-forward
if [ "$DB_HOST" = "localhost" ]; then
    echo -e "\n${YELLOW}Note: Database connection via port-forward${NC}"
    echo -e "${YELLOW}Port-forward is running in background${NC}"
fi

# Start legitimate traffic generator
echo -e "\n${YELLOW}[4] Setting up legitimate traffic generator...${NC}"
if [ -f ~/scripts/generate-legitimate-traffic.sh ]; then
    chmod +x ~/scripts/generate-legitimate-traffic.sh
    nohup ~/scripts/generate-legitimate-traffic.sh vulnerable-apps medium > /tmp/legitimate-traffic.log 2>&1 &
    echo -e "${GREEN}✓ Legitimate traffic generator started${NC}"
else
    echo -e "${YELLOW}⚠ Traffic generator script not found (will be uploaded separately)${NC}"
fi

