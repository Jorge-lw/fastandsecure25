#!/bin/bash

# Script para inicializar git y preparar el repositorio para GitHub

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Configuración de Git para GitHub ===${NC}\n"

# Verificar si git está instalado
if ! command -v git &> /dev/null; then
    echo -e "${RED}Error: git no está instalado${NC}"
    exit 1
fi

# Verificar si ya hay un repositorio git
if [ -d ".git" ]; then
    echo -e "${YELLOW}Ya existe un repositorio git${NC}"
    read -p "¿Continuar de todos modos? (y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

# Inicializar repositorio git si no existe
if [ ! -d ".git" ]; then
    echo -e "${YELLOW}[1] Inicializando repositorio git...${NC}"
    git init
    echo -e "${GREEN}✓ Repositorio inicializado${NC}"
fi

# Verificar .gitignore
if [ ! -f ".gitignore" ]; then
    echo -e "${YELLOW}[2] Creando .gitignore...${NC}"
    # El .gitignore ya debería existir, pero por si acaso
    echo -e "${RED}⚠ .gitignore no encontrado${NC}"
else
    echo -e "${GREEN}✓ .gitignore encontrado${NC}"
fi

# Agregar todos los archivos
echo -e "\n${YELLOW}[3] Agregando archivos al staging...${NC}"
git add .

# Verificar si hay cambios
if git diff --cached --quiet; then
    echo -e "${YELLOW}⚠ No hay cambios para commitear${NC}"
else
    echo -e "${GREEN}✓ Archivos agregados${NC}"
    
    # Hacer commit inicial
    echo -e "\n${YELLOW}[4] Creando commit inicial...${NC}"
    read -p "Mensaje del commit (default: 'Initial commit'): " COMMIT_MSG
    COMMIT_MSG=${COMMIT_MSG:-"Initial commit"}
    
    git commit -m "$COMMIT_MSG"
    echo -e "${GREEN}✓ Commit creado${NC}"
fi

# Información sobre el siguiente paso
echo -e "\n${BLUE}=== Próximos Pasos ===${NC}"
echo -e "${YELLOW}1. Crea un repositorio en GitHub:${NC}"
echo -e "   - Ve a https://github.com/new"
echo -e "   - Nombre del repositorio: fastandsecure25 (o el que prefieras)"
echo -e "   - Descripción: Infraestructura de laboratorio de seguridad con Terraform y Kubernetes"
echo -e "   - Visibilidad: Private o Public (según prefieras)"
echo -e "   - ${RED}NO${NC} inicialices con README, .gitignore o licencia"
echo ""
echo -e "${YELLOW}2. Conecta el repositorio local con GitHub:${NC}"
echo -e "   ${GREEN}git remote add origin https://github.com/TU_USUARIO/fastandsecure25.git${NC}"
echo -e "   (Reemplaza TU_USUARIO con tu usuario de GitHub)"
echo ""
echo -e "${YELLOW}3. Sube el código:${NC}"
echo -e "   ${GREEN}git branch -M main${NC}"
echo -e "   ${GREEN}git push -u origin main${NC}"
echo ""
echo -e "${BLUE}O ejecuta estos comandos después de crear el repo:${NC}"
echo -e "${GREEN}git remote add origin https://github.com/TU_USUARIO/fastandsecure25.git${NC}"
echo -e "${GREEN}git branch -M main${NC}"
echo -e "${GREEN}git push -u origin main${NC}"

