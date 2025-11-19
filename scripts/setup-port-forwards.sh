#!/bin/bash

# Script to set up port-forwards for all applications
# Runs in background to keep connections alive

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

NAMESPACE="${1:-vulnerable-apps}"
LOG_DIR="${2:-/tmp/port-forwards}"

mkdir -p "$LOG_DIR"

echo -e "${GREEN}=== Setting up port-forwards ===${NC}\n"

# Function to start port-forward
start_port_forward() {
    local service=$1
    local local_port=$2
    local remote_port=$3
    
    # Check if already running
    if ps aux | grep -q "[k]ubectl port-forward.*$service.*$local_port"; then
        echo -e "${YELLOW}  Port-forward for $service:$local_port already running${NC}"
        return 0
    fi
    
    echo -e "${YELLOW}Starting port-forward: $service ($local_port:$remote_port)...${NC}"
    kubectl port-forward -n "$NAMESPACE" svc/$service $local_port:$remote_port > "$LOG_DIR/${service}-${local_port}.log" 2>&1 &
    PF_PID=$!
    sleep 2
    
    if ps -p $PF_PID > /dev/null 2>&1; then
        echo -e "${GREEN}  ✓ Port-forward started (PID: $PF_PID)${NC}"
        return 0
    else
        echo -e "${RED}  ✗ Port-forward failed${NC}"
        return 1
    fi
}

# Start port-forwards for all services
start_port_forward "vulnerable-web-app" 3000 3000
start_port_forward "vulnerable-api" 5000 5000
start_port_forward "vulnerable-legacy-app" 8083 8080
start_port_forward "vulnerable-database" 3306 3306

# Additional apps if they exist (using service ports)
start_port_forward "blog-app" 8081 8081 2>/dev/null || true
start_port_forward "ecommerce-app" 8082 8082 2>/dev/null || true

echo -e "\n${GREEN}=== Port-forwards setup complete ===${NC}"
echo -e "${YELLOW}Logs are in: $LOG_DIR${NC}"
echo -e "${YELLOW}To stop all port-forwards: pkill -f 'kubectl port-forward'${NC}"

