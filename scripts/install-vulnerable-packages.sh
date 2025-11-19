#!/bin/bash

# Script to install packages with known critical vulnerabilities on bastion
# This makes the environment more vulnerable for security testing

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Installing Vulnerable Packages on Bastion               ║"
echo "║                  (Lab Only)                                  ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo -e "${NC}\n"

# Update package list
echo -e "${YELLOW}[1] Updating package list...${NC}"
apt-get update -y > /dev/null 2>&1
echo -e "${GREEN}✓ Package list updated${NC}\n"

# Install vulnerable versions of common packages
echo -e "${YELLOW}[2] Installing vulnerable packages...${NC}"

# VULNERABILITY: Old OpenSSL version (CVE-2022-0778, CVE-2021-3711, etc.)
echo -e "${BLUE}  Installing old OpenSSL version...${NC}"
apt-get install -y openssl=1.1.1* 2>/dev/null || \
    apt-get install -y openssl=1.0.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old OpenSSL version${NC}"

# VULNERABILITY: Old curl version (CVE-2021-22946, CVE-2021-22876, etc.)
echo -e "${BLUE}  Installing old curl version...${NC}"
apt-get install -y curl=7.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old curl version${NC}"

# VULNERABILITY: Old wget version (CVE-2021-31879, etc.)
echo -e "${BLUE}  Installing old wget version...${NC}"
apt-get install -y wget=1.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old wget version${NC}"

# VULNERABILITY: Old git version (CVE-2022-39253, etc.)
echo -e "${BLUE}  Installing old git version...${NC}"
apt-get install -y git=1:2.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old git version${NC}"

# VULNERABILITY: Old Python versions with known CVEs
echo -e "${BLUE}  Installing old Python versions...${NC}"
apt-get install -y python2.7 python2.7-minimal 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Python 2.7 not available${NC}"
apt-get install -y python3.8 python3.8-minimal 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Python 3.8 not available${NC}"

# VULNERABILITY: Old sudo version (CVE-2021-3156 - Baron Samedit)
echo -e "${BLUE}  Installing old sudo version...${NC}"
# Try to install older sudo if available
apt-get install -y sudo=1.8.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old sudo version${NC}"

# VULNERABILITY: Old bash version (Shellshock - CVE-2014-6271)
echo -e "${BLUE}  Installing old bash version...${NC}"
apt-get install -y bash=4.2* 2>/dev/null || \
    apt-get install -y bash=4.3* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old bash version${NC}"

# VULNERABILITY: Old Apache2 version (if available)
echo -e "${BLUE}  Installing old Apache2 version...${NC}"
apt-get install -y apache2=2.4.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Apache2 not available${NC}"

# VULNERABILITY: Old nginx version
echo -e "${BLUE}  Installing old nginx version...${NC}"
apt-get install -y nginx=1.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Nginx not available${NC}"

# VULNERABILITY: Old Docker version (CVE-2020-15257, etc.)
echo -e "${BLUE}  Installing old Docker version...${NC}"
# Docker is usually installed via Docker's own repository, so we'll note it
if command -v docker > /dev/null; then
    docker_version=$(docker --version)
    echo -e "${CYAN}    Current Docker: $docker_version${NC}"
    echo -e "${YELLOW}    Note: Consider downgrading Docker manually if needed${NC}"
fi

# VULNERABILITY: Old Node.js version (if npm/node available)
echo -e "${BLUE}  Installing old Node.js version...${NC}"
# Skip Node.js installation as it requires interactive confirmation
# curl -fsSL https://deb.nodesource.com/setup_12.x | DEBIAN_FRONTEND=noninteractive bash - 2>/dev/null || \
#     curl -fsSL https://deb.nodesource.com/setup_14.x | DEBIAN_FRONTEND=noninteractive bash - 2>/dev/null || \
echo -e "${YELLOW}    ⚠ Skipping Node.js installation (requires interactive confirmation)${NC}"

# VULNERABILITY: Old MySQL client
echo -e "${BLUE}  Installing old MySQL client...${NC}"
apt-get install -y mysql-client=5.7.* 2>/dev/null || \
    apt-get install -y mysql-client=8.0.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old MySQL client${NC}"

