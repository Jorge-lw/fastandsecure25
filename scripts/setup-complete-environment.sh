#!/bin/bash

# Complete script to set up the entire environment
# Includes port-forwards, voting app, and legitimate traffic

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Complete Environment Setup                              ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Step 1: Setup port-forwards
echo -e "${YELLOW}[1] Setting up port-forwards...${NC}"
chmod +x "$SCRIPT_DIR/setup-port-forwards.sh"
"$SCRIPT_DIR/setup-port-forwards.sh" vulnerable-apps
sleep 3

# Step 2: Deploy voting app
echo -e "\n${YELLOW}[2] Deploying voting application...${NC}"
chmod +x "$SCRIPT_DIR/deploy-voting-app-bastion.sh"
"$SCRIPT_DIR/deploy-voting-app-bastion.sh"

# Step 3: Start legitimate traffic generator
echo -e "\n${YELLOW}[3] Starting legitimate traffic generator...${NC}"
chmod +x "$SCRIPT_DIR/generate-legitimate-traffic.sh"
nohup "$SCRIPT_DIR/generate-legitimate-traffic.sh" vulnerable-apps medium > /tmp/legitimate-traffic.log 2>&1 &
TRAFFIC_PID=$!
sleep 2

if ps -p $TRAFFIC_PID > /dev/null 2>&1; then
    echo -e "${GREEN}✓ Traffic generator started (PID: $TRAFFIC_PID)${NC}"
else
    echo -e "${YELLOW}⚠ Traffic generator may have failed, check logs${NC}"
fi

echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║              Environment Setup Complete                       ║${NC}"
echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"

echo -e "\n${YELLOW}Running services:${NC}"
echo -e "  ✓ Port-forwards active"
echo -e "  ✓ Voting application: http://localhost:8080"
echo -e "  ✓ Legitimate traffic generator (PID: $TRAFFIC_PID)"

echo -e "\n${YELLOW}To stop traffic generator:${NC}"
echo -e "  ${GREEN}kill $TRAFFIC_PID${NC}"

echo -e "\n${YELLOW}To stop all port-forwards:${NC}"
echo -e "  ${GREEN}pkill -f 'kubectl port-forward'${NC}"

