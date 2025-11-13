# Scripts de Monitoreo y Configuración

## fix-kubectl-config.sh

Script para arreglar problemas de configuración de kubectl, especialmente el error:
```
error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
```

**Uso:**
```bash
./scripts/fix-kubectl-config.sh
```

Este script:
- Actualiza la configuración de kubectl
- Reemplaza versiones antiguas de la API (v1alpha1) con v1beta1
- Verifica que el acceso al cluster funcione

## monitor-containers.sh

Script para monitorear y hacer peticiones periódicas a los contenedores vulnerables en el cluster Kubernetes.

### Características

- ✅ Ejecuta en background
- ✅ Hace peticiones periódicas a todos los servicios vulnerables
- ✅ Gestiona port-forwards automáticamente
- ✅ Genera logs detallados
- ✅ Maneja errores y reconexiones
- ✅ Fácil de iniciar/detener/verificar

### Uso Básico

```bash
# Iniciar monitoreo (en background)
./scripts/monitor-containers.sh start

# Ver estado
./scripts/monitor-containers.sh status

# Ver logs en tiempo real
./scripts/monitor-containers.sh logs

# Detener monitoreo
./scripts/monitor-containers.sh stop
```

### Configuración con Variables de Entorno

```bash
# Cambiar intervalo (default: 30 segundos)
INTERVAL=60 ./scripts/monitor-containers.sh start

# Cambiar namespace
NAMESPACE=otro-namespace ./scripts/monitor-containers.sh start

# Cambiar archivo de log
LOG_FILE=/var/log/monitor.log ./scripts/monitor-containers.sh start
```

### Servicios Monitoreados

El script monitorea automáticamente:

1. **vulnerable-web-app** (puerto 3000)
   - `/debug` - Información de debug
   - `/search?q=test` - Búsqueda

2. **vulnerable-api** (puerto 5000)
   - `/env` - Variables de entorno
   - `/ping?host=localhost` - Ping

3. **vulnerable-database** (puerto 3306)
   - Conexión MySQL con credenciales por defecto

4. **vulnerable-legacy-app** (puerto 8080)
   - Petición GET a la raíz

### Ejemplo Completo

```bash
# 1. Conectarse al bastión
ssh -p 22222 -i ~/.ssh/bastion_key ubuntu@<BASTION_IP>

# 2. Configurar kubectl (si es necesario)
export AWS_REGION=eu-central-1
export CLUSTER_NAME=lab-cluster
./scripts/fix-kubectl-config.sh

# 3. Verificar acceso
kubectl get pods -n vulnerable-apps

# 4. Iniciar monitoreo
cd ~/scripts  # o donde estén los scripts
./monitor-containers.sh start

# 5. Ver logs
./monitor-containers.sh logs

# 6. Verificar estado
./monitor-containers.sh status

# 7. Detener cuando termines
./monitor-containers.sh stop
```

### Archivos Generados

- `/tmp/container-monitor.log` - Log principal
- `/tmp/container-monitor.pid` - PID del proceso
- `/tmp/pf-*.pid` - PIDs de los port-forwards

### Troubleshooting

**Error: kubectl no está configurado**
```bash
./scripts/fix-kubectl-config.sh
```

**Error: Namespace no existe**
```bash
# Verificar namespace
kubectl get namespaces

# Crear si es necesario
kubectl create namespace vulnerable-apps
```

**Los port-forwards no funcionan**
```bash
# Verificar que los servicios existen
kubectl get services -n vulnerable-apps

# Verificar que los pods están running
kubectl get pods -n vulnerable-apps
```

**El script se detiene**
```bash
# Ver logs para diagnóstico
tail -100 /tmp/container-monitor.log

# Reiniciar
./scripts/monitor-containers.sh stop
./scripts/monitor-containers.sh start
```

### Personalización

Puedes modificar el script para:
- Agregar más endpoints a monitorear
- Cambiar los tipos de peticiones
- Agregar más verificaciones
- Integrar con sistemas de alertas

### Ejemplo de Salida del Log

```
[2024-01-15 10:30:00] === Iniciando monitoreo de contenedores ===
[2024-01-15 10:30:00] Namespace: vulnerable-apps
[2024-01-15 10:30:00] Intervalo: 30 segundos
[2024-01-15 10:30:02] ✓ Port-forward para vulnerable-web-app iniciado (PID: 12345)
[2024-01-15 10:30:05] ✓ vulnerable-web-app (debug): HTTP 200
[2024-01-15 10:30:05] ✓ vulnerable-web-app (search): HTTP 200
[2024-01-15 10:30:10] ✓ vulnerable-api (env): HTTP 200
[2024-01-15 10:30:15] --- Ciclo de monitoreo ---
[2024-01-15 10:30:15] Pods activos: 4
```

