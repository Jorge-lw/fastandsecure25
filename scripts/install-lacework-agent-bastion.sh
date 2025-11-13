#!/bin/bash

# Script to install Lacework agent (FortiCNP) on bastion

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

LACEWORK_URL="https://2068520.lacework.net/ui/investigation/settings/agents"
AGENT_DIR="/opt/lacework"
AGENT_BINARY="$AGENT_DIR/lacework-agent"

echo -e "${BLUE}=== Installing Lacework Agent on Bastion ===${NC}\n"

# Check if already installed
if [ -f "$AGENT_BINARY" ] && command -v lacework-agent &> /dev/null; then
    echo -e "${YELLOW}Lacework agent is already installed${NC}"
    lacework-agent version 2>/dev/null || true
    read -p "Reinstall? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 0
    fi
fi

# Create installation directory
echo -e "${YELLOW}[1] Creating installation directory...${NC}"
sudo mkdir -p "$AGENT_DIR"
sudo chmod 755 "$AGENT_DIR"
echo -e "${GREEN}✓ Directory created${NC}"

# Detect architecture
echo -e "\n${YELLOW}[2] Detecting architecture...${NC}"
ARCH=$(uname -m)
OS=$(uname -s | tr '[:upper:]' '[:lower:]')

case $ARCH in
    x86_64)
        ARCH="amd64"
        ;;
    aarch64|arm64)
        ARCH="arm64"
        ;;
    *)
        echo -e "${RED}✗ Unsupported architecture: $ARCH${NC}"
        exit 1
        ;;
esac

echo -e "${GREEN}✓ Architecture: $OS-$ARCH${NC}"

# Download agent
echo -e "\n${YELLOW}[3] Downloading Lacework agent...${NC}"
echo -e "${YELLOW}   URL: $LACEWORK_URL${NC}"

# Try different download methods
# Method 1: Try to download directly from configuration URL
# Note: URL may require authentication, so we try different approaches

# First, try to get download link from page
echo -e "${YELLOW}   Attempting to get download link...${NC}"

# For Linux amd64, agent is generally available at:
# https://<account>.lacework.net/ui/investigation/settings/agents/download/<os>/<arch>
DOWNLOAD_URL="https://2068520.lacework.net/ui/investigation/settings/agents/download/linux/${ARCH}"

echo -e "${YELLOW}   Download URL: $DOWNLOAD_URL${NC}"

# Download binary
if curl -L -f -o "$AGENT_BINARY" "$DOWNLOAD_URL" 2>/dev/null; then
    echo -e "${GREEN}✓ Agent downloaded${NC}"
elif wget -O "$AGENT_BINARY" "$DOWNLOAD_URL" 2>/dev/null; then
    echo -e "${GREEN}✓ Agent downloaded${NC}"
else
    echo -e "${YELLOW}⚠ Could not download automatically${NC}"
    echo -e "${YELLOW}   Please download manually from:${NC}"
    echo -e "${BLUE}   $LACEWORK_URL${NC}"
    echo -e "${YELLOW}   And save it to: $AGENT_BINARY${NC}"
    read -p "Continue with manual installation? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
    
    # Verify file exists after manual download
    if [ ! -f "$AGENT_BINARY" ]; then
        echo -e "${RED}✗ File not found at $AGENT_BINARY${NC}"
        exit 1
    fi
fi

# Give execution permissions
echo -e "\n${YELLOW}[4] Configuring permissions...${NC}"
sudo chmod +x "$AGENT_BINARY"
sudo chown root:root "$AGENT_BINARY"
echo -e "${GREEN}✓ Permissions configured${NC}"

# Create symlink in /usr/local/bin for global access
echo -e "\n${YELLOW}[5] Creating symlink...${NC}"
sudo ln -sf "$AGENT_BINARY" /usr/local/bin/lacework-agent
echo -e "${GREEN}✓ Symlink created${NC}"

# Verify installation
echo -e "\n${YELLOW}[6] Verifying installation...${NC}"
if "$AGENT_BINARY" version 2>/dev/null || lacework-agent version 2>/dev/null; then
    echo -e "${GREEN}✓ Agent installed correctly${NC}"
    lacework-agent version 2>/dev/null || "$AGENT_BINARY" version 2>/dev/null
else
    echo -e "${YELLOW}⚠ Could not verify version, but binary is installed${NC}"
fi

# Create systemd service (optional)
echo -e "\n${YELLOW}[7] Creating systemd service...${NC}"
sudo tee /etc/systemd/system/lacework-agent.service > /dev/null <<EOF
[Unit]
Description=Lacework Agent
After=network.target

[Service]
Type=simple
ExecStart=$AGENT_BINARY
Restart=always
RestartSec=10
User=root

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
echo -e "${GREEN}✓ systemd service created${NC}"

# Instructions to start
echo -e "\n${BLUE}=== Installation Completed ===${NC}"
echo -e "${YELLOW}To start the agent:${NC}"
echo -e "  ${GREEN}sudo systemctl start lacework-agent${NC}"
echo -e "  ${GREEN}sudo systemctl enable lacework-agent${NC}"
echo -e ""
echo -e "${YELLOW}To check status:${NC}"
echo -e "  ${GREEN}sudo systemctl status lacework-agent${NC}"
echo -e ""
echo -e "${YELLOW}To run manually:${NC}"
echo -e "  ${GREEN}sudo $AGENT_BINARY${NC}"
echo -e "  ${GREEN}lacework-agent${NC}"