# VULNERABILITY: Old PostgreSQL client
echo -e "${BLUE}  Installing old PostgreSQL client...${NC}"
apt-get install -y postgresql-client=9.* 2>/dev/null || \
    apt-get install -y postgresql-client=10.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old PostgreSQL client${NC}"

# VULNERABILITY: Old Redis tools
echo -e "${BLUE}  Installing old Redis tools...${NC}"
apt-get install -y redis-tools=5:* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old Redis tools${NC}"

# VULNERABILITY: Old nmap version
echo -e "${BLUE}  Installing old nmap version...${NC}"
apt-get install -y nmap=7.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old nmap version${NC}"

# VULNERABILITY: Old tcpdump version
echo -e "${BLUE}  Installing old tcpdump version...${NC}"
apt-get install -y tcpdump=4.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old tcpdump version${NC}"

# VULNERABILITY: Old netcat versions
echo -e "${BLUE}  Installing old netcat versions...${NC}"
apt-get install -y netcat-traditional netcat-openbsd 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install netcat${NC}"

# VULNERABILITY: Old SSH server (if we can downgrade)
echo -e "${BLUE}  Checking SSH server version...${NC}"
ssh_version=$(sshd -V 2>&1 | head -1 || echo "unknown")
echo -e "${CYAN}    Current SSH: $ssh_version${NC}"
echo -e "${YELLOW}    Note: SSH downgrade may require manual configuration${NC}"

# VULNERABILITY: Install vulnerable Python packages via pip
echo -e "${BLUE}  Installing vulnerable Python packages...${NC}"
if command -v pip3 > /dev/null; then
    # Old Flask with known vulnerabilities
    pip3 install --break-system-packages Flask==0.12.2 2>/dev/null || \
        pip3 install Flask==0.12.2 --user 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old Flask${NC}"
    
    # Old requests library
    pip3 install --break-system-packages requests==2.20.0 2>/dev/null || \
        pip3 install requests==2.20.0 --user 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old requests${NC}"
    
    # Old urllib3
    pip3 install --break-system-packages urllib3==1.24.0 2>/dev/null || \
        pip3 install urllib3==1.24.0 --user 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old urllib3${NC}"
    
    # Old PyYAML (CVE-2020-14343)
    pip3 install --break-system-packages PyYAML==5.1.2 2>/dev/null || \
        pip3 install PyYAML==5.1.2 --user 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old PyYAML${NC}"
fi

# VULNERABILITY: Install vulnerable npm packages
echo -e "${BLUE}  Installing vulnerable npm packages...${NC}"
if command -v npm > /dev/null; then
    npm install -g express@4.16.0 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old express${NC}"
    
    npm install -g lodash@4.17.4 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old lodash${NC}"
    
    npm install -g minimist@0.0.8 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old minimist${NC}"
    
    npm install -g axios@0.18.0 2>/dev/null || \
        echo -e "${YELLOW}    ⚠ Could not install old axios${NC}"
fi

# VULNERABILITY: Install old Java versions (if available)
echo -e "${BLUE}  Installing old Java versions...${NC}"
apt-get install -y openjdk-8-jdk 2>/dev/null || \
    apt-get install -y openjdk-11-jdk 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old Java${NC}"

# VULNERABILITY: Install old Ruby versions
echo -e "${BLUE}  Installing old Ruby versions...${NC}"
apt-get install -y ruby=1:2.7.* 2>/dev/null || \
    apt-get install -y ruby=1:2.9.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old Ruby${NC}"

# VULNERABILITY: Install old Perl versions
echo -e "${BLUE}  Installing old Perl versions...${NC}"
apt-get install -y perl=5.30.* 2>/dev/null || \
    apt-get install -y perl=5.32.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old Perl${NC}"

# VULNERABILITY: Install old PHP versions (CVE-2021-21703, etc.)
echo -e "${BLUE}  Installing old PHP versions...${NC}"
apt-get install -y php7.4 2>/dev/null || \
    apt-get install -y php8.0 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old PHP${NC}"

