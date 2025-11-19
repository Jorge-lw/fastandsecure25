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

### 2. Configure AWS Profile (Optional)

If you use AWS profiles for credential management, you can configure them:

**Option 1: Environment variable (recommended)**
```bash
export AWS_PROFILE=your-aws-profile
```

**Option 2: Terraform configuration**
Edit `terraform/main.tf` and uncomment the profile line:
```hcl
provider "aws" {
  region  = var.aws_region
  profile = "your-aws-profile"  # Uncomment and set your AWS profile
}
```

**Option 3: AWS credentials file**
Configure your credentials in `~/.aws/credentials`:
```ini
[your-aws-profile]
aws_access_key_id = YOUR_ACCESS_KEY
aws_secret_access_key = YOUR_SECRET_KEY
```

### 3. Configure Terraform Variables

Copy the example file and edit it:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edit `terraform/terraform.tfvars` and add your public SSH key:

```hcl
aws_region = "us-east-1"
bastion_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... your-public-key"
```

### 4. Deploy Infrastructure

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

### 5. Generate SSH RSA Key on Bastion (Optional)

After deploying the infrastructure, you can generate an SSH RSA key pair directly on the bastion host:

```bash
chmod +x scripts/generate-ssh-key-bastion.sh
./scripts/generate-ssh-key-bastion.sh
```

This script:
- Generates a 4096-bit RSA key pair on the bastion
- Stores the keys in `~/.ssh/bastion_rsa_key` (private) and `~/.ssh/bastion_rsa_key.pub` (public)
- Sets proper permissions (600 for private key, 644 for public key)
- Displays the public key fingerprint and content

**Custom key name:**
```bash
./scripts/generate-ssh-key-bastion.sh my_custom_key_name 2048
```

**Download the private key to your local machine:**
```bash
scp -P 22222 ubuntu@<BASTION_IP>:~/.ssh/bastion_rsa_key ~/.ssh/bastion_rsa_key
chmod 600 ~/.ssh/bastion_rsa_key
```

**Use the key for SSH access:**
```bash
ssh -i ~/.ssh/bastion_rsa_key -p 22222 ubuntu@<BASTION_IP>
```

### 6. Get Deployment Information

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
2. **Deploys** applications to the Kubernetes cluster (including blog-app and ecommerce-app)
3. **Adds bastion** to EKS aws-auth ConfigMap (allows kubectl access)
4. **Configures kubectl** on the bastion automatically
5. **Sets up port-forwards** for all applications
6. **Deploys voting app** on the bastion host
7. **Starts legitimate traffic generator** to simulate normal user behavior

After running this script, you can immediately use kubectl from the bastion and all applications will be generating legitimate traffic!

## Build and Push Docker Images

Vulnerable images are located in `docker-images/`:

- **vulnerable-web-app**: Node.js application with multiple vulnerabilities (XSS, SQL Injection, Path Traversal, etc.) - **Now includes legitimate content** (home, products, about, contact pages)
- **vulnerable-api**: Python/Flask API with vulnerabilities (Deserialization, Command Injection, SSRF, etc.) - **Now includes legitimate endpoints** (/health, /api/users, /api/products)
- **vulnerable-database**: MySQL with insecure configuration and test data
- **vulnerable-legacy-app**: Legacy application with known vulnerabilities - Using Tomcat 9 (SecurityManager disabled)
- **blog-app**: Python/Flask blog application with legitimate content (posts, search) - Deployed in cluster
- **ecommerce-app**: Python/Flask e-commerce application with legitimate shopping functionality - Deployed in cluster
- **voting-app**: Python/Flask voting application deployed on bastion host, connects to database in K8s cluster. Contains multiple vulnerabilities:
  - SQL Injection (vote endpoint, API endpoint, admin panel)
  - Cross-Site Scripting (XSS) in comments
  - Path Traversal (file access endpoint)
  - Command Injection (exec endpoint)
  - Insecure Deserialization (pickle)
  - Weak Authentication (admin panel)
  - CSRF (no CSRF tokens)
  - Information Disclosure (debug endpoint)
  - Arbitrary SQL Execution (admin panel)

