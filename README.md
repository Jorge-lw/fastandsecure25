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
- EC2 bastion instance with Ubuntu (automatically configured with AWS CLI v2, kubectl, Docker)
- Minimal EKS cluster (1 node)
- ECR repositories for vulnerable images

**Note:** The bastion is automatically configured during deployment with:
- AWS CLI v2 (latest version)
- kubectl (latest version)
- Docker
- All necessary tools

### 4. Get Deployment Information

```bash
terraform output
```

Note especially:
- `bastion_public_ip`: Public IP of the bastion
- `eks_cluster_name`: Cluster name
- `aws_region`: AWS region

## Complete Automated Deployment

The easiest way to deploy everything is using the complete deployment script:

```bash
chmod +x scripts/complete-deployment.sh
./scripts/complete-deployment.sh
```

This script automates the entire process:
1. **Builds and pushes** all Docker images to ECR
2. **Deploys** applications to the Kubernetes cluster
3. **Adds bastion** to EKS aws-auth ConfigMap (allows kubectl access)
4. **Configures kubectl** on the bastion automatically

After running this script, you can immediately use kubectl from the bastion!

## Build and Push Docker Images

Vulnerable images are located in `docker-images/`:

- **vulnerable-web-app**: Node.js application with multiple vulnerabilities (XSS, SQL Injection, Path Traversal, etc.)
- **vulnerable-api**: Python/Flask API with vulnerabilities (Deserialization, Command Injection, SSRF, etc.) - Fixed dependency compatibility issues
- **vulnerable-database**: MySQL with insecure configuration and test data
- **vulnerable-legacy-app**: Legacy application with known vulnerabilities - Using Tomcat 9 (SecurityManager disabled)

### Build and Push Manually

```bash
# Set environment variables
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export AWS_ACCOUNT_ID=$(cd terraform && terraform output -raw aws_account_id)
export AWS_PROFILE=Admin-Forti  # Or your AWS profile

# Run script
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh
```

### Rebuild Failed Applications

If any application pods are failing, you can rebuild them:

```bash
chmod +x scripts/rebuild-failed-apps.sh
export AWS_PROFILE=Admin-Forti  # Or your AWS profile
./scripts/rebuild-failed-apps.sh
```

## Deploy Applications to the Cluster

### Automated Deployment (Recommended)

The easiest way is to use the complete deployment script, which automates everything:

```bash
chmod +x scripts/complete-deployment.sh
./scripts/complete-deployment.sh
```

This script will:
1. Build and push all Docker images to ECR
2. Deploy applications to the Kubernetes cluster
3. Add the bastion role to EKS aws-auth ConfigMap
4. Configure kubectl on the bastion automatically

### Manual Deployment

#### From Your Local Machine

First, configure kubectl:

```bash
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export CLUSTER_NAME=$(cd terraform && terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Fix API version if needed (for older kubectl versions)
sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' ~/.kube/config
```

Then deploy:

```bash
chmod +x scripts/deploy-to-cluster.sh
./scripts/deploy-to-cluster.sh
```

#### From the Bastion

The bastion is automatically configured with:
- **AWS CLI v2** (latest version)
- **kubectl** (latest version)
- **Docker** (for building images)

1. Connect to the bastion:

```bash
ssh -p 22222 ubuntu@<BASTION_IP>
```

2. Configure kubectl (if not already done):

```bash
export AWS_REGION=$(terraform output -raw aws_region)
export CLUSTER_NAME=$(terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME

# Fix API version if needed
sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' ~/.kube/config
```

3. Verify kubectl works:

```bash
kubectl get pods -n vulnerable-apps
kubectl get services -n vulnerable-apps
```

### Adding Bastion to EKS Cluster

If you need to manually add the bastion role to the EKS cluster:

```bash
chmod +x scripts/add-bastion-to-eks.sh
./scripts/add-bastion-to-eks.sh
```

This script:
- Gets the bastion role ARN from Terraform
- Adds it to the EKS aws-auth ConfigMap
- Configures kubectl with the correct API version

### Configuring kubectl on Bastion

To configure kubectl on the bastion remotely:

```bash
chmod +x scripts/configure-bastion-kubectl.sh
./scripts/configure-bastion-kubectl.sh
```

