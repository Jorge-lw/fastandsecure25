# Database with insecure configuration
# Specify platform for compatibility (EKS uses linux/amd64)
FROM --platform=linux/amd64 mysql:5.7

# Vulnerability: Old MySQL version with known CVEs
# Vulnerability: Weak root password
ENV MYSQL_ROOT_PASSWORD=root123
ENV MYSQL_DATABASE=vulnerable_db
ENV MYSQL_USER=admin
ENV MYSQL_PASSWORD=admin123

# Vulnerability: Allow remote connections without restrictions
COPY my.cnf /etc/mysql/conf.d/my.cnf

# Vulnerability: Expose port without restrictions
EXPOSE 3306

# Vulnerability: Initialize with insecure test data
COPY init.sql /docker-entrypoint-initdb.d/