# VULNERABILITY: Install old Go version
echo -e "${BLUE}  Installing old Go version...${NC}"
if [ ! -d /usr/local/go ]; then
    wget -q https://go.dev/dl/go1.15.15.linux-amd64.tar.gz -O /tmp/go.tar.gz 2>/dev/null && \
        tar -C /usr/local -xzf /tmp/go.tar.gz 2>/dev/null && \
        echo 'export PATH=$PATH:/usr/local/go/bin' >> /etc/profile && \
        echo -e "${GREEN}    ✓ Go 1.15.15 installed${NC}" || \
        echo -e "${YELLOW}    ⚠ Could not install old Go${NC}"
fi

# VULNERABILITY: Install old kubectl version (CVE-2020-8555, etc.)
echo -e "${BLUE}  Installing old kubectl version...${NC}"
if command -v kubectl > /dev/null; then
    kubectl_version=$(kubectl version --client --short 2>/dev/null | cut -d' ' -f3 || echo "unknown")
    echo -e "${CYAN}    Current kubectl: $kubectl_version${NC}"
    echo -e "${YELLOW}    Note: Consider installing kubectl 1.18 or earlier for known vulnerabilities${NC}"
fi

# VULNERABILITY: Install old AWS CLI version
echo -e "${BLUE}  Installing old AWS CLI version...${NC}"
if command -v aws > /dev/null; then
    aws_version=$(aws --version 2>/dev/null || echo "unknown")
    echo -e "${CYAN}    Current AWS CLI: $aws_version${NC}"
    echo -e "${YELLOW}    Note: Consider installing AWS CLI v1 for known vulnerabilities${NC}"
fi

# VULNERABILITY: Install old Docker Compose version
echo -e "${BLUE}  Installing old Docker Compose version...${NC}"
if command -v docker-compose > /dev/null; then
    compose_version=$(docker-compose --version 2>/dev/null || echo "unknown")
    echo -e "${CYAN}    Current Docker Compose: $compose_version${NC}"
fi

# VULNERABILITY: Install old jq version
echo -e "${BLUE}  Installing old jq version...${NC}"
apt-get install -y jq=1.5* 2>/dev/null || \
    apt-get install -y jq=1.6* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old jq${NC}"

# VULNERABILITY: Install old unzip version (CVE-2021-22827)
echo -e "${BLUE}  Installing old unzip version...${NC}"
apt-get install -y unzip=6.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old unzip${NC}"

# VULNERABILITY: Install old tar version
echo -e "${BLUE}  Installing old tar version...${NC}"
apt-get install -y tar=1.3* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old tar${NC}"

# VULNERABILITY: Install old zip version
echo -e "${BLUE}  Installing old zip version...${NC}"
apt-get install -y zip=3.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old zip${NC}"

# VULNERABILITY: Install old vim version
echo -e "${BLUE}  Installing old vim version...${NC}"
apt-get install -y vim=2:8.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old vim${NC}"

# VULNERABILITY: Install old nano version
echo -e "${BLUE}  Installing old nano version...${NC}"
apt-get install -y nano=2.9.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old nano${NC}"

# VULNERABILITY: Install old screen version
echo -e "${BLUE}  Installing old screen version...${NC}"
apt-get install -y screen=4.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old screen${NC}"

# VULNERABILITY: Install old tmux version
echo -e "${BLUE}  Installing old tmux version...${NC}"
apt-get install -y tmux=3.* 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install old tmux${NC}"

# VULNERABILITY: Disable automatic security updates
echo -e "${BLUE}  Disabling automatic security updates...${NC}"
systemctl stop unattended-upgrades 2>/dev/null || true
systemctl disable unattended-upgrades 2>/dev/null || true
echo "APT::Periodic::Update-Package-Lists \"0\";" > /etc/apt/apt.conf.d/20auto-upgrades
echo "APT::Periodic::Unattended-Upgrade \"0\";" >> /etc/apt/apt.conf.d/20auto-upgrades
echo -e "${GREEN}✓ Automatic updates disabled${NC}"

