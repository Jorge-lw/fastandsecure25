# Infraestructura de Laboratorio de Seguridad - AWS

Este proyecto despliega una infraestructura básica en AWS con Terraform que incluye:

- **Máquina Bastión**: Instancia EC2 con Ubuntu que expone SSH en el puerto 22222
- **Cluster Kubernetes (EKS)**: Cluster mínimo para laboratorio en una VPC privada
- **ECR Repositories**: Repositorios para imágenes Docker vulnerables
- **Aplicaciones Vulnerables**: Varias aplicaciones Docker con diferentes tipos de vulnerabilidades

## Arquitectura

```
Internet
   │
   ├─> Bastión VPC (10.0.0.0/16)
   │   └─> EC2 Bastión (Puerto 22222)
   │
   └─> VPC Peering
       │
       └─> K8s VPC (10.1.0.0/16)
           └─> EKS Cluster (Privado)
               └─> Aplicaciones Vulnerables
```

## Requisitos Previos

1. **AWS CLI** instalado y configurado
2. **Terraform** >= 1.0
3. **Docker** instalado (para construir imágenes)
4. **kubectl** instalado (para gestionar el cluster)
5. **Clave SSH** para acceder al bastión

## Configuración Inicial

### 1. Generar Clave SSH

```bash
ssh-keygen -t rsa -b 4096 -f ~/.ssh/bastion_key
```

### 2. Configurar Variables de Terraform

Copia el archivo de ejemplo y edítalo:

```bash
cp terraform/terraform.tfvars.example terraform/terraform.tfvars
```

Edita `terraform/terraform.tfvars` y agrega tu clave pública SSH:

```hcl
aws_region = "us-east-1"
bastion_public_key = "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAACAQ... tu-clave-publica"
```

### 3. Desplegar Infraestructura

```bash
cd terraform
terraform init
terraform plan
terraform apply
```

Esto creará:
- 2 VPCs (bastión y Kubernetes)
- VPC Peering entre ellas
- Instancia EC2 bastión con Ubuntu
- Cluster EKS mínimo (1 nodo)
- Repositorios ECR para imágenes vulnerables

### 4. Obtener Información del Despliegue

```bash
terraform output
```

Anota especialmente:
- `bastion_public_ip`: IP pública del bastión
- `eks_cluster_name`: Nombre del cluster
- `aws_region`: Región de AWS

## Construir y Subir Imágenes Docker

Las imágenes vulnerables se encuentran en `docker-images/`:

- **vulnerable-web-app**: Aplicación Node.js con múltiples vulnerabilidades (XSS, SQL Injection, Path Traversal, etc.)
- **vulnerable-api**: API Python/Flask con vulnerabilidades (Deserialización, Command Injection, SSRF, etc.)
- **vulnerable-database**: MySQL con configuración insegura y datos de prueba
- **vulnerable-legacy-app**: Aplicación legacy con vulnerabilidades conocidas

### Construir y Subir Manualmente

```bash
# Configurar variables de entorno
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export AWS_ACCOUNT_ID=$(cd terraform && terraform output -raw aws_account_id)

# Ejecutar script
chmod +x scripts/build-and-push-images.sh
./scripts/build-and-push-images.sh
```

### O Usar el Script Completo

```bash
chmod +x scripts/complete-deployment.sh
./scripts/complete-deployment.sh
```

## Desplegar Aplicaciones en el Cluster

### Desde tu Máquina Local

Primero, configura kubectl:

```bash
export AWS_REGION=$(cd terraform && terraform output -raw aws_region)
export CLUSTER_NAME=$(cd terraform && terraform output -raw eks_cluster_name)
aws eks update-kubeconfig --region $AWS_REGION --name $CLUSTER_NAME
```

Luego despliega:

```bash
chmod +x scripts/deploy-to-cluster.sh
./scripts/deploy-to-cluster.sh
```

### Desde el Bastión

1. Conéctate al bastión:

```bash
ssh -p 22222 -i ~/.ssh/bastion_key ubuntu@<BASTION_IP>
```

