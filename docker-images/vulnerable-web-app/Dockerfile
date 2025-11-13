# Imagen con múltiples vulnerabilidades conocidas
# Especificar plataforma para compatibilidad (EKS usa linux/amd64)
FROM --platform=linux/amd64 node:14-alpine

# Vulnerabilidad: Versión antigua de Node.js con CVE conocidos
# Vulnerabilidad: Usuario root
USER root

# Vulnerabilidad: Exponer credenciales hardcodeadas
ENV DB_PASSWORD=admin123
ENV API_KEY=sk_live_1234567890abcdef
ENV SECRET_TOKEN=super_secret_token_12345

# Vulnerabilidad: Instalar paquetes sin verificar checksums
RUN apk add --no-cache curl wget

# Vulnerabilidad: Copiar archivos sensibles
COPY secrets.txt /app/secrets.txt

# Vulnerabilidad: Permisos demasiado permisivos
RUN chmod 777 /app

WORKDIR /app

# Vulnerabilidad: Versión vulnerable de express
RUN npm install express@4.16.0 --no-audit

# Vulnerabilidad: Ejecutar como root
COPY app.js .
COPY package.json .

# Vulnerabilidad: Exponer puerto sin restricciones
EXPOSE 3000

# Vulnerabilidad: Comando inseguro
CMD ["node", "app.js"]

