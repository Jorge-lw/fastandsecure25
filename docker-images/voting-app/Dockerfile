# Vulnerable Voting Application
# Multiple security vulnerabilities intentionally included for testing
FROM --platform=linux/amd64 python:3.9-slim

# Vulnerability: Running as root
USER root

# Vulnerability: Expose hardcoded credentials
ENV DB_HOST=vulnerable-database.vulnerable-apps.svc.cluster.local
ENV DB_PORT=3306
ENV DB_USER=admin
ENV DB_PASSWORD=admin123
ENV DB_NAME=vulnerable_db
ENV ADMIN_PASSWORD=admin123

# Vulnerability: Install packages without verification
RUN apt-get update && apt-get install -y \
    default-mysql-client \
    curl \
    wget \
    netcat-openbsd \
    gcc \
    python3-dev \
    libxml2-dev \
    libxslt1-dev \
    libjpeg-dev \
    zlib1g-dev \
    libpng-dev \
    libfreetype6-dev \
    liblcms2-dev \
    libopenjp2-7-dev \
    libtiff5-dev \
    libwebp-dev \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Vulnerability: Old Flask version with known vulnerabilities
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Vulnerability: Copy application files
COPY app.py .

# Vulnerability: Overly permissive permissions
RUN chmod 777 /app

# Vulnerability: Expose port without restrictions
EXPOSE 8080

# Vulnerability: Run as root with debug mode
CMD ["python", "app.py"]

