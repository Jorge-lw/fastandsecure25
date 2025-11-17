#!/bin/sh
# Disable SecurityManager completely
export CATALINA_OPTS="-Djava.security.manager="
export JAVA_OPTS="-Djava.security.manager="