### Build and Push Manually

```bash
# Set environment variables
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export AWS_ACCOUNT_ID=$(cd terraform && terraform output -raw aws_account_id)
export AWS_PROFILE=your-aws-profile  # Optional: Set your AWS profile name

# Run script
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh
```

**Note:** If `AWS_PROFILE` is not set, the script will use default AWS credentials from your environment or `~/.aws/credentials`.

### Rebuild Failed Applications

If any application pods are failing, you can rebuild them:

```bash
chmod +x scripts/rebuild-failed-apps.sh
export AWS_PROFILE=your-aws-profile  # Optional: Set your AWS profile name
./scripts/rebuild-failed-apps.sh
```

**Note:** If `AWS_PROFILE` is not set, the script will use default AWS credentials.

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

## Deploy Voting Application on Bastion

The voting application runs directly on the bastion host and connects to the database in the Kubernetes cluster.

### Automated Deployment

The voting app is automatically deployed as part of the complete deployment script. If you need to deploy it manually:

```bash
# From your local machine
scp -P 22222 -r docker-images/voting-app/* ubuntu@<BASTION_IP>:~/voting-app/
scp -P 22222 scripts/deploy-voting-app-bastion.sh ubuntu@<BASTION_IP>:~/

# SSH to bastion
ssh -p 22222 ubuntu@<BASTION_IP>

# Deploy voting app
chmod +x ~/deploy-voting-app-bastion.sh
~/deploy-voting-app-bastion.sh
```

The application will be available at:
- `http://localhost:8080` (from bastion)
- `http://<BASTION_IP>:8080` (from internet, if security group allows)

### Voting Application Vulnerabilities

The voting application includes the following vulnerabilities for testing:

1. **SQL Injection**: Multiple endpoints vulnerable to SQL injection
   - Vote endpoint: `POST /vote`
   - API endpoint: `GET /api/votes?question_id=<payload>`
   - Admin panel: `POST /admin/query`

2. **Cross-Site Scripting (XSS)**: Comments section vulnerable to XSS
   - Endpoint: `POST /comment`

3. **Path Traversal**: File access without validation
   - Endpoint: `GET /file?file=<path>`

4. **Command Injection**: Direct command execution
   - Endpoint: `GET /exec?cmd=<command>`

5. **Insecure Deserialization**: Pickle deserialization without validation
   - Endpoint: `GET /deserialize?data=<base64_pickle>`

6. **Weak Authentication**: Admin panel with weak credentials
   - Default: `admin:admin123`
   - Endpoint: `POST /admin`

7. **CSRF**: No CSRF protection on forms
   - All POST endpoints vulnerable

8. **Information Disclosure**: Debug endpoint exposes sensitive data
   - Endpoint: `GET /debug`

9. **Arbitrary SQL Execution**: Admin panel allows arbitrary SQL queries
   - Endpoint: `POST /admin/query`

## Legitimate Traffic Generation

The environment includes a **legitimate traffic generator** that simulates normal user behavior by making regular requests to all applications. This helps create realistic traffic patterns and makes attack traffic less obvious.

### Automated Setup

The traffic generator is automatically started as part of the complete deployment script. It runs in the background and generates traffic at configurable intervals.

### Manual Setup

To set up legitimate traffic generation manually:

```bash
# From the bastion
chmod +x ~/scripts/generate-legitimate-traffic.sh
~/scripts/generate-legitimate-traffic.sh vulnerable-apps medium
```

### Traffic Intensity Levels

- **low**: 10 second delays, 5 requests per cycle
- **medium**: 5 second delays, 10 requests per cycle (default)
- **high**: 2 second delays, 20 requests per cycle

### Applications Targeted

The traffic generator makes legitimate requests to:
- **voting-app**: Home page, voting, viewing results, comments
- **vulnerable-web-app**: Home, products, about, contact pages
- **vulnerable-api**: Health checks, /api/users, /api/products
- **vulnerable-legacy-app**: Home page, index.html
- **blog-app**: Home, posts, individual posts, about
- **ecommerce-app**: Home, products, product details, cart

