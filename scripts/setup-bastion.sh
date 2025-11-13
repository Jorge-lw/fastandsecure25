#!/bin/bash

# Script para configurar el bastión con las herramientas necesarias

set -e

# Este script se ejecuta en el bastión después del despliegue
# Se puede ejecutar manualmente o agregar al user_data

echo "Configurando bastión host..."

# Actualizar sistema
sudo apt-get update -y

# Instalar herramientas necesarias
sudo apt-get install -y \
    curl \
    wget \
    git \
    docker.io \
    kubectl \
    awscli \
    jq \
    unzip

# Configurar Docker
sudo systemctl start docker
sudo systemctl enable docker
sudo usermod -aG docker ubuntu

# Instalar AWS CLI v2 si no está instalado
if ! command -v aws &> /dev/null; then
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    unzip awscliv2.zip
    sudo ./aws/install
fi

# Instalar kubectl si no está instalado
if ! command -v kubectl &> /dev/null; then
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
fi

# Instalar eksctl
if ! command -v eksctl &> /dev/null; then
    curl --silent --location "https://github.com/weaveworks/eksctl/releases/latest/download/eksctl_$(uname -s)_amd64.tar.gz" | tar xz -C /tmp
    sudo mv /tmp/eksctl /usr/local/bin
fi

# Configurar kubectl para el cluster (esto se hace después de crear el cluster)
# aws eks update-kubeconfig --region <region> --name lab-cluster

echo "✓ Bastión configurado correctamente"