# VULNERABILITY: Install packages with known CVEs
echo -e "${BLUE}  Installing additional vulnerable packages...${NC}"

# Old libc6 version (if available)
apt-get install -y libc6=2.* 2>/dev/null || true

# Old libssl version
apt-get install -y libssl1.1=1.1.* 2>/dev/null || \
    apt-get install -y libssl1.0.0 2>/dev/null || true

# Old zlib version
apt-get install -y zlib1g=1:1.* 2>/dev/null || true

echo -e "${GREEN}✓ Vulnerable packages installation completed${NC}\n"

# VULNERABILITY: Create vulnerable configuration files
echo -e "${BLUE}  Creating vulnerable configuration files...${NC}"
# Create a world-writable directory
mkdir -p /tmp/vulnerable-data
chmod 777 /tmp/vulnerable-data
echo -e "${GREEN}    ✓ Created /tmp/vulnerable-data with 777 permissions${NC}"

# Create a file with weak permissions
echo "Sensitive data: admin:password123" > /tmp/vulnerable-data/secrets.txt
chmod 666 /tmp/vulnerable-data/secrets.txt
echo -e "${GREEN}    ✓ Created /tmp/vulnerable-data/secrets.txt with weak permissions${NC}"

# Create a vulnerable sudoers entry (for demonstration only)
# Note: This is dangerous and should only be in a lab environment
if [ -f /etc/sudoers.d/vulnerable-lab ]; then
    echo -e "${YELLOW}    ⚠ Vulnerable sudoers entry already exists${NC}"
else
    echo "ubuntu ALL=(ALL) NOPASSWD: ALL" > /tmp/vulnerable-sudoers
    chmod 0440 /tmp/vulnerable-sudoers
    echo -e "${YELLOW}    ⚠ Skipping sudoers modification for safety${NC}"
fi

# VULNERABILITY: Install vulnerable kernel modules or tools
echo -e "${BLUE}  Installing additional vulnerable tools...${NC}"
apt-get install -y strace ltrace gdb 2>/dev/null || \
    echo -e "${YELLOW}    ⚠ Could not install debugging tools${NC}"

# Show installed versions
echo -e "${YELLOW}[3] Installed versions:${NC}"
echo -e "${CYAN}OpenSSL:${NC}"
openssl version 2>/dev/null || echo "  Not installed"
echo -e "${CYAN}Curl:${NC}"
curl --version 2>/dev/null | head -1 || echo "  Not installed"
echo -e "${CYAN}Git:${NC}"
git --version 2>/dev/null || echo "  Not installed"
echo -e "${CYAN}Python:${NC}"
python --version 2>/dev/null || python3 --version 2>/dev/null || echo "  Not installed"
python2.7 --version 2>/dev/null || echo "  Python 2.7 not installed"
echo -e "${CYAN}Sudo:${NC}"
sudo --version 2>/dev/null | head -1 || echo "  Not installed"
echo -e "${CYAN}Bash:${NC}"
bash --version 2>/dev/null | head -1 || echo "  Not installed"
echo -e "${CYAN}Apache2:${NC}"
apache2 -v 2>/dev/null | head -1 || echo "  Not installed"
echo -e "${CYAN}Nginx:${NC}"
nginx -v 2>/dev/null || echo "  Not installed"
echo -e "${CYAN}Docker:${NC}"
docker --version 2>/dev/null || echo "  Not installed"
echo -e "${CYAN}Java:${NC}"
java -version 2>&1 | head -1 || echo "  Not installed"
echo -e "${CYAN}PHP:${NC}"
php --version 2>/dev/null | head -1 || echo "  Not installed"
echo -e "${CYAN}Ruby:${NC}"
ruby --version 2>/dev/null || echo "  Not installed"
echo -e "${CYAN}Perl:${NC}"
perl --version 2>/dev/null | head -1 || echo "  Not installed"

echo -e "\n${GREEN}✓ Vulnerable packages installed${NC}"
echo -e "${YELLOW}Note: Some packages may have been installed at latest available version${NC}"
echo -e "${YELLOW}      due to repository limitations. Check versions manually if needed.${NC}"

