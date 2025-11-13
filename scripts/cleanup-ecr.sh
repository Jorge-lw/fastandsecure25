#!/bin/bash

# Script to clean ECR repositories before running terraform destroy

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}Cleaning ECR repositories...${NC}"

# Get Terraform information
cd terraform 2>/dev/null || { echo "Error: Run this script from the project root directory"; exit 1; }

if [ ! -f "terraform.tfstate" ]; then
    echo -e "${RED}terraform.tfstate not found. Repositories may not exist.${NC}"
    exit 0
fi

AWS_REGION=$(terraform output -raw aws_region 2>/dev/null || echo "us-east-1")
AWS_ACCOUNT_ID=$(terraform output -raw aws_account_id 2>/dev/null || echo "")

if [ -z "$AWS_ACCOUNT_ID" ]; then
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text 2>/dev/null || echo "")
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${RED}Could not get AWS Account ID${NC}"
    exit 1
fi

echo -e "${GREEN}Region: $AWS_REGION${NC}"
echo -e "${GREEN}Account ID: $AWS_ACCOUNT_ID${NC}"

# List of repositories (can get from terraform output or hardcode)
REPOS=(
    "vulnerable-web-app"
    "vulnerable-api"
    "vulnerable-database"
    "vulnerable-legacy-app"
)

for REPO in "${REPOS[@]}"; do
    echo -e "\n${YELLOW}Processing repository: $REPO${NC}"
    
    # Check if repository exists
    if aws ecr describe-repositories --repository-names "$REPO" --region "$AWS_REGION" &>/dev/null; then
        # Get all images
        IMAGE_COUNT=$(aws ecr list-images \
            --repository-name "$REPO" \
            --region "$AWS_REGION" \
            --query 'length(imageIds)' \
            --output text 2>/dev/null || echo "0")
        
        if [ "$IMAGE_COUNT" -gt 0 ]; then
            echo -e "${YELLOW}Deleting $IMAGE_COUNT image(s) from $REPO...${NC}"
            
            # Get all images and delete them
            IMAGES_JSON=$(aws ecr list-images \
                --repository-name "$REPO" \
                --region "$AWS_REGION" \
                --query 'imageIds[*]' \
                --output json 2>/dev/null || echo "[]")
            
            if [ "$IMAGES_JSON" != "[]" ] && [ -n "$IMAGES_JSON" ]; then
                # Delete using batch-delete-image
                echo "$IMAGES_JSON" | aws ecr batch-delete-image \
                    --repository-name "$REPO" \
                    --region "$AWS_REGION" \
                    --image-ids file:///dev/stdin \
                    2>&1 | grep -v "does not exist" || true
                
                # Verify deletion
                sleep 2
                REMAINING=$(aws ecr list-images \
                    --repository-name "$REPO" \
                    --region "$AWS_REGION" \
                    --query 'length(imageIds)' \
                    --output text 2>/dev/null || echo "0")
                
                if [ "$REMAINING" -eq "0" ]; then
                    echo -e "${GREEN}✓ All images deleted from $REPO${NC}"
                else
                    echo -e "${YELLOW}⚠ $REMAINING image(s) remaining in $REPO${NC}"
                    # Try to delete repository completely with force
                    echo -e "${YELLOW}Attempting to delete repository with force...${NC}"
                    aws ecr delete-repository \
                        --repository-name "$REPO" \
                        --region "$AWS_REGION" \
                        --force \
                        2>&1 || echo -e "${RED}Could not delete $REPO${NC}"
                fi
            fi
        else
            echo -e "${GREEN}✓ $REPO is already empty${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ $REPO does not exist${NC}"
    fi
done

echo -e "\n${GREEN}✓ ECR cleanup completed${NC}"
echo -e "${YELLOW}You can now run: terraform destroy${NC}"