2. Configura kubectl:

```bash
aws eks update-kubeconfig --region <REGION> --name lab-cluster
```

3. Despliega las aplicaciones:

```bash
# Desde el bastión, puedes ejecutar los mismos scripts
# o usar kubectl directamente
```

## Acceder a las Aplicaciones

### Desde el Bastión

1. Conéctate al bastión vía SSH (puerto 22222)
2. Configura port-forwarding:

```bash
# Para la aplicación web
kubectl port-forward -n vulnerable-apps svc/vulnerable-web-app 3000:3000

# Para la API
kubectl port-forward -n vulnerable-apps svc/vulnerable-api 5000:5000
```

3. Accede desde tu máquina local usando SSH tunnel:

```bash
ssh -p 22222 -i ~/.ssh/bastion_key -L 3000:localhost:3000 ubuntu@<BASTION_IP>
```

Luego accede a `http://localhost:3000` en tu navegador.

## Tipos de Vulnerabilidades Incluidas

### vulnerable-web-app
- **XSS (Cross-Site Scripting)**: `/search?q=<script>alert(1)</script>`
- **SQL Injection**: `/users?id=1 OR 1=1`
- **Path Traversal**: `/file?name=../../../etc/passwd`
- **Command Injection**: `POST /execute {"command": "ls -la"}`
- **Exposición de Secretos**: `/secrets`, `/debug`
- **Versiones Vulnerables**: Node.js 14, Express 4.16.0

### vulnerable-api
- **Deserialización Insegura**: `POST /unpickle` (pickle)
- **YAML Deserialization**: `POST /yaml`
- **Command Injection**: `/ping?host=localhost; cat /etc/passwd`
- **Path Traversal**: `/read?file=../../../etc/passwd`
- **SSRF**: `/fetch?url=file:///etc/passwd`
- **Autenticación Débil**: Header `X-Token: admin_token_never_change`
- **Exposición de Variables**: `/env`

### vulnerable-database
- **Credenciales Débiles**: root/root123, admin/admin123
- **Sin Encriptación**: Contraseñas en texto plano
- **Privilegios Excesivos**: Usuario 'test' con ALL PRIVILEGES
- **Versión Antigua**: MySQL 5.7 con CVE conocidos
- **Datos Sensibles**: SSN, tarjetas de crédito sin encriptar

### vulnerable-legacy-app
- **Versión Antigua**: Tomcat 8.5 con vulnerabilidades conocidas
- **Java Desactualizado**: OpenJDK 8
- **Sin Security Manager**: Deshabilitado
- **Permisos Excesivos**: Ejecución como root, privileged mode

## Comandos Útiles

### Terraform

```bash
# Ver plan
terraform plan

# Aplicar cambios
terraform apply

# Destruir infraestructura
terraform destroy

# Ver outputs
terraform output
```

### Kubernetes

```bash
# Ver pods
kubectl get pods -n vulnerable-apps

# Ver servicios
kubectl get svc -n vulnerable-apps

# Ver logs
kubectl logs -n vulnerable-apps deployment/vulnerable-web-app

# Ejecutar comando en pod
kubectl exec -it -n vulnerable-apps deployment/vulnerable-web-app -- /bin/sh

# Describir recurso
kubectl describe pod -n vulnerable-apps <pod-name>
```

### Docker/ECR

```bash
# Login a ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com

# Listar repositorios
aws ecr describe-repositories

# Listar imágenes
aws ecr list-images --repository-name vulnerable-web-app
```

## Seguridad y Consideraciones

⚠️ **ADVERTENCIA**: Esta infraestructura está diseñada específicamente para un **laboratorio de seguridad**. **NO** debe usarse en producción.

Las vulnerabilidades incluidas son intencionales y están diseñadas para:
- Práctica de técnicas de seguridad ofensiva
- Pruebas de herramientas de escaneo de vulnerabilidades
- Educación sobre seguridad de aplicaciones
- Entrenamiento de equipos de seguridad

**Nunca despliegues esto en un entorno de producción o con datos reales.**

## Limpieza

