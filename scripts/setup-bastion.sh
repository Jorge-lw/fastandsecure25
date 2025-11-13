#!/bin/bash

# Script to configure bastion with necessary tools

set -e

# This script runs on the bastion after deployment
# Can be run manually or added to user_data

echo "Configuring bastion host..."

# Update system
sudo apt-get update -y

# Install necessary tools
sudo apt-get install -y \
    curl \
    wget \
    git \
    docker.io \
    kubectl \
    awscli \
    jq \
    unzip

# Configure Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Install AWS CLI v2 if not installed
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
fi

# Install kubectl if not installed
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Install eksctl
if ! command -v eksctl &> /dev/null; then
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

# Configure kubectl for cluster (this is done after creating the cluster)
# aws eks update-kubeconfig --region <region> --name lab-cluster

echo "✓ Bastion configured correctly"
