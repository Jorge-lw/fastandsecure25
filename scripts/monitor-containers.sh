#!/bin/bash

# Script para hacer peticiones periódicas a los contenedores vulnerables
# Se ejecuta en background y genera logs

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuración
NAMESPACE="${NAMESPACE:-vulnerable-apps}"
INTERVAL="${INTERVAL:-30}"  # Segundos entre peticiones
LOG_FILE="${LOG_FILE:-/tmp/container-monitor.log}"
PID_FILE="${PID_FILE:-/tmp/container-monitor.pid}"

# Función para logging
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

# Función para hacer petición HTTP
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

# Función para verificar pod y hacer port-forward
setup_port_forward() {
    local SERVICE=$1
    local PORT=$2
    local PF_PID_FILE="/tmp/pf-$SERVICE.pid"
    
    # Verificar si el port-forward ya está corriendo
    if [ -f "$PF_PID_FILE" ]; then
        OLD_PID=$(cat "$PF_PID_FILE")
        if ps -p "$OLD_PID" > /dev/null 2>&1; then
            return 0  # Ya está corriendo
        fi
    fi
    
    # Iniciar port-forward en background
    kubectl port-forward -n "$NAMESPACE" "svc/$SERVICE" "$PORT:$PORT" > /dev/null 2>&1 &
    PF_PID=$!
    echo $PF_PID > "$PF_PID_FILE"
    sleep 2  # Esperar a que el port-forward se establezca
    
    if ps -p "$PF_PID" > /dev/null 2>&1; then
        log "${GREEN}✓${NC} Port-forward para $SERVICE iniciado (PID: $PF_PID)"
        return 0
    else
        log "${RED}✗${NC} Error iniciando port-forward para $SERVICE"
        return 1
    fi
}

# Función principal de monitoreo
monitor_containers() {
    log "${BLUE}=== Iniciando monitoreo de contenedores ===${NC}"
    log "Namespace: $NAMESPACE"
    log "Intervalo: $INTERVAL segundos"
    log "Log file: $LOG_FILE"
    
    # Verificar que kubectl está configurado
    if ! kubectl cluster-info > /dev/null 2>&1; then
        log "${RED}✗ Error: kubectl no está configurado correctamente${NC}"
        exit 1
    fi
    
    # Verificar que el namespace existe
    if ! kubectl get namespace "$NAMESPACE" > /dev/null 2>&1; then
        log "${RED}✗ Error: Namespace $NAMESPACE no existe${NC}"
        exit 1
    fi
    
    # Obtener servicios disponibles
    SERVICES=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
    
    if [ -z "$SERVICES" ]; then
        log "${YELLOW}⚠ No se encontraron servicios en el namespace $NAMESPACE${NC}"
        exit 1
    fi
    
    log "${GREEN}Servicios encontrados: $SERVICES${NC}"
    
    # Configurar port-forwards para cada servicio
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
    
    # Loop principal de monitoreo
    while true; do
        log "${YELLOW}--- Ciclo de monitoreo ---${NC}"
        
        # Verificar estado de los pods
        PODS=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")
        POD_COUNT=$(echo $PODS | wc -w)
        log "Pods activos: $POD_COUNT"
        
        # Hacer peticiones a cada servicio
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
                        # Para MySQL, intentar conexión
                        timeout 2 mysql -h localhost -P 3306 -u root -proot123 -e "SELECT 1" > /dev/null 2>&1 && \
                            log "${GREEN}✓${NC} vulnerable-database: Conexión exitosa" || \
                            log "${RED}✗${NC} vulnerable-database: Error de conexión"
                    fi
                    ;;
                vulnerable-legacy-app)
                    if setup_port_forward "$SERVICE" 8080; then
                        make_request "http://localhost:8080" "vulnerable-legacy-app"
                    fi
                    ;;
            esac
        done
        
        # Esperar antes del siguiente ciclo
        sleep "$INTERVAL"
    done
}

# Función para detener el monitoreo
stop_monitoring() {
    if [ -f "$PID_FILE" ]; then
        PID=$(cat "$PID_FILE")
        if ps -p "$PID" > /dev/null 2>&1; then
            kill "$PID" 2>/dev/null
            log "Monitoreo detenido (PID: $PID)"
        fi
        rm -f "$PID_FILE"
    fi
    
    # Detener todos los port-forwards
    for PF_FILE in /tmp/pf-*.pid; do
        if [ -f "$PF_FILE" ]; then
            PF_PID=$(cat "$PF_FILE")
            kill "$PF_PID" 2>/dev/null || true
            rm -f "$PF_FILE"
        fi
    done
    
    log "Todos los port-forwards detenidos"
}

# Manejo de señales
trap 'stop_monitoring; exit 0' SIGTERM SIGINT

# Verificar argumentos
case "${1:-start}" in
    start)
        # Verificar si ya está corriendo
        if [ -f "$PID_FILE" ]; then
            OLD_PID=$(cat "$PID_FILE")
            if ps -p "$OLD_PID" > /dev/null 2>&1; then
                echo -e "${YELLOW}El monitoreo ya está corriendo (PID: $OLD_PID)${NC}"
                echo "Usa '$0 stop' para detenerlo"
                exit 1
            fi
        fi
        
        # Iniciar en background
        echo -e "${BLUE}Iniciando monitoreo en background...${NC}"
        echo "Log file: $LOG_FILE"
        echo "PID file: $PID_FILE"
        echo "Para detener: $0 stop"
        echo "Para ver logs: tail -f $LOG_FILE"
        
        monitor_containers > "$LOG_FILE" 2>&1 &
        MONITOR_PID=$!
        echo $MONITOR_PID > "$PID_FILE"
        
        sleep 2
        if ps -p "$MONITOR_PID" > /dev/null 2>&1; then
            echo -e "${GREEN}✓ Monitoreo iniciado (PID: $MONITOR_PID)${NC}"
        else
            echo -e "${RED}✗ Error iniciando monitoreo${NC}"
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
                echo -e "${GREEN}✓ Monitoreo corriendo (PID: $PID)${NC}"
                echo "Log file: $LOG_FILE"
                tail -20 "$LOG_FILE" 2>/dev/null || echo "No hay logs aún"
            else
                echo -e "${RED}✗ Monitoreo no está corriendo${NC}"
                rm -f "$PID_FILE"
            fi
        else
            echo -e "${RED}✗ Monitoreo no está corriendo${NC}"
        fi
        ;;
    logs)
        if [ -f "$LOG_FILE" ]; then
            tail -f "$LOG_FILE"
        else
            echo "No hay archivo de log"
        fi
        ;;
    *)
        echo "Uso: $0 {start|stop|status|logs}"
        echo ""
        echo "Variables de entorno:"
        echo "  NAMESPACE  - Namespace de Kubernetes (default: vulnerable-apps)"
        echo "  INTERVAL   - Intervalo entre peticiones en segundos (default: 30)"
        echo "  LOG_FILE   - Archivo de log (default: /tmp/container-monitor.log)"
        echo ""
        echo "Ejemplos:"
        echo "  $0 start              # Iniciar monitoreo"
        echo "  INTERVAL=60 $0 start  # Iniciar con intervalo de 60 segundos"
        echo "  $0 stop               # Detener monitoreo"
        echo "  $0 status             # Ver estado"
        echo "  $0 logs               # Ver logs en tiempo real"
        exit 1
        ;;
esac

