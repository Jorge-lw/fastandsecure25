# Vulnerable API with security issues
# Specify platform for compatibility (EKS uses linux/amd64)
FROM --platform=linux/amd64 python:3.7-slim

# Vulnerability: Old Python version
# Vulnerability: Run as root
USER root

# Vulnerability: Credentials in environment variables
ENV ADMIN_PASSWORD=changeme123
ENV JWT_SECRET=insecure_secret_key

WORKDIR /app

# Vulnerability: Install vulnerable packages
RUN pip install --no-cache-dir flask==1.1.1 requests==2.20.0 jinja2==2.11.3 markupsafe==2.0.1 itsdangerous==1.1.0 werkzeug==0.16.1 pyyaml==5.1

# Vulnerability: Copy code with vulnerabilities
COPY api.py .
COPY requirements.txt .

# Vulnerability: No SSL certificate validation
ENV PYTHONHTTPSVERIFY=0

# Vulnerability: Expose port
EXPOSE 5000

# Vulnerability: Run as root
CMD ["python", "api.py"]
