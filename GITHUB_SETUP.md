# Guía para Subir el Código a GitHub

## Pasos para Crear y Subir el Repositorio

### Opción 1: Usando el Script Automatizado

```bash
# Ejecutar el script de configuración
chmod +x scripts/setup-github.sh
./scripts/setup-github.sh
```

Luego sigue las instrucciones que aparecen en pantalla.

### Opción 2: Pasos Manuales

#### 1. Inicializar Git (si no está inicializado)

```bash
git init
```

#### 2. Verificar .gitignore

El archivo `.gitignore` ya está configurado para excluir:
- Archivos de Terraform (estado, variables sensibles)
- Claves SSH
- Configuraciones de AWS/Kubernetes
- Archivos temporales

#### 3. Agregar archivos y hacer commit

```bash
# Agregar todos los archivos
git add .

# Verificar qué se va a commitear (opcional)
git status

# Crear commit inicial
git commit -m "Initial commit: Infraestructura de laboratorio de seguridad"
```

#### 4. Crear Repositorio en GitHub

1. Ve a [https://github.com/new](https://github.com/new)
2. **Nombre del repositorio**: `fastandsecure25` (o el que prefieras)
3. **Descripción**: `Infraestructura de laboratorio de seguridad con Terraform, AWS EKS y aplicaciones vulnerables`
4. **Visibilidad**: 
   - `Private` - Si quieres mantenerlo privado
   - `Public` - Si quieres compartirlo (recomendado para proyectos educativos)
5. **IMPORTANTE**: NO marques las opciones de:
   - ❌ Add a README file
   - ❌ Add .gitignore
   - ❌ Choose a license
   
   (Ya tenemos estos archivos en el proyecto)

6. Click en **"Create repository"**

#### 5. Conectar Repositorio Local con GitHub

```bash
# Reemplaza TU_USUARIO con tu usuario de GitHub
git remote add origin https://github.com/TU_USUARIO/fastandsecure25.git

# Verificar que se agregó correctamente
git remote -v
```

#### 6. Renombrar Branch Principal (si es necesario)

```bash
git branch -M main
```

#### 7. Subir el Código

```bash
# Primera vez (establece upstream)
git push -u origin main

# En el futuro, solo necesitas:
git push
```

## Comandos Completos (Copy-Paste)

```bash
# 1. Inicializar git
git init

# 2. Agregar archivos
git add .

# 3. Commit inicial
git commit -m "Initial commit: Infraestructura de laboratorio de seguridad"

# 4. Agregar remote (REEMPLAZA TU_USUARIO)
git remote add origin https://github.com/TU_USUARIO/fastandsecure25.git

# 5. Renombrar branch
git branch -M main

# 6. Subir código
git push -u origin main
```

## Verificación

Después de hacer push, verifica en GitHub:
- ✅ Todos los archivos están presentes
- ✅ El README.md se muestra correctamente
- ✅ La estructura de directorios es correcta

## Configuración Adicional (Opcional)

### Configurar Git (si es la primera vez)

```bash
git config --global user.name "Tu Nombre"
git config --global user.email "tu.email@example.com"
```

### Usar SSH en lugar de HTTPS

Si prefieres usar SSH:

```bash
# Generar clave SSH (si no tienes una)
ssh-keygen -t ed25519 -C "tu.email@example.com"

# Agregar clave a ssh-agent
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519

# Copiar clave pública
cat ~/.ssh/id_ed25519.pub
# Pegar en GitHub: Settings > SSH and GPG keys > New SSH key

# Usar SSH URL en lugar de HTTPS
git remote set-url origin git@github.com:TU_USUARIO/fastandsecure25.git
```

### Agregar Descripción al Repositorio

En GitHub, puedes agregar:
- **Topics**: `terraform`, `kubernetes`, `aws`, `security`, `vulnerable-apps`, `eks`, `docker`
- **Website**: (opcional) Si tienes documentación online
- **Description**: Infraestructura de laboratorio de seguridad con Terraform y Kubernetes

## Estructura que se Subirá

```
fastandsecure25/
├── .gitignore
├── README.md
├── GITHUB_SETUP.md
├── terraform/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── terraform.tfvars.example
│   └── modules/
│       └── vpc/
├── docker-images/
│   ├── vulnerable-web-app/
│   ├── vulnerable-api/
│   ├── vulnerable-database/
│   └── vulnerable-legacy-app/
├── scripts/
│   ├── build-and-push-images.sh
│   ├── deploy-to-cluster.sh
│   ├── monitor-containers.sh
│   └── ...
└── exploitation/
    ├── exploit-web-app.sh
    ├── exploit-api.sh
    └── ...
```

## Troubleshooting

### Error: "remote origin already exists"
```bash
# Ver remotes actuales
git remote -v

# Eliminar y volver a agregar
git remote remove origin
git remote add origin https://github.com/TU_USUARIO/fastandsecure25.git
```

### Error: "failed to push some refs"
```bash
# Si el repositorio de GitHub tiene contenido inicial
git pull origin main --allow-unrelated-histories
git push -u origin main
```

### Error de autenticación
```bash
# GitHub ya no acepta contraseñas, usa Personal Access Token
# Crear token en: GitHub > Settings > Developer settings > Personal access tokens
# Usar el token como contraseña cuando git lo pida
```

## Próximos Pasos Después de Subir

1. ✅ Agregar badges al README (opcional)
2. ✅ Configurar GitHub Actions para CI/CD (opcional)
3. ✅ Agregar Issues templates (opcional)
4. ✅ Configurar branch protection (si es necesario)

