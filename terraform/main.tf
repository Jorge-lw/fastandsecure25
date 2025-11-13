terraform {
  required_version = ">= 1.0"
  
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}

provider "aws" {
  region = var.aws_region
}


# Data sources
data "aws_availability_zones" "available" {
  state = "available"
}

data "aws_caller_identity" "current" {}

# VPC para máquina bastión
# No necesita NAT Gateways porque solo tiene subnets públicas
module "bastion_vpc" {
  source = "./modules/vpc"
  
  name               = "bastion-vpc"
  cidr               = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway = false  # No necesita NAT Gateway, solo subnets públicas
  
  tags = {
    Environment = "lab"
    Purpose     = "bastion"
  }
}

# VPC para cluster Kubernetes
# Solo necesita 1 NAT Gateway para ahorrar costos en laboratorio
module "k8s_vpc" {
  source = "./modules/vpc"
  
  name               = "k8s-vpc"
  cidr               = "10.1.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway = true
  nat_gateway_count  = 1  # Solo 1 NAT Gateway para ahorrar costos
  
  tags = {
    Environment = "lab"
    Purpose     = "kubernetes"
  }
}

# Peering entre VPCs
resource "aws_vpc_peering_connection" "bastion_to_k8s" {
  vpc_id      = module.bastion_vpc.vpc_id
  peer_vpc_id = module.k8s_vpc.vpc_id
  auto_accept = true

  tags = {
    Name = "bastion-to-k8s-peering"
  }
}

# Route tables para peering
resource "aws_route" "bastion_to_k8s" {
  route_table_id            = module.bastion_vpc.public_route_table_id
  destination_cidr_block    = module.k8s_vpc.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_to_k8s.id
}

resource "aws_route" "k8s_to_bastion" {
  route_table_id            = module.k8s_vpc.private_route_table_id
  destination_cidr_block    = module.bastion_vpc.cidr
  vpc_peering_connection_id = aws_vpc_peering_connection.bastion_to_k8s.id
}

# Security Group para bastión
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.bastion_vpc.vpc_id

  ingress {
    description = "SSH from internet (puerto 22222)"
    from_port   = 22222
    to_port     = 22222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Permitir también puerto 22 por si acaso (puedes eliminarlo después)
  ingress {
    description = "SSH from internet (puerto 22 - temporal)"
    from_port   = 22
    to_port     = 22
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "bastion-sg"
  }
}

# Security Group para EKS
resource "aws_security_group" "eks_cluster" {
  name        = "eks-cluster-sg"
  description = "Security group for EKS cluster"
  vpc_id      = module.k8s_vpc.vpc_id

  ingress {
    description     = "Allow traffic from bastion"
    from_port       = 0
    to_port         = 65535
    protocol        = "tcp"
    security_groups = [aws_security_group.bastion.id]
  }

  egress {
    description = "Allow all outbound"
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = {
    Name = "eks-cluster-sg"
  }
}

# Key pair para bastión
resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key"
  public_key = var.bastion_public_key

  tags = {
    Name = "bastion-key"
  }
}

# Data source para AMI de Ubuntu
data "aws_ami" "ubuntu" {
  most_recent = true
  owners      = ["099720109477"] # Canonical

  filter {
    name   = "name"
    values = ["ubuntu/images/hvm-ssd/ubuntu-jammy-22.04-amd64-server-*"]
  }

  filter {
    name   = "virtualization-type"
    values = ["hvm"]
  }
}

# IAM role para EKS
resource "aws_iam_role" "eks_cluster" {
  name = "eks-cluster-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "eks.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_cluster_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSClusterPolicy"
  role       = aws_iam_role.eks_cluster.name
}

# IAM role para EKS node group
resource "aws_iam_role" "eks_node_group" {
  name = "eks-node-group-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy_attachment" "eks_worker_node_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKSWorkerNodePolicy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_cni_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEKS_CNI_Policy"
  role       = aws_iam_role.eks_node_group.name
}

