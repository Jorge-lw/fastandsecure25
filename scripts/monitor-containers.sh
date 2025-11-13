#!/bin/bash

# Script to make periodic requests to vulnerable containers
# Runs in background and generates logs

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
NAMESPACE="${NAMESPACE:-vulnerable-apps}"
INTERVAL="${INTERVAL:-30}"  # Seconds between requests
LOG_FILE="${LOG_FILE:-/tmp/container-monitor.log}"
PID_FILE="${PID_FILE:-/tmp/container-monitor.pid}"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Function to make HTTP request
make_request() {
    local URL=$1
    local NAME=$2
    local METHOD=${3:-GET}
    local DATA=${4:-}
    
    if [ "$METHOD" = "GET" ]; then
        RESPONSE=$(curl -s -w "\n%{http_code}" -m 5 "$URL" 2>&1 || echo "ERROR")
    else
        RESPONSE=$(curl -s -w "\n%{http_code}" -m 5 -X "$METHOD" -H "Content-Type: application/json" -d "$DATA" "$URL" 2>&1 || echo "ERROR")
    fi
    
    HTTP_CODE=$(echo "$RESPONSE" | tail -1)
    BODY=$(echo "$RESPONSE" | sed '$d')
    
    if [ "$HTTP_CODE" = "200" ] || [ "$HTTP_CODE" = "201" ]; then
        log "${GREEN}✓${NC} $NAME: HTTP $HTTP_CODE"
        return 0
    else
        log "${RED}✗${NC} $NAME: HTTP $HTTP_CODE"
        return 1
    fi
}

# Function to verify pod and set up port-forward
setup_port_forward() {
    local SERVICE=$1
    local PORT=$2
    local PF_PID_FILE="/tmp/pf-$SERVICE.pid"
    
    # Check if port-forward is already running
    if [ -f "$PF_PID_FILE" ]; then
        OLD_PID=$(cat "$PF_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            return 0  # Already running
        fi
    fi
    
    # Start port-forward in background
    kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" "$PORT:$PORT" > /dev/null 2>&1 &
    PF_PID=$!
    echo $PF_PID > "$PF_PID_FILE"
    sleep 2  # Wait for port-forward to establish
    
    if ps -p "$PF_PID" > /dev/null 2>&1; then
        log "${GREEN}✓${NC} Port-forward for $SERVICE started (PID: $PF_PID)"
        return 0
    else
        log "${RED}✗${NC} Error starting port-forward for $SERVICE"
        return 1
    fi
}

# Main monitoring function
monitor_containers() {
    log "${BLUE}=== Starting container monitoring ===${NC}"
    log "Namespace: $NAMESPACE"
    log "Interval: $INTERVAL seconds"
    log "Log file: $LOG_FILE"
    
    # Verify kubectl is configured
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log "${RED}✗ Error: kubectl is not configured correctly${NC}"
        exit 1
    fi
    
    # Verify namespace exists
    if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
        log "${RED}✗ Error: Namespace $NAMESPACE does not exist${NC}"
        exit 1
    fi
    
    # Get available services
    SERVICES=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$SERVICES" ]; then
        log "${YELLOW}⚠ No services found in namespace $NAMESPACE${NC}"
        exit 1
    fi
    
    log "${GREEN}Services found: $SERVICES${NC}"
    
    # Set up port-forwards for each service
    for SERVICE in $SERVICES; do
        case $SERVICE in
            vulnerable-web-app)
                setup_port_forward "$SERVICE" 3000
                ;;
            vulnerable-api)
                setup_port_forward "$SERVICE" 5000
                ;;
            vulnerable-database)
                setup_port_forward "$SERVICE" 3306
                ;;
            vulnerable-legacy-app)
                setup_port_forward "$SERVICE" 8080
                ;;
        esac
    done
    
    # Main monitoring loop
    while true; do
        log "${YELLOW}--- Monitoring cycle ---${NC}"
        
        # Check pod status
        PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        POD_COUNT=$(echo $PODS | wc -w)
        log "Active pods: $POD_COUNT"
        
        # Make requests to each service
        for SERVICE in $SERVICES; do
            case $SERVICE in
                vulnerable-web-app)
                    if setup_port_forward "$SERVICE" 3000; then
                        make_request "http://localhost:3000/debug" "vulnerable-web-app (debug)"
                        make_request "http://localhost:3000/search?q=test" "vulnerable-web-app (search)"
                    fi
                    ;;
                vulnerable-api)
                    if setup_port_forward "$SERVICE" 5000; then
                        make_request "http://localhost:5000/env" "vulnerable-api (env)"
                        make_request "http://localhost:5000/ping?host=localhost" "vulnerable-api (ping)"
                    fi
                    ;;
                vulnerable-database)
                    if setup_port_forward "$SERVICE" 3306; then
                        # For MySQL, try connection
                        timeout 2 mysql -h localhost -P 3306 -u root -proot123 -e "SELECT 1" > /dev/null 2>&1 && \
                            log "${GREEN}✓${NC} vulnerable-database: Connection successful" || \
                            log "${RED}✗${NC} vulnerable-database: Connection error"
                    fi
                    ;;
                vulnerable-legacy-app)
                    if setup_port_forward "$SERVICE" 8080; then
                        make_request "http://localhost:8080" "vulnerable-legacy-app"
                    fi
                    ;;
            esac
        done
        
        # Wait before next cycle
        sleep "$INTERVAL"
    done
}

