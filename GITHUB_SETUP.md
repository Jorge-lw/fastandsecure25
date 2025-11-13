# Guide to Upload Code to GitHub

## Steps to Create and Upload the Repository

### Option 1: Using the Automated Script

```bash
# Run the setup script
chmod +x scripts/setup-github.sh
./scripts/setup-github.sh
```

Then follow the on-screen instructions.

### Option 2: Manual Steps

#### 1. Initialize Git (if not initialized)

```bash
git init
```

#### 2. Verify .gitignore

The `.gitignore` file is already configured to exclude:
- Terraform files (state, sensitive variables)
- SSH keys
- AWS/Kubernetes configurations
- Temporary files

#### 3. Add files and commit

```bash
# Add all files
git add .

# Verify what will be committed (optional)
git status

# Create initial commit
git commit -m "Initial commit: Security lab infrastructure"
```

#### 4. Create Repository on GitHub

1. Go to [https://github.com/new](https://github.com/new)
2. **Repository name**: `fastandsecure25` (or your preferred name)
3. **Description**: `Security lab infrastructure with Terraform, AWS EKS and vulnerable applications`
4. **Visibility**: 
   - `Private` - If you want to keep it private
   - `Public` - If you want to share it (recommended for educational projects)
5. **IMPORTANT**: DO NOT check the options for:
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license
   
   (We already have these files in the project)

6. Click **"Create repository"**

#### 5. Connect Local Repository with GitHub

```bash
# Replace YOUR_USERNAME with your GitHub username
git remote add origin https://github.com/YOUR_USERNAME/fastandsecure25.git

# Verify it was added correctly
git remote -v
```

#### 6. Rename Main Branch (if necessary)

```bash
git branch -M main
```

#### 7. Upload Code

```bash
# First time (sets upstream)
git push -u origin main

# In the future, you only need:
git push
```

## Complete Commands (Copy-Paste)

```bash
# 1. Initialize git
git init

# 2. Add files
git add .

# 3. Initial commit
git commit -m "Initial commit: Security lab infrastructure"

# 4. Add remote (REPLACE YOUR_USERNAME)
git remote add origin https://github.com/YOUR_USERNAME/fastandsecure25.git

# 5. Rename branch
git branch -M main

# 6. Upload code
git push -u origin main
```

## Verification

After pushing, verify on GitHub:
- ✅ All files are present
- ✅ README.md displays correctly
- ✅ Directory structure is correct

## Additional Configuration (Optional)

### Configure Git (if first time)

```bash
git config --global user.name "Your Name"
git config --global user.email "your.email@example.com"
```

### Use SSH instead of HTTPS

If you prefer to use SSH:

```bash
# Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "your.email@example.com"

# Add key to ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copy public key
cat ~/.ssh/id_ed25519.pub
# Paste in GitHub: Settings > SSH and GPG keys > New SSH key

# Use SSH URL instead of HTTPS
git remote set-url origin git@github.com:YOUR_USERNAME/fastandsecure25.git
```

### Add Repository Description

On GitHub, you can add:
- **Topics**: `terraform`, `kubernetes`, `aws`, `security`, `vulnerable-apps`, `eks`, `docker`
- **Website**: (optional) If you have online documentation
- **Description**: Security lab infrastructure with Terraform and Kubernetes

## Structure to be Uploaded

```
fastandsecure25/
├── .gitignore
├── README.md
├── GITHUB_SETUP.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       └── vpc/
├── docker-images/
│   ├── vulnerable-web-app/
│   ├── vulnerable-api/
│   ├── vulnerable-database/
│   └── vulnerable-legacy-app/
├── scripts/
│   ├── build-and-push-images.sh
│   ├── deploy-to-cluster.sh
│   ├── monitor-containers.sh
│   └── ...
└── exploitation/
    ├── exploit-web-app.sh
    ├── exploit-api.sh
    └── ...
```

## Troubleshooting

### Error: "remote origin already exists"
```bash
# View current remotes
git remote -v

# Remove and add again
git remote remove origin
git remote add origin https://github.com/YOUR_USERNAME/fastandsecure25.git
```

### Error: "failed to push some refs"
```bash
# If GitHub repository has initial content
git pull origin main --allow-unrelated-histories
git push -u origin main
```

### Authentication error
```bash
# GitHub no longer accepts passwords, use Personal Access Token
# Create token at: GitHub > Settings > Developer settings > Personal access tokens
# Use the token as password when git asks for it
```

## Next Steps After Uploading

1. ✅ Add badges to README (optional)
2. ✅ Configure GitHub Actions for CI/CD (optional)
3. ✅ Add Issues templates (optional)
4. ✅ Configure branch protection (if necessary)