Para destruir toda la infraestructura:

```bash
cd terraform
terraform destroy
```

Esto eliminará:
- Todas las instancias EC2
- El cluster EKS
- Los repositorios ECR (las imágenes se eliminarán)
- Las VPCs y recursos de red
- Todos los recursos creados

## Troubleshooting

### Error al conectar al cluster

```bash
# Verificar que el cluster existe
aws eks describe-cluster --name lab-cluster --region <region>

# Actualizar kubeconfig
aws eks update-kubeconfig --region <region> --name lab-cluster --kubeconfig ~/.kube/config
```

### Error al subir imágenes a ECR

```bash
# Verificar permisos IAM
aws sts get-caller-identity

# Verificar login a ECR
aws ecr get-login-password --region <region> | docker login --username AWS --password-stdin <account-id>.dkr.ecr.<region>.amazonaws.com
```

### Pods no inician

```bash
# Ver eventos
kubectl get events -n vulnerable-apps --sort-by='.lastTimestamp'

# Ver logs
kubectl logs -n vulnerable-apps <pod-name>

# Describir pod
kubectl describe pod -n vulnerable-apps <pod-name>
```

## Scripts de Explotación

Este proyecto incluye scripts de explotación para demostrar las vulnerabilidades y realizar movimiento lateral. Ver [exploitation/README.md](exploitation/README.md) para más detalles.

**Scripts disponibles:**
- `exploit-web-app.sh` - Explota vulnerabilidades web (XSS, SQL Injection, etc.)
- `exploit-api.sh` - Explota vulnerabilidades de API (deserialización, SSRF, etc.)
- `exploit-database.sh` - Explota base de datos con credenciales débiles
- `lateral-movement.sh` - Movimiento lateral desde bastión al cluster
- `exploit-k8s.sh` - Explota vulnerabilidades de Kubernetes
- `enumerate-resources.sh` - Enumera recursos del cluster
- `steal-service-account-token.sh` - Roba tokens de service accounts
- `reverse-shell.sh` - Establece reverse shells
- `master-exploit.sh` - Script maestro que ejecuta todo

**Uso rápido:**
```bash
# Desde el bastión
cd ~/exploitation
./master-exploit.sh
```

## Estructura del Proyecto

```
.
├── terraform/
│   ├── main.tf                 # Configuración principal
│   ├── variables.tf            # Variables
│   ├── outputs.tf              # Outputs
│   ├── terraform.tfvars.example # Ejemplo de variables
│   └── modules/
│       └── vpc/                # Módulo VPC
├── docker-images/
│   ├── vulnerable-web-app/    # Aplicación web vulnerable
│   ├── vulnerable-api/        # API vulnerable
│   ├── vulnerable-database/   # Base de datos vulnerable
│   └── vulnerable-legacy-app/ # Aplicación legacy vulnerable
├── scripts/
│   ├── build-and-push-images.sh    # Construir y subir imágenes
│   ├── deploy-to-cluster.sh        # Desplegar en cluster
│   ├── setup-bastion.sh            # Configurar bastión
│   ├── complete-deployment.sh      # Script completo
│   ├── cleanup-ecr.sh              # Limpiar ECR antes de destroy
│   └── check-bastion.sh            # Verificar estado del bastión
├── exploitation/
│   ├── exploit-web-app.sh          # Explotar aplicación web
│   ├── exploit-api.sh              # Explotar API
│   ├── exploit-database.sh         # Explotar base de datos
│   ├── exploit-k8s.sh              # Explotar Kubernetes
│   ├── lateral-movement.sh         # Movimiento lateral
│   ├── enumerate-resources.sh      # Enumerar recursos
│   ├── steal-service-account-token.sh # Robar tokens
│   ├── reverse-shell.sh            # Reverse shells
│   ├── get-shell.sh                # Obtener shell interactiva
│   ├── master-exploit.sh           # Script maestro
│   └── README.md                   # Documentación de explotación
└── README.md                  # Este archivo
```

## Licencia

Este proyecto es solo para fines educativos y de laboratorio.

