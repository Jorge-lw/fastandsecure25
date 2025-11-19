#!/bin/bash

# Script to generate legitimate traffic from local machine to LoadBalancer URLs
# Simulates normal user behavior

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

INTENSITY="${1:-medium}"  # low, medium, high

# Get LoadBalancer URLs from kubectl
export AWS_PROFILE="${AWS_PROFILE:-Admin-Forti}" 2>/dev/null || true

WEB_URL=$(kubectl get svc -n vulnerable-apps vulnerable-web-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
API_URL=$(kubectl get svc -n vulnerable-apps vulnerable-api -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
LEGACY_URL=$(kubectl get svc -n vulnerable-apps vulnerable-legacy-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
BLOG_URL=$(kubectl get svc -n vulnerable-apps blog-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
ECOM_URL=$(kubectl get svc -n vulnerable-apps ecommerce-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")
VOTING_URL=$(kubectl get svc -n vulnerable-apps voting-app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || echo "")

# Use defaults if not found
WEB_URL="${WEB_URL:-af27f94ff0dd5475abf27381998b12fc-2136651876.eu-central-1.elb.amazonaws.com}"
API_URL="${API_URL:-a98f78674a87c490fb96ee76715e9518-288516544.eu-central-1.elb.amazonaws.com}"
LEGACY_URL="${LEGACY_URL:-a88e2ebd02375423d87211a4aaef867d-356569397.eu-central-1.elb.amazonaws.com}"
BLOG_URL="${BLOG_URL:-a8e30c27f440045a190fb51d1fd10062-1007446821.eu-central-1.elb.amazonaws.com}"
ECOM_URL="${ECOM_URL:-ac9c51258fda44a149fb400ec24e8d02-1766768.eu-central-1.elb.amazonaws.com}"
VOTING_URL="${VOTING_URL:-ad8512b5692d9457da88ce9329cd97c6-1574672033.eu-central-1.elb.amazonaws.com}"

# Set delays based on intensity
case "$INTENSITY" in
    low)
        DELAY=10
        REQUESTS_PER_CYCLE=5
        ;;
    medium)
        DELAY=5
        REQUESTS_PER_CYCLE=10
        ;;
    high)
        DELAY=2
        REQUESTS_PER_CYCLE=20
        ;;
    *)
        DELAY=5
        REQUESTS_PER_CYCLE=10
        ;;
esac

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Legitimate Traffic Generator (Local Machine)            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

echo -e "${YELLOW}Intensity: $INTENSITY${NC}"
echo -e "${YELLOW}Delay between cycles: ${DELAY}s${NC}"
echo -e "${YELLOW}Requests per cycle: $REQUESTS_PER_CYCLE${NC}\n"

echo -e "${YELLOW}Target URLs:${NC}"
echo -e "  Web App:     http://${WEB_URL}:3000"
echo -e "  API:         http://${API_URL}:5000"
echo -e "  Legacy App:  http://${LEGACY_URL}:8080"
echo -e "  Blog App:    http://${BLOG_URL}:8081"
echo -e "  E-commerce:  http://${ECOM_URL}:8082"
echo -e "  Voting App:  http://${VOTING_URL}:8080"
echo ""

CYCLE=0

# Function to make legitimate requests
make_request() {
    local url=$1
    local method=${2:-GET}
    
    if [ "$method" = "GET" ]; then
        curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" 2>/dev/null || echo "000"
    else
        curl -s -o /dev/null -w "%{http_code}" --max-time 5 -X "$method" "$url" 2>/dev/null || echo "000"
    fi
}

# Main loop
while true; do
    CYCLE=$((CYCLE + 1))
    echo -e "${BLUE}[Cycle $CYCLE] Generating legitimate traffic...${NC}"
    
    REQUEST_COUNT=0
    
    # Vulnerable Web App
    if [ -n "$WEB_URL" ]; then
        make_request "http://${WEB_URL}:3000/" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
        make_request "http://${WEB_URL}:3000/products" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
        make_request "http://${WEB_URL}:3000/about" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
    fi
    
    # Vulnerable API
    if [ -n "$API_URL" ]; then
        make_request "http://${API_URL}:5000/health" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
        make_request "http://${API_URL}:5000/api/users" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
        make_request "http://${API_URL}:5000/api/products" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
    fi
    
    # Legacy App
    if [ -n "$LEGACY_URL" ]; then
        make_request "http://${LEGACY_URL}:8080/" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
    fi
    
    # Blog App
    if [ -n "$BLOG_URL" ]; then
        make_request "http://${BLOG_URL}:8081/" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
        make_request "http://${BLOG_URL}:8081/posts" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
    fi
    
    # E-commerce App
    if [ -n "$ECOM_URL" ]; then
        make_request "http://${ECOM_URL}:8082/" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
        make_request "http://${ECOM_URL}:8082/products" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
    fi
    
    # Voting App
    if [ -n "$VOTING_URL" ]; then
        make_request "http://${VOTING_URL}:8080/" > /dev/null && REQUEST_COUNT=$((REQUEST_COUNT + 1))
    fi
    
    echo -e "${GREEN}✓ Cycle $CYCLE completed ($REQUEST_COUNT requests)${NC}"
    sleep $DELAY
done

