#!/bin/bash

# Script to generate SSH RSA key pair on the bastion host
# This creates a key pair that can be used for SSH access or other purposes

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Generate SSH RSA Key on Bastion Host                  ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

# Get bastion IP from Terraform
cd "$PROJECT_ROOT/terraform" 2>/dev/null || {
    echo -e "${RED}Error: Run this script from the project root directory${NC}"
    exit 1
}

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}terraform.tfstate not found. Please run terraform apply first.${NC}"
    exit 1
fi

BASTION_IP=$(terraform output -raw bastion_public_ip 2>/dev/null || echo "")
if [ -z "$BASTION_IP" ]; then
    echo -e "${RED}Could not get bastion IP from Terraform${NC}"
    exit 1
fi

echo -e "${GREEN}Bastion IP: $BASTION_IP${NC}\n"

# Key configuration
KEY_NAME="${1:-bastion_rsa_key}"
KEY_SIZE="${2:-4096}"
KEY_DIR="~/.ssh"
KEY_PATH="$KEY_DIR/$KEY_NAME"

echo -e "${YELLOW}Key configuration:${NC}"
echo -e "  Key name: $KEY_NAME"
echo -e "  Key size: $KEY_SIZE bits"
echo -e "  Key path: $KEY_PATH\n"

# Check if key already exists
echo -e "${YELLOW}[1] Checking if key already exists on bastion...${NC}"
KEY_EXISTS=$(ssh -p 22222 -o StrictHostKeyChecking=no ubuntu@$BASTION_IP \
    "test -f $KEY_PATH && echo 'yes' || echo 'no'" 2>/dev/null || echo "no")

if [ "$KEY_EXISTS" = "yes" ]; then
    echo -e "${YELLOW}⚠ Key $KEY_NAME already exists on bastion${NC}"
    read -p "Do you want to overwrite it? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo -e "${YELLOW}Aborted. Using existing key.${NC}"
        exit 0
    fi
    echo -e "${YELLOW}Removing existing key...${NC}"
    ssh -p 22222 -o StrictHostKeyChecking=no ubuntu@$BASTION_IP \
        "rm -f $KEY_PATH $KEY_PATH.pub" 2>/dev/null || true
fi

# Generate key on bastion
echo -e "\n${YELLOW}[2] Generating SSH RSA key pair on bastion...${NC}"
ssh -p 22222 -o StrictHostKeyChecking=no ubuntu@$BASTION_IP bash <<EOF
    set -euo pipefail
    
    # Create .ssh directory if it doesn't exist
    mkdir -p $KEY_DIR
    chmod 700 $KEY_DIR
    
    # Generate RSA key pair
    ssh-keygen -t rsa -b $KEY_SIZE -f $KEY_PATH -N "" -C "bastion-rsa-key-\$(date +%Y%m%d)"
    
    # Set proper permissions
    chmod 600 $KEY_PATH
    chmod 644 $KEY_PATH.pub
    
    echo "✓ Key pair generated successfully"
    echo "  Private key: $KEY_PATH"
    echo "  Public key: $KEY_PATH.pub"
    
    # Display public key fingerprint
    echo ""
    echo "Public key fingerprint:"
    ssh-keygen -lf $KEY_PATH.pub
    
    # Display public key content
    echo ""
    echo "Public key content:"
    cat $KEY_PATH.pub
EOF

if [ $? -eq 0 ]; then
    echo -e "\n${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║           SSH Key Generated Successfully                      ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}\n"
    
    echo -e "${YELLOW}Key location on bastion:${NC}"
    echo -e "  Private key: $KEY_PATH"
    echo -e "  Public key: $KEY_PATH.pub\n"
    
    echo -e "${YELLOW}To view the public key:${NC}"
    echo -e "  ${GREEN}ssh -p 22222 ubuntu@$BASTION_IP 'cat $KEY_PATH.pub'${NC}\n"
    
    echo -e "${YELLOW}To copy the public key to authorized_keys (for passwordless SSH):${NC}"
    echo -e "  ${GREEN}ssh -p 22222 ubuntu@$BASTION_IP 'cat $KEY_PATH.pub >> ~/.ssh/authorized_keys'${NC}\n"
    
    echo -e "${YELLOW}To download the private key to your local machine:${NC}"
    echo -e "  ${GREEN}scp -P 22222 ubuntu@$BASTION_IP:$KEY_PATH ~/.ssh/${KEY_NAME}${NC}\n"
    
    echo -e "${CYAN}Note: The private key is stored on the bastion.${NC}"
    echo -e "${CYAN}      Download it if you need to use it from your local machine.${NC}"
else
    echo -e "\n${RED}Error: Failed to generate SSH key${NC}"
    exit 1
fi

