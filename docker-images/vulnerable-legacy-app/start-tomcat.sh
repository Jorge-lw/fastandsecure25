#!/bin/sh
# Wrapper script to start Tomcat without SecurityManager

# Modify catalina.sh to disable SecurityManager before starting
sed -i 's/-Djava\.security\.manager/-Djava.security.manager=/' /usr/local/tomcat/bin/catalina.sh 2>/dev/null || true
sed -i 's/SECURITY_MANAGER=1/SECURITY_MANAGER=0/' /usr/local/tomcat/bin/catalina.sh 2>/dev/null || true

export CATALINA_OPTS="-Djava.security.manager="
export JAVA_OPTS="-Djava.security.manager="

# Start Tomcat
exec /usr/local/tomcat/bin/catalina.sh run

