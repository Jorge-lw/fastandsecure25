# Base de datos con configuración insegura
# Especificar plataforma para compatibilidad (EKS usa linux/amd64)
FROM --platform=linux/amd64 mysql:5.7

# Vulnerabilidad: Versión antigua de MySQL con CVE conocidos
# Vulnerabilidad: Root password débil
ENV MYSQL_ROOT_PASSWORD=root123
ENV MYSQL_DATABASE=vulnerable_db
ENV MYSQL_USER=admin
ENV MYSQL_PASSWORD=admin123

# Vulnerabilidad: Permitir conexiones remotas sin restricciones
COPY my.cnf /etc/mysql/conf.d/my.cnf

# Vulnerabilidad: Exponer puerto sin restricciones
EXPOSE 3306

# Vulnerabilidad: Inicializar con datos de prueba inseguros
COPY init.sql /docker-entrypoint-initdb.d/

