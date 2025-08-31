#!/bin/bash

# SLA Dashboard Docker Deployment Script
# Author: Manus AI
# Version: 1.0
# Description: Docker-based deployment for SLA Dashboard

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
APP_NAME="sla-dashboard"
CONTAINER_NAME="sla-dashboard-app"
IMAGE_NAME="sla-dashboard:latest"
PORT="5000"
EXTERNAL_PORT="80"
DOMAIN=""

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Create Dockerfile
create_dockerfile() {
    log "Creating Dockerfile..."
    
    cat > Dockerfile << 'EOF'
FROM python:3.11-slim

# Set environment variables
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1
ENV FLASK_APP=src.main:app
ENV FLASK_ENV=production

# Set work directory
WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    && rm -rf /var/lib/apt/lists/*

# Copy requirements and install Python dependencies
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

# Copy application code
COPY src/ ./src/
COPY . .

# Create necessary directories
RUN mkdir -p src/database logs

# Create non-root user
RUN useradd --create-home --shell /bin/bash app && \
    chown -R app:app /app
USER app

# Expose port
EXPOSE 5000

# Health check
HEALTHCHECK --interval=30s --timeout=30s --start-period=5s --retries=3 \
    CMD curl -f http://localhost:5000/api/dashboard/health || exit 1

# Run application
CMD ["gunicorn", "--bind", "0.0.0.0:5000", "--workers", "4", "--timeout", "120", "src.main:app"]
EOF

    log "Dockerfile created"
}

# Create docker-compose file
create_docker_compose() {
    log "Creating docker-compose.yml..."
    
    cat > docker-compose.yml << EOF
version: '3.8'

services:
  app:
    build: .
    container_name: $CONTAINER_NAME
    restart: unless-stopped
    ports:
      - "$EXTERNAL_PORT:5000"
    environment:
      - FLASK_ENV=production
      - SECRET_KEY=\${SECRET_KEY:-$(openssl rand -hex 32)}
    volumes:
      - ./data:/app/src/database
      - ./logs:/app/logs
    healthcheck:
      test: ["CMD", "curl", "-f", "http://localhost:5000/api/dashboard/health"]
      interval: 30s
      timeout: 10s
      retries: 3
      start_period: 40s
    networks:
      - sla-network

  nginx:
    image: nginx:alpine
    container_name: sla-dashboard-nginx
    restart: unless-stopped
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx.conf:/etc/nginx/nginx.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - app
    networks:
      - sla-network

networks:
  sla-network:
    driver: bridge

volumes:
  data:
  logs:
EOF

    log "docker-compose.yml created"
}

# Create nginx configuration
create_nginx_config() {
    log "Creating nginx configuration..."
    
    cat > nginx.conf << EOF
events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    # Logging
    log_format main '\$remote_addr - \$remote_user [\$time_local] "\$request" '
                    '\$status \$body_bytes_sent "\$http_referer" '
                    '"\$http_user_agent" "\$http_x_forwarded_for"';
    
    access_log /var/log/nginx/access.log main;
    error_log /var/log/nginx/error.log;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types text/plain text/css application/json application/javascript text/xml application/xml application/xml+rss text/javascript;
    
    # Rate limiting
    limit_req_zone \$binary_remote_addr zone=api:10m rate=10r/s;
    
    upstream app {
        server app:5000;
    }
    
    server {
        listen 80;
        server_name ${DOMAIN:-_};
        
        # Security headers
        add_header X-Frame-Options "SAMEORIGIN" always;
        add_header X-XSS-Protection "1; mode=block" always;
        add_header X-Content-Type-Options "nosniff" always;
        add_header Referrer-Policy "no-referrer-when-downgrade" always;
        
        # Static files
        location /static/ {
            proxy_pass http://app;
            expires 1y;
            add_header Cache-Control "public, immutable";
        }
        
        # API rate limiting
        location /api/ {
            limit_req zone=api burst=20 nodelay;
            proxy_pass http://app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
        
        # Main application
        location / {
            proxy_pass http://app;
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
            proxy_connect_timeout 60s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
        }
        
        # Health check
        location /health {
            access_log off;
            proxy_pass http://app/api/dashboard/health;
        }
    }
}
EOF

    log "nginx configuration created"
}

# Create deployment script
create_deploy_script() {
    log "Creating deployment management script..."
    
    cat > manage.sh << 'EOF'
#!/bin/bash

# SLA Dashboard Management Script

COMPOSE_FILE="docker-compose.yml"

case "$1" in
    start)
        echo "Starting SLA Dashboard..."
        docker-compose up -d
        ;;
    stop)
        echo "Stopping SLA Dashboard..."
        docker-compose down
        ;;
    restart)
        echo "Restarting SLA Dashboard..."
        docker-compose restart
        ;;
    rebuild)
        echo "Rebuilding and restarting SLA Dashboard..."
        docker-compose down
        docker-compose build --no-cache
        docker-compose up -d
        ;;
    logs)
        docker-compose logs -f
        ;;
    status)
        docker-compose ps
        ;;
    backup)
        echo "Creating backup..."
        mkdir -p backups
        tar -czf "backups/sla-dashboard-backup-$(date +%Y%m%d_%H%M%S).tar.gz" data/ logs/
        echo "Backup created in backups/ directory"
        ;;
    update)
        echo "Updating application..."
        git pull
        docker-compose build
        docker-compose up -d
        ;;
    clean)
        echo "Cleaning up unused Docker resources..."
        docker system prune -f
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|rebuild|logs|status|backup|update|clean}"
        exit 1
        ;;
esac
EOF

    chmod +x manage.sh
    log "Management script created"
}

# Install Docker
install_docker() {
    log "Installing Docker..."
    
    # Remove old versions
    apt-get remove -y docker docker-engine docker.io containerd runc 2>/dev/null || true
    
    # Install dependencies
    apt-get update
    apt-get install -y ca-certificates curl gnupg lsb-release
    
    # Add Docker's official GPG key
    mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    
    # Set up repository
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable" | tee /etc/apt/sources.list.d/docker.list > /dev/null
    
    # Install Docker Engine
    apt-get update
    apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
    
    # Install docker-compose
    curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    chmod +x /usr/local/bin/docker-compose
    
    # Start Docker
    systemctl enable docker
    systemctl start docker
    
    log "Docker installed successfully"
}

# Main deployment function
main() {
    log "🐳 Starting Docker deployment for SLA Dashboard..."
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --port)
                EXTERNAL_PORT="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--domain DOMAIN] [--port PORT]"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Check if running as root
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root"
    fi
    
    # Install Docker if not present
    if ! command -v docker &> /dev/null; then
        install_docker
    fi
    
    # Create deployment files
    create_dockerfile
    create_docker_compose
    create_nginx_config
    create_deploy_script
    
    # Create directories
    mkdir -p data logs ssl
    
    # Build and start
    log "Building Docker image..."
    docker-compose build
    
    log "Starting services..."
    docker-compose up -d
    
    # Wait for services to start
    sleep 10
    
    # Verify deployment
    if curl -f -s http://localhost:$EXTERNAL_PORT/health > /dev/null; then
        log "✅ Deployment successful!"
        log "🌐 Application is available at: http://localhost:$EXTERNAL_PORT"
        if [[ -n "$DOMAIN" ]]; then
            log "🌐 Domain access: http://$DOMAIN"
        fi
    else
        error "❌ Deployment failed"
    fi
    
    log "📋 Management commands:"
    log "  Start:    ./manage.sh start"
    log "  Stop:     ./manage.sh stop"
    log "  Restart:  ./manage.sh restart"
    log "  Logs:     ./manage.sh logs"
    log "  Status:   ./manage.sh status"
    log "  Backup:   ./manage.sh backup"
}

main "$@"