### Monitoring Traffic

```bash
# View traffic generator logs
tail -f /tmp/legitimate-traffic.log

# Check if traffic generator is running
ps aux | grep generate-legitimate-traffic

# Stop traffic generator
pkill -f generate-legitimate-traffic
```

## Access Applications

### Direct Internet Access (LoadBalancer)

**All Kubernetes services are now exposed directly to the internet via LoadBalancer**, allowing you to attack them directly from your local machine without needing SSH tunnels or port-forwards.

After deployment, get the LoadBalancer URLs:

```bash
kubectl get svc -n vulnerable-apps
```

Wait a few minutes for AWS to assign LoadBalancer IPs. Then access applications directly:

```bash
# Web application
http://<LOADBALANCER_IP>:3000

# API
http://<LOADBALANCER_IP>:5000

# Legacy app
http://<LOADBALANCER_IP>:8080

# Blog app
http://<LOADBALANCER_IP>:8081

# E-commerce app
http://<LOADBALANCER_IP>:8082
```

**Note:** This is intentionally vulnerable - services are exposed to the internet for direct attack access.

### From the Bastion (Alternative)

If you prefer to access via the bastion:

1. Connect to the bastion via SSH (port 22222)
2. Port-forwards are automatically set up by the deployment script
3. Access applications:

```bash
# Voting app (running directly on bastion)
http://localhost:8080

# Web application (via port-forward)
http://localhost:3000

# API (via port-forward)
http://localhost:5000

# Legacy app (via port-forward)
http://localhost:8083

# Blog app (via port-forward)
http://localhost:8081

# E-commerce app (via port-forward)
http://localhost:8082
```

### Manual Port-Forward Setup

If port-forwards are not running automatically:

```bash
# Setup all port-forwards
chmod +x ~/scripts/setup-port-forwards.sh
~/scripts/setup-port-forwards.sh vulnerable-apps
```

### SSH Tunnel Access (Alternative)

Access from your local machine using SSH tunnel:

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

## IAM Role Exploitation

The infrastructure includes an **overly permissive IAM role** (`exploitation-admin-role`) that can be assumed from the bastion host. This role has AdministratorAccess and full IAM write permissions, allowing for cloud reconnaissance and privilege escalation.

### Role Details

- **Role Name**: `exploitation-admin-role`
- **Permissions**: AdministratorAccess + Full IAM write access
- **Assumable By**: Bastion IAM role
- **Purpose**: Demonstrate cloud privilege escalation and reconnaissance

### Exploitation Script

The `exploit-iam-role.sh` script performs the following:

1. **Assumes the exploitation role** using STS AssumeRole
2. **Downloads EICAR test file** (malware simulation) to `/tmp/eicar.com`
3. **Creates additional IAM user** (`recon-user-*`) with AdministratorAccess
4. **Generates access keys** for the new user
5. **Performs cloud reconnaissance**:
   - Lists all IAM users and roles
   - Lists EC2 instances
   - Lists S3 buckets
   - Lists EKS clusters
   - Lists Lambda functions
   - Lists RDS instances
6. **Saves credentials** to `/tmp/recon_credentials.txt`

### Usage

```bash
# From the bastion
cd ~/exploitation
chmod +x exploit-iam-role.sh
./exploit-iam-role.sh
```

Or get the role ARN and run from anywhere:

```bash
export EXPLOITATION_ROLE_ARN=$(cd terraform && terraform output -raw exploitation_role_arn)
./exploitation/exploit-iam-role.sh
```

### Output

The script creates:
- `/tmp/eicar.com` - EICAR test file (malware simulation)
- `/tmp/eicar_com.zip` - EICAR ZIP version
- `/tmp/recon_credentials.txt` - Credentials for the new reconnaissance user
- `/tmp/iam_users.json` - List of all IAM users
- `/tmp/iam_roles.json` - List of all IAM roles
- `/tmp/ec2_instances.json` - List of EC2 instances
- `/tmp/s3_buckets.txt` - List of S3 buckets
- `/tmp/eks_clusters.json` - List of EKS clusters
- `/tmp/lambda_functions.json` - List of Lambda functions
- `/tmp/rds_instances.json` - List of RDS instances

