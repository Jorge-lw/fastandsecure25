# Aplicación legacy con múltiples vulnerabilidades
# Especificar plataforma para compatibilidad (EKS usa linux/amd64)
FROM --platform=linux/amd64 tomcat:8.5-jre8-alpine

# Vulnerabilidad: Versión antigua de Tomcat con CVE conocidos
# Vulnerabilidad: Ejecutar como root
USER root

# Vulnerabilidad: Deshabilitar verificaciones de seguridad
ENV CATALINA_OPTS="-Djava.security.manager= -Djava.security.policy=all.policy"

WORKDIR /usr/local/tomcat

# Vulnerabilidad: Aplicación web vulnerable (placeholder)
# En producción sería un WAR real, aquí usamos un HTML simple
RUN mkdir -p webapps/ROOT
COPY index.html webapps/ROOT/

# Vulnerabilidad: Configuración insegura
COPY server.xml conf/server.xml

# Vulnerabilidad: Exponer puerto
EXPOSE 8080

# Vulnerabilidad: Ejecutar con permisos elevados
RUN chmod -R 777 /usr/local/tomcat

CMD ["catalina.sh", "run"]
