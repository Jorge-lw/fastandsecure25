#!/bin/bash

# Script to build and push vulnerable images to ECR

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Get variables from Terraform outputs
if [ -z "$AWS_REGION" ]; then
    echo -e "${YELLOW}AWS_REGION is not defined. Using us-east-1 as default${NC}"
    AWS_REGION="us-east-1"
fi

if [ -z "$AWS_ACCOUNT_ID" ]; then
    echo -e "${YELLOW}Getting AWS Account ID...${NC}"
    AWS_ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
fi

echo -e "${GREEN}Configuring Docker for ECR...${NC}"
aws ecr get-login-password --region $AWS_REGION | docker login --username AWS --password-stdin $AWS_ACCOUNT_ID.dkr.ecr.$AWS_REGION.amazonaws.com

# Base directory for images
IMAGES_DIR="docker-images"

# List of images to build
IMAGES=(
    "vulnerable-web-app"
    "vulnerable-api"
    "vulnerable-database"
    "vulnerable-legacy-app"
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