### EICAR Test File

The EICAR (European Institute for Computer Antivirus Research) test file is a standard test file used to verify antivirus software functionality. It's harmless but triggers antivirus detection, making it useful for:
- Testing security monitoring systems
- Simulating malware downloads in attack scenarios
- Verifying that security tools are working correctly

The file is downloaded from `https://www.eicar.org/download/eicar.com` or created locally if the download fails.

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
export AWS_PROFILE=your-aws-profile  # Optional: Set your AWS profile name
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
- `exploit-voting-app.sh` - Exploits voting application vulnerabilities (SQL Injection, XSS, Command Injection, etc.)
- `exploit-iam-role.sh` - **NEW:** Assumes overly permissive IAM role, creates additional user, downloads EICAR, performs cloud reconnaissance
- `lateral-movement.sh` - Lateral movement from bastion to cluster (includes EICAR download)
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
- `master-attack.sh` - Advanced master script (includes voting app exploitation and IAM role exploitation)

**Quick usage:**
```bash
# From the bastion
cd ~/exploitation
./master-exploit.sh
```

## Available Scripts

### Deployment Scripts

- **`scripts/complete-deployment.sh`**: Complete automated deployment (builds, pushes, deploys, configures, sets up traffic)
- **`scripts/build-and-push-images.sh`**: Build and push all Docker images to ECR
- **`scripts/deploy-to-cluster.sh`**: Deploy applications to Kubernetes cluster
- **`scripts/deploy-voting-app-bastion.sh`**: Deploy voting application on bastion host
- **`scripts/setup-port-forwards.sh`**: Set up port-forwards for all applications
- **`scripts/setup-complete-environment.sh`**: Complete environment setup (port-forwards, voting app, traffic generator)
- **`scripts/rebuild-failed-apps.sh`**: Rebuild and redeploy failed applications

### Configuration Scripts

- **`scripts/add-bastion-to-eks.sh`**: Add bastion IAM role to EKS aws-auth ConfigMap
- **`scripts/configure-bastion-kubectl.sh`**: Configure kubectl on bastion remotely via SSH
- **`scripts/fix-kubectl-config.sh`**: Fix kubectl API version (v1alpha1 → v1beta1)
- **`scripts/generate-ssh-key-bastion.sh`**: Generate SSH RSA key pair on bastion host

### Utility Scripts

- **`scripts/cleanup-ecr.sh`**: Clean ECR repositories before terraform destroy
- **`scripts/check-bastion.sh`**: Check bastion host status and connectivity
- **`scripts/monitor-containers.sh`**: Monitor containers with periodic requests (background)
- **`scripts/generate-legitimate-traffic.sh`**: Generate legitimate traffic to all applications (simulates normal users)

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
│   ├── vulnerable-web-app/    # Vulnerable web application (with legitimate content)
│   ├── vulnerable-api/        # Vulnerable API (with legitimate endpoints)
│   ├── vulnerable-database/   # Vulnerable database
│   ├── vulnerable-legacy-app/ # Vulnerable legacy application (Tomcat 9)
│   ├── blog-app/              # Blog application (legitimate content)
│   ├── ecommerce-app/         # E-commerce application (legitimate content)
│   └── voting-app/            # Voting application (deployed on bastion)
├── scripts/
│   ├── build-and-push-images.sh      # Build and push images
│   ├── deploy-to-cluster.sh          # Deploy to cluster
│   ├── complete-deployment.sh        # Complete automated deployment
│   ├── deploy-voting-app-bastion.sh  # Deploy voting app on bastion
│   ├── setup-port-forwards.sh        # Set up port-forwards
│   ├── setup-complete-environment.sh # Complete environment setup
│   ├── generate-legitimate-traffic.sh # Generate legitimate traffic
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
