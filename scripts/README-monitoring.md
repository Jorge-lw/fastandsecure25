# Monitoring and Configuration Scripts

## fix-kubectl-config.sh

Script to fix kubectl configuration issues, especially the error:
```
error: exec plugin: invalid apiVersion "client.authentication.k8s.io/v1alpha1"
```

**Usage:**
```bash
./scripts/fix-kubectl-config.sh
```

This script:
- Updates kubectl configuration
- Replaces old API versions (v1alpha1) with v1beta1
- Verifies cluster access works

## monitor-containers.sh

Script to monitor and make periodic requests to vulnerable containers in the Kubernetes cluster.

### Features

- ✅ Runs in background
- ✅ Makes periodic requests to all vulnerable services
- ✅ Manages port-forwards automatically
- ✅ Generates detailed logs
- ✅ Handles errors and reconnections
- ✅ Easy to start/stop/check

### Basic Usage

```bash
# Start monitoring (in background)
./scripts/monitor-containers.sh start

# Check status
./scripts/monitor-containers.sh status

# View logs in real time
./scripts/monitor-containers.sh logs

# Stop monitoring
./scripts/monitor-containers.sh stop
```

### Configuration with Environment Variables

```bash
# Change interval (default: 30 seconds)
INTERVAL=60 ./scripts/monitor-containers.sh start

# Change namespace
NAMESPACE=other-namespace ./scripts/monitor-containers.sh start

# Change log file
LOG_FILE=/var/log/monitor.log ./scripts/monitor-containers.sh start
```

### Monitored Services

The script automatically monitors:

1. **vulnerable-web-app** (port 3000)
   - `/debug` - Debug information
   - `/search?q=test` - Search

2. **vulnerable-api** (port 5000)
   - `/env` - Environment variables
   - `/ping?host=localhost` - Ping

3. **vulnerable-database** (port 3306)
   - MySQL connection with default credentials

4. **vulnerable-legacy-app** (port 8080)
   - GET request to root

### Complete Example

```bash
# 1. Connect to bastion
ssh -p 22222 -i ~/.ssh/bastion_key ubuntu@<BASTION_IP>

# 2. Configure kubectl (if necessary)
export AWS_REGION=eu-central-1
export CLUSTER_NAME=lab-cluster
./scripts/fix-kubectl-config.sh

# 3. Verify access
kubectl get pods -n vulnerable-apps

# 4. Start monitoring
cd ~/scripts  # or wherever scripts are
./monitor-containers.sh start

# 5. View logs
./monitor-containers.sh logs

# 6. Check status
./monitor-containers.sh status

# 7. Stop when done
./monitor-containers.sh stop
```

### Generated Files

- `/tmp/container-monitor.log` - Main log
- `/tmp/container-monitor.pid` - Process PID
- `/tmp/pf-*.pid` - Port-forward PIDs

### Troubleshooting

**Error: kubectl is not configured**
```bash
./scripts/fix-kubectl-config.sh
```

**Error: Namespace does not exist**
```bash
# Verify namespace
kubectl get namespaces

# Create if necessary
kubectl create namespace vulnerable-apps
```

**Port-forwards not working**
```bash
# Verify services exist
kubectl get services -n vulnerable-apps

# Verify pods are running
kubectl get pods -n vulnerable-apps
```

**Script stops**
```bash
# View logs for diagnosis
tail -100 /tmp/container-monitor.log

# Restart
./scripts/monitor-containers.sh stop
./scripts/monitor-containers.sh start
```

### Customization

You can modify the script to:
- Add more endpoints to monitor
- Change request types
- Add more checks
- Integrate with alerting systems

### Example Log Output

```
[2024-01-15 10:30:00] === Starting container monitoring ===
[2024-01-15 10:30:00] Namespace: vulnerable-apps
[2024-01-15 10:30:00] Interval: 30 seconds
[2024-01-15 10:30:02] ✓ Port-forward for vulnerable-web-app started (PID: 12345)
[2024-01-15 10:30:05] ✓ vulnerable-web-app (debug): HTTP 200
[2024-01-15 10:30:05] ✓ vulnerable-web-app (search): HTTP 200
[2024-01-15 10:30:10] ✓ vulnerable-api (env): HTTP 200
[2024-01-15 10:30:15] --- Monitoring cycle ---
[2024-01-15 10:30:15] Active pods: 4
```
