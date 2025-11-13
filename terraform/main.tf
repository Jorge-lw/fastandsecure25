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

# VPC for bastion host
# Does not need NAT Gateways because it only has public subnets
module "bastion_vpc" {
  source = "./modules/vpc"
  
  name               = "bastion-vpc"
  cidr               = "10.0.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway = false  # Does not need NAT Gateway, only public subnets
  
  tags = {
    Environment = "lab"
    Purpose     = "bastion"
  }
}

# VPC for Kubernetes cluster
# Only needs 1 NAT Gateway to save costs in lab
module "k8s_vpc" {
  source = "./modules/vpc"
  
  name               = "k8s-vpc"
  cidr               = "10.1.0.0/16"
  availability_zones = slice(data.aws_availability_zones.available.names, 0, 2)
  enable_nat_gateway = true
  nat_gateway_count  = 1  # Only 1 NAT Gateway to save costs
  
  tags = {
    Environment = "lab"
    Purpose     = "kubernetes"
  }
}

# Peering between VPCs
resource "aws_vpc_peering_connection" "bastion_to_k8s" {
  vpc_id      = module.bastion_vpc.vpc_id
  peer_vpc_id = module.k8s_vpc.vpc_id
  auto_accept = true

  tags = {
    Name = "bastion-to-k8s-peering"
  }
}

# Route tables for peering
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

# Security Group for bastion
resource "aws_security_group" "bastion" {
  name        = "bastion-sg"
  description = "Security group for bastion host"
  vpc_id      = module.bastion_vpc.vpc_id

  ingress {
    description = "SSH from internet (port 22222)"
    from_port   = 22222
    to_port     = 22222
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Also allow port 22 just in case (you can remove it later)
  ingress {
    description = "SSH from internet (port 22 - temporary)"
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

# Key pair for bastion
resource "aws_key_pair" "bastion" {
  key_name   = "bastion-key"
  public_key = var.bastion_public_key

  tags = {
    Name = "bastion-key"
  }
}

# Data source for Ubuntu AMI
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

# IAM role for EKS
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

# IAM role for EKS node group
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

# Note: For the bastion to authenticate to the EKS cluster, you need to add
# the bastion role to the aws-auth ConfigMap. Run scripts/add-bastion-to-eks.sh
# after deployment, or use the role ARN output to do it manually.

# ECR Repositories
resource "aws_ecr_repository" "vulnerable_images" {
  for_each = toset(var.vulnerable_image_names)
  
  name                 = each.value
  image_tag_mutability = "MUTABLE"
  force_delete         = true  # Allows deleting repository even if it has images

  image_scanning_configuration {
    scan_on_push = false
  }

  tags = {
    Name        = each.value
    Environment = "lab"
  }
}

# IAM policy for bastion to access ECR
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

# Policy to allow access to EKS cluster
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

# EC2 bastion instance
resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.ubuntu.id
  instance_type          = "t3.micro"
  key_name               = aws_key_pair.bastion.key_name
  vpc_security_group_ids = [aws_security_group.bastion.id]
  subnet_id              = module.bastion_vpc.public_subnet_ids[0]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name

  # Ensure instance is created after IAM policies are ready
  depends_on = [
    aws_iam_role_policy.bastion_ecr,
    aws_iam_role_policy.bastion_eks
  ]

  user_data = <<-EOF
    #!/bin/bash
    # Do not use set -e to avoid silent failures
    exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1
    
    echo "=== Starting bastion configuration ==="
    date
    
    # Update system (not critical if it fails)
    export DEBIAN_FRONTEND=noninteractive
    apt-get update -y || echo "ERROR: apt-get update failed"
    apt-get upgrade -y || echo "ERROR: apt-get upgrade failed"
    
    # Install and configure SSH (CRITICAL)
    echo "Installing openssh-server..."
    apt-get install -y openssh-server || { echo "ERROR: Could not install openssh-server"; exit 1; }
    
    # Backup configuration file
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
    
    # Configure SSH on port 22222
    echo "Configuring SSH on port 22222..."
    if ! grep -q "^Port 22222" /etc/ssh/sshd_config; then
      # Comment any existing Port line
      sed -i 's/^Port /#Port /' /etc/ssh/sshd_config
      # Add new configuration
      echo "Port 22222" >> /etc/ssh/sshd_config
      echo "Port 22222 added to sshd_config"
    else
      echo "Port 22222 already configured"
    fi
    
    # Allow root login to simplify (do not do this in production)
    sed -i 's/^#PermitRootLogin.*/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin prohibit-password/PermitRootLogin yes/' /etc/ssh/sshd_config
    sed -i 's/^PermitRootLogin no/PermitRootLogin yes/' /etc/ssh/sshd_config
    
    # Ensure SSH listens on all interfaces
    if ! grep -q "^ListenAddress" /etc/ssh/sshd_config; then
      echo "ListenAddress 0.0.0.0" >> /etc/ssh/sshd_config
    fi
    
    # Restart SSH
    echo "Enabling and restarting SSH..."
    systemctl enable ssh || systemctl enable sshd
    systemctl restart ssh || systemctl restart sshd || service ssh restart || service sshd restart
    
    # Wait a moment and verify
    sleep 5
    echo "Verifying SSH status..."
    systemctl status ssh || systemctl status sshd || service ssh status || service sshd status
    
    # Verify SSH is listening on the correct port
    echo "Verifying ports..."
    ss -tlnp | grep 22222 && echo "✓ SSH is listening on 22222" || echo "✗ WARNING: SSH is not listening on 22222"
    ss -tlnp | grep :22 && echo "✓ SSH is also listening on 22" || echo "SSH is not on 22"
    
    # Install necessary tools (not critical)
    echo "Installing tools..."
    apt-get install -y curl wget git docker.io awscli jq unzip || echo "Some tools were not installed"
    
    # Install kubectl (not critical)
    if command -v curl > /dev/null; then
      curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl" && \
      chmod +x kubectl && \
      mv kubectl /usr/local/bin/ && \
      echo "kubectl installed" || echo "kubectl could not be installed"
    fi
    
    # Configure Docker (not critical)
    systemctl enable docker || echo "Docker not available"
    systemctl start docker || echo "Could not start Docker"
    usermod -aG docker ubuntu || echo "Could not add user to docker"
    
    echo "=== Bastion configuration completed ==="
    date
    echo "SSH should be listening on ports 22 and 22222"
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

