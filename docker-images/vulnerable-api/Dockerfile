# API vulnerable con problemas de seguridad
# Especificar plataforma para compatibilidad (EKS usa linux/amd64)
FROM --platform=linux/amd64 python:3.7-slim

# Vulnerabilidad: Versión antigua de Python
# Vulnerabilidad: Ejecutar como root
USER root

# Vulnerabilidad: Credenciales en variables de entorno
ENV ADMIN_PASSWORD=changeme123
ENV JWT_SECRET=insecure_secret_key

WORKDIR /app

# Vulnerabilidad: Instalar paquetes vulnerables
RUN pip install --no-cache-dir flask==1.1.1 requests==2.20.0

# Vulnerabilidad: Copiar código con vulnerabilidades
COPY api.py .
COPY requirements.txt .

# Vulnerabilidad: Sin validación de certificados SSL
ENV PYTHONHTTPSVERIFY=0

# Vulnerabilidad: Exponer puerto
EXPOSE 5000

# Vulnerabilidad: Ejecutar como root
CMD ["python", "api.py"]

