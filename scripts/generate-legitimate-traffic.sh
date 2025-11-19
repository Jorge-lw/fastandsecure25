#!/bin/bash

# Script to generate legitimate traffic to all applications
# Simulates normal user behavior

set -euo pipefail

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

NAMESPACE="${1:-vulnerable-apps}"
INTENSITY="${2:-medium}"  # low, medium, high

echo -e "${BLUE}╔══════════════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║        Legitimate Traffic Generator                            ║${NC}"
echo -e "${BLUE}╚══════════════════════════════════════════════════════════════╝${NC}\n"

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

echo -e "${YELLOW}Intensity: $INTENSITY${NC}"
echo -e "${YELLOW}Delay between cycles: ${DELAY}s${NC}"
echo -e "${YELLOW}Requests per cycle: $REQUESTS_PER_CYCLE${NC}\n"

# Function to make legitimate requests
make_request() {
    local url=$1
    local method=${2:-GET}
    local data=${3:-}
    
    if [ "$method" = "POST" ]; then
        curl -s -X POST "$url" \
            -H "Content-Type: application/x-www-form-urlencoded" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            -d "$data" \
            > /dev/null 2>&1
    else
        curl -s "$url" \
            -H "User-Agent: Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36" \
            > /dev/null 2>&1
    fi
}

# Function to generate traffic to voting app
traffic_voting_app() {
    local base_url="http://localhost:8080"
    
    # Legitimate votes
    make_request "$base_url/" "GET"
    sleep 1
    make_request "$base_url/vote" "POST" "question_id=1&vote=yes"
    sleep 1
    make_request "$base_url/vote" "POST" "question_id=1&vote=no"
    sleep 1
    
    # View results
    make_request "$base_url/" "GET"
    sleep 1
    
    # Legitimate comments
    make_request "$base_url/comment" "POST" "comment=This is a great survey!"
    sleep 1
    make_request "$base_url/comment" "POST" "comment=Very interesting topic"
}

# Function to generate traffic to web app (via port-forward)
traffic_web_app() {
    # Check if port-forward exists
    if ! ss -tlnp 2>/dev/null | grep -q ":3000"; then
        return
    fi
    
    local base_url="http://localhost:3000"
    
    # Legitimate requests
    make_request "$base_url/" "GET"
    sleep 0.5
    make_request "$base_url/about" "GET"
    sleep 0.5
    make_request "$base_url/contact" "GET"
    sleep 0.5
    make_request "$base_url/products" "GET"
}

# Function to generate traffic to API (via port-forward)
traffic_api() {
    if ! ss -tlnp 2>/dev/null | grep -q ":5000"; then
        return
    fi
    
    local base_url="http://localhost:5000"
    
    # Legitimate API calls
    make_request "$base_url/health" "GET"
    sleep 0.5
    make_request "$base_url/api/users" "GET"
    sleep 0.5
    make_request "$base_url/api/products" "GET"
}

# Function to generate traffic to legacy app (via port-forward)
traffic_legacy_app() {
    if ! ss -tlnp 2>/dev/null | grep -q ":8083"; then
        return
    fi
    
    local base_url="http://localhost:8083"
    
    # Legitimate requests
    make_request "$base_url/" "GET"
    sleep 0.5
    make_request "$base_url/index.html" "GET"
}

# Function to generate traffic to additional apps
traffic_additional_apps() {
    # Blog app (via port-forward)
    if ss -tlnp 2>/dev/null | grep -q ":8081"; then
        make_request "http://localhost:8081/" "GET"
        sleep 0.5
        make_request "http://localhost:8081/posts" "GET"
        sleep 0.5
        make_request "http://localhost:8081/post/1" "GET"
        sleep 0.5
        make_request "http://localhost:8081/about" "GET"
    fi
    
    # E-commerce app (via port-forward)
    if ss -tlnp 2>/dev/null | grep -q ":8082"; then
        make_request "http://localhost:8082/" "GET"
        sleep 0.5
        make_request "http://localhost:8082/products" "GET"
        sleep 0.5
        make_request "http://localhost:8082/product/1" "GET"
        sleep 0.5
        make_request "http://localhost:8082/cart" "GET"
    fi
}

# Main loop
echo -e "${GREEN}Starting legitimate traffic generation...${NC}"
echo -e "${YELLOW}Press Ctrl+C to stop${NC}\n"

CYCLE=0
while true; do
    CYCLE=$((CYCLE + 1))
    echo -e "${BLUE}[Cycle $CYCLE] Generating legitimate traffic...${NC}"
    
    # Generate traffic to all applications
    traffic_voting_app &
    sleep 1
    
    traffic_web_app &
    sleep 1
    
    traffic_api &
    sleep 1
    
    traffic_legacy_app &
    sleep 1
    
    traffic_additional_apps &
    
    # Wait for all background jobs
    wait
    
    echo -e "${GREEN}✓ Cycle $CYCLE completed${NC}"
    sleep $DELAY
done

