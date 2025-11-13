#!/bin/bash

# Script to initialize git and prepare repository for GitHub

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Git Configuration for GitHub ===${NC}\n"

# Verify git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git is not installed${NC}"
    exit 1
fi

# Check if git repository already exists
if [ -d ".git" ]; then
    echo -e "${YELLOW}Git repository already exists${NC}"
    read -p "Continue anyway? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Initialize git repository if it doesn't exist
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}[1] Initializing git repository...${NC}"
    git init
    echo -e "${GREEN}✓ Repository initialized${NC}"
fi

# Check .gitignore
if [ ! -f ".gitignore" ]; then
    echo -e "${YELLOW}[2] Creating .gitignore...${NC}"
    # .gitignore should already exist, but just in case
    echo -e "${RED}⚠ .gitignore not found${NC}"
else
    echo -e "${GREEN}✓ .gitignore found${NC}"
fi

# Add all files
echo -e "\n${YELLOW}[3] Adding files to staging...${NC}"
git add .

# Check if there are changes
if git diff --cached --quiet; then
    echo -e "${YELLOW}⚠ No changes to commit${NC}"
else
    echo -e "${GREEN}✓ Files added${NC}"
    
    # Create initial commit
    echo -e "\n${YELLOW}[4] Creating initial commit...${NC}"
    read -p "Commit message (default: 'Initial commit'): " COMMIT_MSG
    COMMIT_MSG=${COMMIT_MSG:-"Initial commit"}
    
    git commit -m "$COMMIT_MSG"
    echo -e "${GREEN}✓ Commit created${NC}"
fi

# Information about next steps
echo -e "\n${BLUE}=== Next Steps ===${NC}"
echo -e "${YELLOW}1. Create a repository on GitHub:${NC}"
echo -e "   - Go to https://github.com/new"
echo -e "   - Repository name: fastandsecure25 (or your preferred name)"
echo -e "   - Description: Security lab infrastructure with Terraform and Kubernetes"
echo -e "   - Visibility: Private or Public (as you prefer)"
echo -e "   - ${RED}DO NOT${NC} initialize with README, .gitignore or license"
echo ""
echo -e "${YELLOW}2. Connect local repository with GitHub:${NC}"
echo -e "   ${GREEN}git remote add origin https://github.com/YOUR_USERNAME/fastandsecure25.git${NC}"
echo -e "   (Replace YOUR_USERNAME with your GitHub username)"
echo ""
echo -e "${YELLOW}3. Push code:${NC}"
echo -e "   ${GREEN}git branch -M main${NC}"
echo -e "   ${GREEN}git push -u origin main${NC}"
echo ""
echo -e "${BLUE}Or run these commands after creating the repo:${NC}"
echo -e "${GREEN}git remote add origin https://github.com/YOUR_USERNAME/fastandsecure25.git${NC}"
echo -e "${GREEN}git branch -M main${NC}"
echo -e "${GREEN}git push -u origin main${NC}"