resource "aws_iam_role_policy_attachment" "eks_container_registry_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2ContainerRegistryReadOnly"
  role       = aws_iam_role.eks_node_group.name
}

# Cluster EKS
# Sin especificar version, EKS usará la versión más reciente soportada por defecto
resource "aws_eks_cluster" "main" {
  name     = "lab-cluster"
  role_arn = aws_iam_role.eks_cluster.arn
  # version no especificada = usa la versión más reciente soportada por EKS

  vpc_config {
    subnet_ids              = module.k8s_vpc.private_subnet_ids
    security_group_ids      = [aws_security_group.eks_cluster.id]
    endpoint_private_access = true
    endpoint_public_access  = true  # Permitir acceso público para facilitar el laboratorio
    # En producción, usaría public_access_cidrs para restringir IPs
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_cluster_policy,
  ]

  tags = {
    Name = "lab-eks-cluster"
  }
}

# Node group para EKS (mínimo para laboratorio)
resource "aws_eks_node_group" "main" {
  cluster_name    = aws_eks_cluster.main.name
  node_group_name = "lab-node-group"
  node_role_arn   = aws_iam_role.eks_node_group.arn
  subnet_ids      = module.k8s_vpc.private_subnet_ids

  scaling_config {
    desired_size = 1
    max_size     = 2
    min_size     = 1
  }

  instance_types = ["t3.small"]

  remote_access {
    ec2_ssh_key               = aws_key_pair.bastion.key_name
    source_security_group_ids = [aws_security_group.bastion.id]
  }

  depends_on = [
    aws_iam_role_policy_attachment.eks_worker_node_policy,
    aws_iam_role_policy_attachment.eks_cni_policy,
    aws_iam_role_policy_attachment.eks_container_registry_policy,
  ]

  tags = {
    Name = "lab-node-group"
  }
}

# Nota: Para que el bastión pueda autenticarse en el cluster EKS, necesitas agregar
# el rol del bastión al ConfigMap aws-auth. Ejecuta el script scripts/add-bastion-to-eks.sh
# después del despliegue, o usa el output del ARN del rol para hacerlo manualmente.

# ECR Repositories
resource "aws_ecr_repository" "vulnerable_images" {
  for_each = toset(var.vulnerable_image_names)
  
  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Permite eliminar el repositorio incluso si tiene imágenes

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name        = each.value
    Environment = "lab"
  }
}

# IAM policy para que bastión pueda acceder a ECR
resource "aws_iam_instance_profile" "bastion" {
  name = "bastion-instance-profile"
  role = aws_iam_role.bastion.name
}

resource "aws_iam_role" "bastion" {
  name = "bastion-role"

  assume_role_policy = jsonencode({
    Statement = [{
      Action = "sts:AssumeRole"
      Effect = "Allow"
      Principal = {
        Service = "ec2.amazonaws.com"
      }
    }]
    Version = "2012-10-17"
  })
}

resource "aws_iam_role_policy" "bastion_ecr" {
  name = "bastion-ecr-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "ecr:GetAuthorizationToken",
          "ecr:BatchCheckLayerAvailability",
          "ecr:GetDownloadUrlForLayer",
          "ecr:BatchGetImage",
          "ecr:PutImage",
          "ecr:InitiateLayerUpload",
          "ecr:UploadLayerPart",
          "ecr:CompleteLayerUpload"
        ]
        Resource = "*"
      }
    ]
  })
}

# Política para permitir acceso al cluster EKS
resource "aws_iam_role_policy" "bastion_eks" {
  name = "bastion-eks-policy"
  role = aws_iam_role.bastion.id

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Effect = "Allow"
        Action = [
          "eks:DescribeCluster",
          "eks:ListClusters",
          "eks:AccessKubernetesApi",
          "eks:DescribeNodegroup",
          "eks:ListNodegroups",
          "eks:DescribeUpdate",
          "eks:ListUpdates"
        ]
        Resource = [
          aws_eks_cluster.main.arn,
          "${aws_eks_cluster.main.arn}/*"
        ]
      },
      {
        Effect = "Allow"
        Action = [
          "eks:ListClusters"
        ]
        Resource = "*"
      }
    ]
  })

  depends_on = [aws_eks_cluster.main]
}

