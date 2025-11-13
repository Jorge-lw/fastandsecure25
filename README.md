# Security Lab Infrastructure - AWS

This project deploys a basic infrastructure in AWS using Terraform that includes:

- **Bastion Host**: EC2 instance with Ubuntu exposing SSH on port 22222
- **Kubernetes Cluster (EKS)**: Minimal cluster for lab in a private VPC
- **ECR Repositories**: Repositories for vulnerable Docker images
- **Vulnerable Applications**: Various Docker applications with different types of vulnerabilities

## Architecture

```
Internet
   │
   ├─> Bastion VPC (10.0.0.0/16)
   │   └─> EC2 Bastion (Port 22222)
   │
   └─> VPC Peering
       │
       └─> K8s VPC (10.1.0.0/16)
           └─> EKS Cluster (Private)
               └─> Vulnerable Applications
```

## Prerequisites

1. **AWS CLI** installed and configured
2. **Terraform** >= 1.0
3. **Docker** installed (to build images)
4. **kubectl** installed (to manage the cluster)
5. **SSH Key** to access the bastion

## Initial Setup

### 1. Generate SSH Key

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion_key
```

### 2. Configure Terraform Variables

Copy the example file and edit it:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and add your public SSH key:

```hcl
aws_region = "us-east-1"
bastion_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... your-public-key"
```

### 3. Deploy Infrastructure

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

This will create:
- 2 VPCs (bastion and Kubernetes)
- VPC Peering between them
- EC2 bastion instance with Ubuntu
- Minimal EKS cluster (1 node)
- ECR repositories for vulnerable images

### 4. Get Deployment Information

```bash
terraform output
```

Note especially:
- `bastion_public_ip`: Public IP of the bastion
- `eks_cluster_name`: Cluster name
- `aws_region`: AWS region

## Build and Push Docker Images

Vulnerable images are located in `docker-images/`:

- **vulnerable-web-app**: Node.js application with multiple vulnerabilities (XSS, SQL Injection, Path Traversal, etc.)
- **vulnerable-api**: Python/Flask API with vulnerabilities (Deserialization, Command Injection, SSRF, etc.)
- **vulnerable-database**: MySQL with insecure configuration and test data
- **vulnerable-legacy-app**: Legacy application with known vulnerabilities

### Build and Push Manually

```bash
# Set environment variables
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export AWS_ACCOUNT_ID=$(cd terraform && terraform output -raw aws_account_id)