This script:
- Connects to the bastion via SSH
- Configures kubectl for the EKS cluster
- Fixes the API version (v1alpha1 → v1beta1)
- Verifies that kubectl works correctly

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
- **Old Version**: Tomcat 9 with known vulnerabilities
- **Outdated Java**: OpenJDK 8
- **No Security Manager**: Disabled
- **Excessive Permissions**: Running as root, privileged mode
- **Permissive Security Policy**: All permissions granted

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
aws eks update-kubeconfig --region <region> --name lab-cluster

# Fix API version if you get "invalid apiVersion v1alpha1" error
sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' ~/.kube/config

# Or use the fix script
chmod +x scripts/fix-kubectl-config.sh
./scripts/fix-kubectl-config.sh
```

### kubectl API version error

If you see `error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"`:

```bash
# Fix the kubeconfig file
sed -i.bak 's/client.authentication.k8s.io\/v1alpha1/client.authentication.k8s.io\/v1beta1/g' ~/.kube/config

# Or use the fix script
chmod +x scripts/fix-kubectl-config.sh
./scripts/fix-kubectl-config.sh
```

### Bastion cannot access cluster

If kubectl on the bastion cannot access the cluster:

1. Verify the bastion role is in aws-auth ConfigMap:
```bash
chmod +x scripts/add-bastion-to-eks.sh
./scripts/add-bastion-to-eks.sh
```

2. Configure kubectl on the bastion:
```bash
chmod +x scripts/configure-bastion-kubectl.sh
./scripts/configure-bastion-kubectl.sh
```

3. Verify AWS CLI version on bastion (should be v2):
```bash
ssh -p 22222 ubuntu@<BASTION_IP> "aws --version"
# Should show: aws-cli/2.x.x
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

# View previous container logs (if pod restarted)
kubectl logs -n vulnerable-apps <pod-name> --previous

# Describe pod
kubectl describe pod -n vulnerable-apps <pod-name>

# Check pod status
kubectl get pods -n vulnerable-apps -o wide
```

### Application pods failing (CrashLoopBackOff)

If pods are in CrashLoopBackOff state:

1. Check the logs to identify the issue:
```bash
kubectl logs -n vulnerable-apps <pod-name> --tail=50
```

2. Rebuild and redeploy the failed application:
```bash
chmod +x scripts/rebuild-failed-apps.sh
export AWS_PROFILE=Admin-Forti  # Or your AWS profile
./scripts/rebuild-failed-apps.sh
```

Common issues:
- **vulnerable-api**: Dependency compatibility issues (fixed with specific versions)
- **vulnerable-legacy-app**: SecurityManager issues (fixed with Tomcat 9)

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

## Available Scripts

### Deployment Scripts

- **`scripts/complete-deployment.sh`**: Complete automated deployment (builds, pushes, deploys, configures)
- **`scripts/build-and-push-images.sh`**: Build and push all Docker images to ECR
- **`scripts/deploy-to-cluster.sh`**: Deploy applications to Kubernetes cluster
- **`scripts/rebuild-failed-apps.sh`**: Rebuild and redeploy failed applications

### Configuration Scripts

- **`scripts/add-bastion-to-eks.sh`**: Add bastion IAM role to EKS aws-auth ConfigMap
- **`scripts/configure-bastion-kubectl.sh`**: Configure kubectl on bastion remotely via SSH
- **`scripts/fix-kubectl-config.sh`**: Fix kubectl API version (v1alpha1 → v1beta1)

### Utility Scripts

- **`scripts/cleanup-ecr.sh`**: Clean ECR repositories before terraform destroy
- **`scripts/check-bastion.sh`**: Check bastion host status and connectivity
- **`scripts/monitor-containers.sh`**: Monitor containers with periodic requests (background)

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
│   ├── vulnerable-api/        # Vulnerable API (fixed dependencies)
│   ├── vulnerable-database/   # Vulnerable database
│   └── vulnerable-legacy-app/ # Vulnerable legacy application (Tomcat 9)
├── scripts/
│   ├── build-and-push-images.sh      # Build and push images
│   ├── deploy-to-cluster.sh          # Deploy to cluster
│   ├── complete-deployment.sh        # Complete automated deployment
│   ├── add-bastion-to-eks.sh        # Add bastion to EKS aws-auth
│   ├── configure-bastion-kubectl.sh  # Configure kubectl on bastion
│   ├── fix-kubectl-config.sh        # Fix kubectl API version
│   ├── rebuild-failed-apps.sh       # Rebuild failed applications
│   ├── cleanup-ecr.sh                # Clean ECR before destroy
│   ├── check-bastion.sh              # Check bastion status
│   └── monitor-containers.sh         # Monitor containers (background)
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
