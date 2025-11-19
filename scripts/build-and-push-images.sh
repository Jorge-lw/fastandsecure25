#!/bin/bash

# Script to build and push vulnerable images to ECR

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Use AWS profile if available
AWS_PROFILE="${AWS_PROFILE:-}"
AWS_PROFILE_FLAG=""
if [ -n "$AWS_PROFILE" ]; then
    AWS_PROFILE_FLAG="--profile $AWS_PROFILE"
    export AWS_PROFILE
fi

# Get variables from Terraform outputs
if [ -z "${AWS_REGION:-}" ]; then
    echo -e "${YELLOW}AWS_REGION is not defined. Trying to get from terraform...${NC}"
    if [ -f "terraform/terraform.tfstate" ]; then
        AWS_REGION=$(cd terraform && terraform output -raw aws_region 2>/dev/null || echo "eu-central-1")
    else
        AWS_REGION="eu-central-1"
    fi
    echo -e "${YELLOW}Using AWS_REGION: $AWS_REGION${NC}"
fi

if [ -z "${AWS_ACCOUNT_ID:-}" ]; then
    echo -e "${YELLOW}Getting AWS Account ID...${NC}"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity $AWS_PROFILE_FLAG --query Account --output text)
fi

export AWS_REGION
export AWS_ACCOUNT_ID

echo -e "${GREEN}Configuring Docker for ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION $AWS_PROFILE_FLAG | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Base directory for images
IMAGES_DIR="docker-images"

# List of images to build
IMAGES=(
    "vulnerable-web-app"
    "vulnerable-api"
    "vulnerable-database"
    "vulnerable-legacy-app"
    "blog-app"
    "ecommerce-app"
    "voting-app"
)

echo -e "${GREEN}Starting image build and push...${NC}"

for IMAGE in "${IMAGES[@]}"; do
    echo -e "\n${YELLOW}Processing: $IMAGE${NC}"
    
    IMAGE_DIR="$IMAGES_DIR/$IMAGE"
    
    if [ ! -d "$IMAGE_DIR" ]; then
        echo -e "${RED}Error: Directory $IMAGE_DIR does not exist${NC}"
        continue
    fi
    
    ECR_REPO="$AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE"
    
    echo -e "${GREEN}Building image: $IMAGE${NC}"
    docker build -t $IMAGE:latest $IMAGE_DIR/
    
    echo -e "${GREEN}Tagging image for ECR${NC}"
    docker tag $IMAGE:latest $ECR_REPO:latest
    
    echo -e "${GREEN}Pushing image to ECR: $ECR_REPO${NC}"
    docker push $ECR_REPO:latest
    
    echo -e "${GREEN}✓ Image $IMAGE pushed successfully${NC}"
done

echo -e "\n${GREEN}✓ All images have been built and pushed to ECR${NC}"
echo -e "${YELLOW}ECR repositories:${NC}"
for IMAGE in "${IMAGES[@]}"; do
    echo "  - $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com/$IMAGE:latest"
done