# Run script
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh
```

### Or Use the Complete Script

```bash
chmod +x scripts/complete-deployment.sh
./scripts/complete-deployment.sh
```

## Deploy Applications to the Cluster

### From Your Local Machine

First, configure kubectl:

```bash
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export CLUSTER_NAME=$(cd terraform && terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
```

Then deploy:

```bash
chmod +x scripts/deploy-to-cluster.sh
./scripts/deploy-to-cluster.sh
```

### From the Bastion

1. Connect to the bastion:

```bash
ssh -p 22222 -i ~/.ssh/bastion_key ubuntu@<BASTION_IP>
```

2. Configure kubectl:

```bash
aws eks update-kubeconfig --region <REGION> --name lab-cluster
```

3. Deploy applications:

```bash
# From the bastion, you can run the same scripts
# or use kubectl directly
```

## Access Applications

### From the Bastion

1. Connect to the bastion via SSH (port 22222)
2. Set up port-forwarding:

```bash
# For the web application
kubectl port-forward -n vulnerable-apps svc/vulnerable-web-app 3000:3000

# For the API
kubectl port-forward -n vulnerable-apps svc/vulnerable-api 5000:5000
```

3. Access from your local machine using SSH tunnel:

```bash
ssh -p 22222 -i ~/.ssh/bastion_key -L 3000:localhost:3000 ubuntu@<BASTION_IP>
```

Then access `http://localhost:3000` in your browser.

## Types of Vulnerabilities Included

### vulnerable-web-app
- **XSS (Cross-Site Scripting)**: `/search?q=<script>alert(1)</script>`
- **SQL Injection**: `/users?id=1 OR 1=1`
- **Path Traversal**: `/file?name=../../../etc/passwd`
- **Command Injection**: `POST /execute {"command": "ls -la"}`
- **Secret Exposure**: `/secrets`, `/debug`
- **Vulnerable Versions**: Node.js 14, Express 4.16.0

### vulnerable-api
- **Unsafe Deserialization**: `POST /unpickle` (pickle)
- **YAML Deserialization**: `POST /yaml`
- **Command Injection**: `/ping?host=localhost; cat /etc/passwd`
- **Path Traversal**: `/read?file=../../../etc/passwd`
- **SSRF**: `/fetch?url=file:///etc/passwd`
- **Weak Authentication**: Header `X-Token: admin_token_never_change`
- **Environment Variable Exposure**: `/env`

### vulnerable-database
- **Weak Credentials**: root/root123, admin/admin123
- **No Encryption**: Plain text passwords
- **Excessive Privileges**: User 'test' with ALL PRIVILEGES
- **Old Version**: MySQL 5.7 with known CVEs
- **Sensitive Data**: SSN, credit cards unencrypted

### vulnerable-legacy-app
- **Old Version**: Tomcat 8.5 with known vulnerabilities
- **Outdated Java**: OpenJDK 8
- **No Security Manager**: Disabled
- **Excessive Permissions**: Running as root, privileged mode

## Useful Commands

### Terraform

```bash
# View plan
terraform plan

# Apply changes
terraform apply

# Destroy infrastructure
terraform destroy

# View outputs
terraform output
```

### Kubernetes

```bash
# View pods
kubectl get pods -n vulnerable-apps

# View services
kubectl get svc -n vulnerable-apps

# View logs
kubectl logs -n vulnerable-apps deployment/vulnerable-web-app

# Execute command in pod
kubectl exec -it -n vulnerable-apps deployment/vulnerable-web-app -- /bin/sh

# Describe resource
kubectl describe pod -n vulnerable-apps <pod-name>
```

### Docker/ECR

```bash
# Login to ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# List repositories
aws ecr describe-repositories

# List images
aws ecr list-images --repository-name vulnerable-web-app
```

## Security and Considerations

⚠️ **WARNING**: This infrastructure is specifically designed for a **security lab**. **DO NOT** use in production.

The included vulnerabilities are intentional and designed for:
- Practice of offensive security techniques
- Testing vulnerability scanning tools
- Education about application security
- Security team training

**Never deploy this in a production environment or with real data.**

## Cleanup

To destroy all infrastructure:

```bash
cd terraform
terraform destroy
```

This will remove:
- All EC2 instances
- The EKS cluster
- ECR repositories (images will be deleted)
- VPCs and network resources
- All created resources

## Troubleshooting

### Error connecting to cluster

```bash
# Verify cluster exists
aws eks describe-cluster --name lab-cluster --region <region>

# Update kubeconfig
aws eks update-kubeconfig --region <region> --name lab-cluster --kubeconfig ~/.kube/config
```

### Error uploading images to ECR

```bash
# Verify IAM permissions
aws sts get-caller-identity

# Verify ECR login
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

### Pods not starting

```bash
# View events
kubectl get events -n vulnerable-apps --sort-by='.lastTimestamp'

# View logs
kubectl logs -n vulnerable-apps <pod-name>

# Describe pod
kubectl describe pod -n vulnerable-apps <pod-name>
```

## Exploitation Scripts

This project includes exploitation scripts to demonstrate vulnerabilities and perform lateral movement. See [exploitation/README.md](exploitation/README.md) for more details.

**Available scripts:**
- `exploit-web-app.sh` - Exploits web vulnerabilities (XSS, SQL Injection, etc.)
- `exploit-api.sh` - Exploits API vulnerabilities (deserialization, SSRF, etc.)
- `exploit-database.sh` - Exploits database with weak credentials
- `lateral-movement.sh` - Lateral movement from bastion to cluster
- `exploit-k8s.sh` - Exploits Kubernetes vulnerabilities
- `enumerate-resources.sh` - Enumerates cluster resources
- `steal-service-account-token.sh` - Steals service account tokens
- `reverse-shell.sh` - Establishes reverse shells
- `reverse-shell-persistent.sh` - Persistent reverse shells accessible from outside AWS
- `generate-noise.sh` - Generates lots of noise and suspicious activity
- `advanced-attacks.sh` - Advanced attack techniques (MITRE ATT&CK)
- `establish-c2.sh` - Establishes C2 using ngrok/serveo
- `ngrok-setup.sh` - Configures ngrok for external access
- `master-exploit.sh` - Basic master script
- `master-attack.sh` - Advanced master script (maximum noise)

**Quick usage:**
```bash
# From the bastion
cd ~/exploitation
./master-exploit.sh
```

## Project Structure

```
.
├── terraform/
│   ├── main.tf                 # Main configuration
│   ├── variables.tf            # Variables
│   ├── outputs.tf              # Outputs
│   ├── terraform.tfvars.example # Example variables
│   └── modules/
│       └── vpc/                # VPC module
├── docker-images/
│   ├── vulnerable-web-app/    # Vulnerable web application
│   ├── vulnerable-api/        # Vulnerable API
│   ├── vulnerable-database/   # Vulnerable database
│   └── vulnerable-legacy-app/ # Vulnerable legacy application
├── scripts/
│   ├── build-and-push-images.sh    # Build and push images
│   ├── deploy-to-cluster.sh        # Deploy to cluster
│   ├── setup-bastion.sh            # Setup bastion
│   ├── complete-deployment.sh      # Complete script
│   ├── cleanup-ecr.sh              # Clean ECR before destroy
│   └── check-bastion.sh            # Check bastion status
├── exploitation/
│   ├── exploit-web-app.sh          # Exploit web application
│   ├── exploit-api.sh               # Exploit API
│   ├── exploit-database.sh          # Exploit database
│   ├── exploit-k8s.sh               # Exploit Kubernetes
│   ├── lateral-movement.sh          # Lateral movement
│   ├── enumerate-resources.sh       # Enumerate resources
│   ├── steal-service-account-token.sh # Steal tokens
│   ├── reverse-shell.sh              # Reverse shells
│   ├── get-shell.sh                 # Get interactive shell
│   ├── master-exploit.sh            # Master script
│   └── README.md                    # Exploitation documentation
└── README.md                  # This file
```

## License

This project is for educational and lab purposes only.
