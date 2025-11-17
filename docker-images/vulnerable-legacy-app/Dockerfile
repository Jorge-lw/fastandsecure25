# Legacy application with multiple vulnerabilities
# Specify platform for compatibility (EKS uses linux/amd64)
# Using Tomcat 9 which doesn't enable SecurityManager by default
FROM --platform=linux/amd64 tomcat:9-jre8-alpine

# Vulnerability: Old Tomcat version with known CVEs (still vulnerable but works)
# Vulnerability: Run as root
USER root

WORKDIR /usr/local/tomcat

# Vulnerability: Vulnerable web application (placeholder)
# In production it would be a real WAR, here we use simple HTML
RUN mkdir -p webapps/ROOT
COPY index.html webapps/ROOT/

# Vulnerability: Insecure configuration
COPY server.xml conf/server.xml

# Vulnerability: Disable security checks - Tomcat 9 doesn't enable SecurityManager by default
# But we'll still create a permissive policy just in case
RUN echo "grant {" > /usr/local/tomcat/conf/catalina.policy && \
    echo "    permission java.security.AllPermission;" >> /usr/local/tomcat/conf/catalina.policy && \
    echo "};" >> /usr/local/tomcat/conf/catalina.policy

# Vulnerability: Expose port
EXPOSE 8080

# Vulnerability: Run with elevated permissions
RUN chmod -R 777 /usr/local/tomcat

# Tomcat 9 should work without SecurityManager issues
CMD ["catalina.sh", "run"]
