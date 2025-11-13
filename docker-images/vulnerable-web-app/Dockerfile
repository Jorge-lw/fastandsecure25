# Image with multiple known vulnerabilities
# Specify platform for compatibility (EKS uses linux/amd64)
FROM --platform=linux/amd64 node:14-alpine

# Vulnerability: Old Node.js version with known CVEs
# Vulnerability: Root user
USER root

# Vulnerability: Expose hardcoded credentials
ENV DB_PASSWORD=admin123
ENV API_KEY=sk_live_1234567890abcdef
ENV SECRET_TOKEN=super_secret_token_12345

# Vulnerability: Install packages without verifying checksums
RUN apk add --no-cache curl wget

# Vulnerability: Copy sensitive files
COPY secrets.txt /app/secrets.txt

# Vulnerability: Overly permissive permissions
RUN chmod 777 /app

WORKDIR /app

# Vulnerability: Vulnerable express version
RUN npm install express@4.16.0 --no-audit

# Vulnerability: Run as root
COPY app.js .
COPY package.json .

# Vulnerability: Expose port without restrictions
EXPOSE 3000

# Vulnerability: Insecure command
CMD ["node", "app.js"]
