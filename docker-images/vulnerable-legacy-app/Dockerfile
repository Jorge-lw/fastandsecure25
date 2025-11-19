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

# VULNERABILITY: Install vulnerable Java libraries with known CVEs
# These libraries have critical vulnerabilities but are commonly used
RUN apk add --no-cache wget curl && \
    mkdir -p /usr/local/tomcat/lib/vulnerable && \
    cd /usr/local/tomcat/lib/vulnerable && \
    # Apache Commons Collections (CVE-2015-6420, CVE-2017-15710, etc.)
    wget -q https://repo1.maven.org/maven2/commons-collections/commons-collections/3.2.1/commons-collections-3.2.1.jar && \
    # Apache Commons BeanUtils (CVE-2014-0114)
    wget -q https://repo1.maven.org/maven2/commons-beanutils/commons-beanutils/1.9.2/commons-beanutils-1.9.2.jar && \
    # Apache Struts (CVE-2017-5638, CVE-2017-12611, etc.)
    wget -q https://repo1.maven.org/maven2/org/apache/struts/struts2-core/2.3.16/struts2-core-2.3.16.jar && \
    # Jackson (CVE-2017-7525, CVE-2018-7489, etc.)
    wget -q https://repo1.maven.org/maven2/com/fasterxml/jackson/core/jackson-databind/2.7.0/jackson-databind-2.7.0.jar && \
    # Log4j (CVE-2017-5645, CVE-2019-17571, etc.) - Note: Not Log4Shell version
    wget -q https://repo1.maven.org/maven2/log4j/log4j/1.2.17/log4j-1.2.17.jar && \
    # Apache HttpClient (CVE-2014-3577, CVE-2015-5262, etc.)
    wget -q https://repo1.maven.org/maven2/org/apache/httpcomponents/httpclient/4.3.6/httpclient-4.3.6.jar && \
    # Apache Commons FileUpload (CVE-2016-1000031)
    wget -q https://repo1.maven.org/maven2/commons-fileupload/commons-fileupload/1.3.1/commons-fileupload-1.3.1.jar && \
    # Apache Commons IO (CVE-2021-29425)
    wget -q https://repo1.maven.org/maven2/commons-io/commons-io/2.4/commons-io-2.4.jar && \
    # Spring Framework (CVE-2016-5007, CVE-2018-1270, etc.)
    wget -q https://repo1.maven.org/maven2/org/springframework/spring-core/4.3.7.RELEASE/spring-core-4.3.7.RELEASE.jar && \
    # Apache CXF (CVE-2017-12624, CVE-2018-8039, etc.)
    wget -q https://repo1.maven.org/maven2/org/apache/cxf/cxf-core/3.1.11/cxf-core-3.1.11.jar && \
    # Apache Shiro (CVE-2016-4437)
    wget -q https://repo1.maven.org/maven2/org/apache/shiro/shiro-core/1.2.4/shiro-core-1.2.4.jar && \
    # Fastjson (CVE-2017-18349, CVE-2020-8840, etc.)
    wget -q https://repo1.maven.org/maven2/com/alibaba/fastjson/1.2.24/fastjson-1.2.24.jar && \
    # XStream (CVE-2013-7285, CVE-2020-26217, etc.)
    wget -q https://repo1.maven.org/maven2/com/thoughtworks/xstream/xstream/1.4.7/xstream-1.4.7.jar && \
    # Apache Velocity (CVE-2020-13936)
    wget -q https://repo1.maven.org/maven2/org/apache/velocity/velocity/1.7/velocity-1.7.jar && \
    # Copy vulnerable libraries to Tomcat lib directory
    cp *.jar /usr/local/tomcat/lib/ && \
    rm -rf /usr/local/tomcat/lib/vulnerable && \
    apk del wget curl

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
