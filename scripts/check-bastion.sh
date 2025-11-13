#!/bin/bash

# Script to check bastion status

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Checking bastion status...${NC}"

# Get Terraform information
cd terraform 2>/dev/null || { echo "Error: You are not in the correct directory"; exit 1; }

BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
INSTANCE_ID=$(terraform output -raw bastion_instance_id 2>/dev/null || echo "")

if [ -z "$BASTION_IP" ]; then
    echo -e "${RED}Could not get bastion IP from Terraform${NC}"
    echo "Checking EC2 instances directly..."
    INSTANCE_ID=$(aws ec2 describe-instances \
        --filters "Name=tag:Name,Values=bastion-host" "Name=instance-state-name,Values=running" \
        --query 'Reservations[0].Instances[0].InstanceId' --output text 2>/dev/null || echo "")
    
    if [ -z "$INSTANCE_ID" ] || [ "$INSTANCE_ID" == "None" ]; then
        echo -e "${RED}Bastion instance not found${NC}"
        exit 1
    fi
    
    BASTION_IP=$(aws ec2 describe-instances \
        --instance-ids $INSTANCE_ID \
        --query 'Reservations[0].Instances[0].PublicIpAddress' --output text 2>/dev/null || echo "")
fi

echo -e "${GREEN}Bastion IP: $BASTION_IP${NC}"
echo -e "${GREEN}Instance ID: $INSTANCE_ID${NC}"

# Check instance status
echo -e "\n${YELLOW}Instance status:${NC}"
aws ec2 describe-instance-status --instance-ids $INSTANCE_ID --query 'InstanceStatuses[0]' --output json

# Check security groups
echo -e "\n${YELLOW}Security Groups:${NC}"
aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[*].[GroupId,GroupName]' --output table

# Check security rules
SG_ID=$(aws ec2 describe-instances --instance-ids $INSTANCE_ID \
    --query 'Reservations[0].Instances[0].SecurityGroups[0].GroupId' --output text)

echo -e "\n${YELLOW}Security Group ingress rules:${NC}"
aws ec2 describe-security-groups --group-ids $SG_ID \
    --query 'SecurityGroups[0].IpPermissions' --output json

# Check user-data logs (if possible)
echo -e "\n${YELLOW}Attempting to check user-data logs...${NC}"
echo "To view logs, connect to the instance and run:"
echo "  sudo cat /var/log/user-data.log"
echo "  sudo cat /var/log/cloud-init-output.log"

# Connectivity test
echo -e "\n${YELLOW}Testing connectivity:${NC}"
echo "Port 22:"
timeout 3 bash -c "echo > /dev/tcp/$BASTION_IP/22" 2>/dev/null && echo -e "${GREEN}✓ Port 22 accessible${NC}" || echo -e "${RED}✗ Port 22 not accessible${NC}"

echo "Port 22222:"
timeout 3 bash -c "echo > /dev/tcp/$BASTION_IP/22222" 2>/dev/null && echo -e "${GREEN}✓ Port 22222 accessible${NC}" || echo -e "${RED}✗ Port 22222 not accessible${NC}"

echo -e "\n${YELLOW}Command to connect:${NC}"
echo "ssh -i ~/.ssh/bastion_key ubuntu@$BASTION_IP"
echo "ssh -p 22222 -i ~/.ssh/bastion_key ubuntu@$BASTION_IP"
