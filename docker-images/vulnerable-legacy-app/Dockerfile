# Legacy application with multiple vulnerabilities
# Specify platform for compatibility (EKS uses linux/amd64)
FROM --platform=linux/amd64 tomcat:8.5-jre8-alpine

# Vulnerability: Old Tomcat version with known CVEs
# Vulnerability: Run as root
USER root

# Vulnerability: Disable security checks
ENV CATALINA_OPTS="-Djava.security.manager= -Djava.security.policy=all.policy"

WORKDIR /usr/local/tomcat

# Vulnerability: Vulnerable web application (placeholder)
# In production it would be a real WAR, here we use simple HTML
RUN mkdir -p webapps/ROOT
COPY index.html webapps/ROOT/

# Vulnerability: Insecure configuration
COPY server.xml conf/server.xml

# Vulnerability: Expose port
EXPOSE 8080

# Vulnerability: Run with elevated permissions
RUN chmod -R 777 /usr/local/tomcat

CMD ["catalina.sh", "run"]