# Instancia EC2 bastión
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = module.bastion_vpc.public_subnet_ids[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # Asegurar que la instancia se cree después de que las políticas IAM estén listas
  depends_on = [
    aws_iam_role_policy.bastion_ecr,
    aws_iam_role_policy.bastion_eks
  ]

  user_data = <<-EOF
    #!/bin/bash
    # No usar set -e para evitar que falle silenciosamente
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    echo "=== Iniciando configuración del bastión ==="
    date
    
    # Actualizar sistema (no crítico si falla)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || echo "ERROR: apt-get update falló"
    apt-get upgrade -y || echo "ERROR: apt-get upgrade falló"
    
    # Instalar y configurar SSH (CRÍTICO)
    echo "Instalando openssh-server..."
    apt-get install -y openssh-server || { echo "ERROR: No se pudo instalar openssh-server"; exit 1; }
    
    # Backup del archivo de configuración
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configurar SSH en puerto 22222
    echo "Configurando SSH en puerto 22222..."
    if ! grep -q "^Port 22222" /etc/ssh/sshd_config; then
      # Comentar cualquier línea Port existente
      sed -i 's/^Port /#Port /' /etc/ssh/sshd_config
      # Agregar nueva configuración
      echo "Port 22222" >> /etc/ssh/sshd_config
      echo "Puerto 22222 agregado a sshd_config"
    else
      echo "Puerto 22222 ya estaba configurado"
    fi
    
    # Permitir root login para simplificar (en producción no hacer esto)
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    
    # Asegurar que SSH escuche en todas las interfaces
    if ! grep -q "^ListenAddress" /etc/ssh/sshd_config; then
      echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config
    fi
    
    # Reiniciar SSH
    echo "Habilitando y reiniciando SSH..."
    systemctl enable ssh || systemctl enable sshd
    systemctl restart ssh || systemctl restart sshd || service ssh restart || service sshd restart
    
    # Esperar un momento y verificar
    sleep 5
    echo "Verificando estado de SSH..."
    systemctl status ssh || systemctl status sshd || service ssh status || service sshd status
    
    # Verificar que SSH está escuchando en el puerto correcto
    echo "Verificando puertos..."
    ss -tlnp | grep 22222 && echo "✓ SSH está escuchando en 22222" || echo "✗ ADVERTENCIA: SSH no está escuchando en 22222"
    ss -tlnp | grep :22 && echo "✓ SSH también está escuchando en 22" || echo "SSH no está en 22"
    
    # Instalar herramientas necesarias (no crítico)
    echo "Instalando herramientas..."
    apt-get install -y curl wget git docker.io awscli jq unzip || echo "Algunas herramientas no se instalaron"
    
    # Instalar kubectl (no crítico)
    if command -v curl > /dev/null; then
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
      chmod +x kubectl && \
      mv kubectl /usr/local/bin/ && \
      echo "kubectl instalado" || echo "kubectl no se pudo instalar"
    fi
    
    # Configurar Docker (no crítico)
    systemctl enable docker || echo "Docker no disponible"
    systemctl start docker || echo "No se pudo iniciar Docker"
    usermod -aG docker ubuntu || echo "No se pudo agregar usuario a docker"
    
    echo "=== Configuración del bastión completada ==="
    date
    echo "SSH debería estar escuchando en los puertos 22 y 22222"
  EOF

  tags = {
    Name = "bastion-host"
  }
}

# Elastic IP para bastión
resource "aws_eip" "bastion" {
  instance = aws_instance.bastion.id
  domain   = "vpc"

  tags = {
    Name = "bastion-eip"
  }
}