# Function to stop monitoring
stop_monitoring() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" 2>/dev/null
            log "Monitoring stopped (PID: $PID)"
        fi
        rm -f "$PID_FILE"
    fi
    
    # Stop all port-forwards
    for PF_FILE in /tmp/pf-*.pid; do
        if [ -f "$PF_FILE" ]; then
            PF_PID=$(cat "$PF_FILE")
            kill "$PF_PID" 2>/dev/null || true
            rm -f "$PF_FILE"
        fi
    done
    
    log "All port-forwards stopped"
}

# Signal handling
trap 'stop_monitoring; exit 0' SIGTERM SIGINT

# Check arguments
case "${1:-start}" in
    start)
        # Check if already running
        if [ -f "$PID_FILE" ]; then
            OLD_PID=$(cat "$PID_FILE")
            if ps -p "$OLD_PID" > /dev/null 2>&1; then
                echo -e "${YELLOW}Monitoring is already running (PID: $OLD_PID)${NC}"
                echo "Use '$0 stop' to stop it"
                exit 1
            fi
        fi
        
        # Start in background
        echo -e "${BLUE}Starting monitoring in background...${NC}"
        echo "Log file: $LOG_FILE"
        echo "PID file: $PID_FILE"
        echo "To stop: $0 stop"
        echo "To view logs: tail -f $LOG_FILE"
        
        monitor_containers > "$LOG_FILE" 2>&1 &
        MONITOR_PID=$!
        echo $MONITOR_PID > "$PID_FILE"
        
        sleep 2
        if ps -p "$MONITOR_PID" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Monitoring started (PID: $MONITOR_PID)${NC}"
        else
            echo -e "${RED}✗ Error starting monitoring${NC}"
            exit 1
        fi
        ;;
    stop)
        stop_monitoring
        ;;
    status)
        if [ -f "$PID_FILE" ]; then
            PID=$(cat "$PID_FILE")
            if ps -p "$PID" > /dev/null 2>&1; then
                echo -e "${GREEN}✓ Monitoring running (PID: $PID)${NC}"
                echo "Log file: $LOG_FILE"
                tail -20 "$LOG_FILE" 2>/dev/null || echo "No logs yet"
            else
                echo -e "${RED}✗ Monitoring is not running${NC}"
                rm -f "$PID_FILE"
            fi
        else
            echo -e "${RED}✗ Monitoring is not running${NC}"
        fi
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "No log file"
        fi
        ;;
    *)
        echo "Usage: $0 {start|stop|status|logs}"
        echo ""
        echo "Environment variables:"
        echo "  NAMESPACE  - Kubernetes namespace (default: vulnerable-apps)"
        echo "  INTERVAL   - Interval between requests in seconds (default: 30)"
        echo "  LOG_FILE   - Log file (default: /tmp/container-monitor.log)"
        echo ""
        echo "Examples:"
        echo "  $0 start              # Start monitoring"
        echo "  INTERVAL=60 $0 start  # Start with 60 second interval"
        echo "  $0 stop               # Stop monitoring"
        echo "  $0 status             # View status"
        echo "  $0 logs               # View logs in real time"
        exit 1
        ;;
esac
