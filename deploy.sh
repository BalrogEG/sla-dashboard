#!/bin/bash

# SLA Dashboard Deployment Script for Linux
# Author: Manus AI
# Version: 1.0
# Description: Automated deployment script for SLA Dashboard on Linux machines

set -e  # Exit on any error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
APP_NAME="sla-dashboard"
APP_USER="sla-dashboard"
APP_DIR="/opt/sla-dashboard"
SERVICE_NAME="sla-dashboard"
PYTHON_VERSION="3.11"
PORT="5000"
DOMAIN=""  # Set this if you have a domain

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

info() {
    echo -e "${BLUE}[INFO] $1${NC}"
}

# Check if running as root
check_root() {
    if [[ $EUID -eq 0 ]]; then
        log "Running as root - OK"
    else
        error "This script must be run as root. Use: sudo ./deploy.sh"
    fi
}

# Detect Linux distribution
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VER=$VERSION_ID
        log "Detected OS: $OS $VER"
    else
        error "Cannot detect Linux distribution"
    fi
}

# Update system packages
update_system() {
    log "Updating system packages..."
    
    if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
        apt update && apt upgrade -y
        apt install -y curl wget git nginx supervisor python3 python3-pip python3-venv \
                       build-essential python3-dev libpq-dev postgresql-client \
                       software-properties-common apt-transport-https ca-certificates \
                       gnupg lsb-release ufw fail2ban
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
        yum update -y
        yum install -y curl wget git nginx supervisor python3 python3-pip \
                       gcc python3-devel postgresql-devel epel-release \
                       firewalld fail2ban
    else
        error "Unsupported Linux distribution: $OS"
    fi
    
    log "System packages updated successfully"
}

# Install Python 3.11 if needed
install_python() {
    log "Checking Python installation..."
    
    # Check if Python 3.11 is available
    if command -v python3.11 &> /dev/null; then
        log "Python 3.11 already installed"
        return 0
    fi
    
    # Check if system Python is 3.11 or newer
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -oP '\d+\.\d+' | head -1)
    if [[ $(echo "$PYTHON_VERSION >= 3.11" | bc -l) -eq 1 ]]; then
        log "System Python $PYTHON_VERSION is compatible (>= 3.11)"
        # Create symlink for compatibility
        ln -sf $(which python3) /usr/local/bin/python3.11 2>/dev/null || true
        return 0
    fi
    
    warning "Python 3.11 not found, installing..."
    
    if [[ "$OS" == *"Ubuntu"* ]]; then
        # Check Ubuntu version
        UBUNTU_VERSION=$(lsb_release -rs 2>/dev/null || echo "0")
        
        if [[ $(echo "$UBUNTU_VERSION >= 24.04" | bc -l) -eq 1 ]]; then
            # For Ubuntu 24.04+, try to install from official repos first
            log "Attempting to install Python 3.11 from official repositories..."
            apt update
            if apt install -y python3.11 python3.11-venv python3.11-dev 2>/dev/null; then
                log "Python 3.11 installed from official repositories"
            else
                # Fallback to deadsnakes PPA for older Ubuntu versions
                log "Official repos don't have Python 3.11, trying deadsnakes PPA..."
                if add-apt-repository ppa:deadsnakes/ppa -y 2>/dev/null; then
                    apt update
                    apt install -y python3.11 python3.11-venv python3.11-dev
                else
                    warning "deadsnakes PPA not available for this Ubuntu version"
                    # Use system Python if it's reasonably recent
                    if [[ $(echo "$PYTHON_VERSION >= 3.9" | bc -l) -eq 1 ]]; then
                        log "Using system Python $PYTHON_VERSION as fallback"
                        ln -sf $(which python3) /usr/local/bin/python3.11
                        # Install venv if not available
                        apt install -y python3-venv python3-dev
                    else
                        error "Cannot install Python 3.11 and system Python $PYTHON_VERSION is too old"
                    fi
                fi
            fi
        else
            # For older Ubuntu versions, use deadsnakes PPA
            add-apt-repository ppa:deadsnakes/ppa -y
            apt update
            apt install -y python3.11 python3.11-venv python3.11-dev
        fi
    elif [[ "$OS" == *"CentOS"* ]] || [[ "$OS" == *"Red Hat"* ]] || [[ "$OS" == *"Rocky"* ]]; then
        # For RHEL-based systems
        yum install -y python3.11 python3.11-devel python3.11-pip
    else
        warning "Unsupported distribution for automatic Python 3.11 installation"
        log "Please install Python 3.11 manually for your distribution"
        # Try to use system Python if available
        if [[ $(echo "$PYTHON_VERSION >= 3.9" | bc -l) -eq 1 ]]; then
            log "Using system Python $PYTHON_VERSION as fallback"
            ln -sf $(which python3) /usr/local/bin/python3.11
        else
            error "System Python $PYTHON_VERSION is too old. Please install Python 3.11+ manually"
        fi
    fi
}

# Create application user
create_app_user() {
    log "Creating application user: $APP_USER"
    
    if id "$APP_USER" &>/dev/null; then
        log "User $APP_USER already exists"
    else
        useradd --system --shell /bin/bash --home-dir $APP_DIR --create-home $APP_USER
        log "User $APP_USER created successfully"
    fi
}

# Setup application directory
setup_app_directory() {
    log "Setting up application directory: $APP_DIR"
    
    # Create directory structure
    mkdir -p $APP_DIR/{app,logs,backups,config}
    
    # Copy application files
    if [[ -d "./src" ]]; then
        cp -r ./src $APP_DIR/app/
        cp -r ./requirements.txt $APP_DIR/app/ 2>/dev/null || true
    else
        error "Application source files not found. Run this script from the SLA Dashboard directory."
    fi
    
    # Set permissions
    chown -R $APP_USER:$APP_USER $APP_DIR
    chmod -R 755 $APP_DIR
    
    log "Application directory setup completed"
}

# Install Python dependencies
install_dependencies() {
    log "Installing Python dependencies..."
    
    cd $APP_DIR/app
    
    # Create virtual environment
    sudo -u $APP_USER python3.11 -m venv venv
    
    # Activate virtual environment and install dependencies
    sudo -u $APP_USER bash -c "
        source venv/bin/activate
        pip install --upgrade pip
        pip install flask flask-sqlalchemy flask-cors gunicorn
        pip install requests python-dateutil
    "
    
    log "Python dependencies installed successfully"
}

# Configure application
configure_app() {
    log "Configuring application..."
    
    # Create production configuration
    cat > $APP_DIR/config/production.py << EOF
import os

class ProductionConfig:
    SECRET_KEY = os.environ.get('SECRET_KEY') or '$(openssl rand -hex 32)'
    SQLALCHEMY_DATABASE_URI = os.environ.get('DATABASE_URL') or 'sqlite:///$APP_DIR/app/database/app.db'
    SQLALCHEMY_TRACK_MODIFICATIONS = False
    DEBUG = False
    TESTING = False
    
    # Security settings
    SESSION_COOKIE_SECURE = True
    SESSION_COOKIE_HTTPONLY = True
    SESSION_COOKIE_SAMESITE = 'Lax'
    
    # Application settings
    MAX_CONTENT_LENGTH = 16 * 1024 * 1024  # 16MB max file upload
EOF

    # Create environment file
    cat > $APP_DIR/config/.env << EOF
FLASK_APP=main.py
FLASK_ENV=production
SECRET_KEY=$(openssl rand -hex 32)
DATABASE_URL=sqlite:///$APP_DIR/app/database/app.db
PORT=$PORT
EOF

    # Create startup script
    cat > $APP_DIR/app/start.sh << EOF
#!/bin/bash
cd $APP_DIR/app
source venv/bin/activate
source ../config/.env
exec gunicorn --bind 0.0.0.0:$PORT --workers 4 --timeout 120 --keep-alive 2 --max-requests 1000 --max-requests-jitter 100 src.main:app
EOF

    chmod +x $APP_DIR/app/start.sh
    chown -R $APP_USER:$APP_USER $APP_DIR
    
    log "Application configuration completed"
}

# Setup systemd service
setup_systemd_service() {
    log "Setting up systemd service..."
    
    cat > /etc/systemd/system/$SERVICE_NAME.service << EOF
[Unit]
Description=SLA Dashboard Application
After=network.target

[Service]
Type=exec
User=$APP_USER
Group=$APP_USER
WorkingDirectory=$APP_DIR/app
Environment=PATH=$APP_DIR/app/venv/bin
EnvironmentFile=$APP_DIR/config/.env
ExecStart=$APP_DIR/app/start.sh
ExecReload=/bin/kill -s HUP \$MAINPID
Restart=always
RestartSec=10
StandardOutput=append:$APP_DIR/logs/app.log
StandardError=append:$APP_DIR/logs/error.log

[Install]
WantedBy=multi-user.target
EOF

    # Enable and start service
    systemctl daemon-reload
    systemctl enable $SERVICE_NAME
    
    log "Systemd service configured"
}

# Configure Nginx
configure_nginx() {
    log "Configuring Nginx..."
    
    # Remove default site
    rm -f /etc/nginx/sites-enabled/default
    
    # Create application configuration
    cat > /etc/nginx/sites-available/$APP_NAME << EOF
server {
    listen 80;
    server_name ${DOMAIN:-_};
    
    # Security headers
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    add_header Content-Security-Policy "default-src 'self' http: https: data: blob: 'unsafe-inline'" always;
    
    # Gzip compression
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_proxied expired no-cache no-store private must-revalidate auth;
    gzip_types text/plain text/css text/xml text/javascript application/x-javascript application/xml+rss application/javascript;
    
    # Static files
    location /static/ {
        alias $APP_DIR/app/src/static/;
        expires 1y;
        add_header Cache-Control "public, immutable";
    }
    
    # Application
    location / {
        proxy_pass http://127.0.0.1:$PORT;
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
        proxy_pass http://127.0.0.1:$PORT/api/dashboard/health;
    }
}
EOF

    # Enable site
    ln -sf /etc/nginx/sites-available/$APP_NAME /etc/nginx/sites-enabled/
    
    # Test configuration
    nginx -t || error "Nginx configuration test failed"
    
    log "Nginx configured successfully"
}

# Setup firewall
setup_firewall() {
    log "Configuring firewall..."
    
    if command -v ufw &> /dev/null; then
        # Ubuntu/Debian firewall
        ufw --force reset
        ufw default deny incoming
        ufw default allow outgoing
        ufw allow ssh
        ufw allow 'Nginx Full'
        ufw --force enable
    elif command -v firewall-cmd &> /dev/null; then
        # CentOS/RHEL firewall
        systemctl enable firewalld
        systemctl start firewalld
        firewall-cmd --permanent --add-service=ssh
        firewall-cmd --permanent --add-service=http
        firewall-cmd --permanent --add-service=https
        firewall-cmd --reload
    fi
    
    log "Firewall configured"
}

# Setup SSL with Let's Encrypt (optional)
setup_ssl() {
    if [[ -n "$DOMAIN" ]]; then
        log "Setting up SSL certificate for domain: $DOMAIN"
        
        # Install certbot
        if [[ "$OS" == *"Ubuntu"* ]] || [[ "$OS" == *"Debian"* ]]; then
            apt install -y certbot python3-certbot-nginx
        else
            warning "Please install certbot manually for SSL setup"
            return
        fi
        
        # Get certificate
        certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN
        
        log "SSL certificate installed"
    else
        warning "No domain specified, skipping SSL setup"
    fi
}

# Setup monitoring and logging
setup_monitoring() {
    log "Setting up monitoring and logging..."
    
    # Create log rotation
    cat > /etc/logrotate.d/$APP_NAME << EOF
$APP_DIR/logs/*.log {
    daily
    missingok
    rotate 52
    compress
    delaycompress
    notifempty
    create 644 $APP_USER $APP_USER
    postrotate
        systemctl reload $SERVICE_NAME
    endscript
}
EOF

    # Create monitoring script
    cat > $APP_DIR/monitor.sh << EOF
#!/bin/bash
# Simple monitoring script for SLA Dashboard

APP_URL="http://localhost:$PORT/api/dashboard/health"
LOG_FILE="$APP_DIR/logs/monitor.log"

check_app() {
    if curl -f -s \$APP_URL > /dev/null; then
        echo "\$(date): Application is running" >> \$LOG_FILE
        return 0
    else
        echo "\$(date): Application is down, restarting..." >> \$LOG_FILE
        systemctl restart $SERVICE_NAME
        return 1
    fi
}

check_app
EOF

    chmod +x $APP_DIR/monitor.sh
    
    # Add to crontab for app user
    (crontab -u $APP_USER -l 2>/dev/null; echo "*/5 * * * * $APP_DIR/monitor.sh") | crontab -u $APP_USER -
    
    log "Monitoring and logging setup completed"
}

# Create backup script
create_backup_script() {
    log "Creating backup script..."
    
    cat > $APP_DIR/backup.sh << EOF
#!/bin/bash
# Backup script for SLA Dashboard

BACKUP_DIR="$APP_DIR/backups"
DATE=\$(date +%Y%m%d_%H%M%S)
BACKUP_FILE="sla_dashboard_backup_\$DATE.tar.gz"

# Create backup
tar -czf \$BACKUP_DIR/\$BACKUP_FILE -C $APP_DIR app/database app/src/static/uploads 2>/dev/null || true

# Keep only last 7 backups
find \$BACKUP_DIR -name "sla_dashboard_backup_*.tar.gz" -mtime +7 -delete

echo "\$(date): Backup created: \$BACKUP_FILE"
EOF

    chmod +x $APP_DIR/backup.sh
    
    # Add to crontab for daily backups
    (crontab -u $APP_USER -l 2>/dev/null; echo "0 2 * * * $APP_DIR/backup.sh") | crontab -u $APP_USER -
    
    log "Backup script created"
}

# Start services
start_services() {
    log "Starting services..."
    
    # Start application
    systemctl start $SERVICE_NAME
    systemctl status $SERVICE_NAME --no-pager
    
    # Start nginx
    systemctl enable nginx
    systemctl restart nginx
    systemctl status nginx --no-pager
    
    log "Services started successfully"
}

# Verify deployment
verify_deployment() {
    log "Verifying deployment..."
    
    # Wait for application to start
    sleep 10
    
    # Check if application is responding
    if curl -f -s http://localhost:$PORT/api/dashboard/health > /dev/null; then
        log "✅ Application is responding on port $PORT"
    else
        error "❌ Application is not responding"
    fi
    
    # Check nginx
    if curl -f -s http://localhost/ > /dev/null; then
        log "✅ Nginx is serving the application"
    else
        error "❌ Nginx is not working properly"
    fi
    
    log "🎉 Deployment verification completed successfully!"
}

# Print deployment summary
print_summary() {
    log "📋 Deployment Summary"
    echo "=================================="
    echo "Application: SLA Dashboard"
    echo "Directory: $APP_DIR"
    echo "User: $APP_USER"
    echo "Port: $PORT"
    echo "Service: $SERVICE_NAME"
    echo "Logs: $APP_DIR/logs/"
    echo "Backups: $APP_DIR/backups/"
    echo ""
    echo "🔧 Management Commands:"
    echo "  Start:   systemctl start $SERVICE_NAME"
    echo "  Stop:    systemctl stop $SERVICE_NAME"
    echo "  Restart: systemctl restart $SERVICE_NAME"
    echo "  Status:  systemctl status $SERVICE_NAME"
    echo "  Logs:    journalctl -u $SERVICE_NAME -f"
    echo ""
    echo "🌐 Access URLs:"
    echo "  Local:   http://localhost/"
    if [[ -n "$DOMAIN" ]]; then
        echo "  Domain:  http://$DOMAIN/"
    fi
    echo ""
    echo "📁 Important Files:"
    echo "  Config:  $APP_DIR/config/"
    echo "  Logs:    $APP_DIR/logs/"
    echo "  Backup:  $APP_DIR/backup.sh"
    echo "  Monitor: $APP_DIR/monitor.sh"
    echo "=================================="
}

# Main deployment function
main() {
    log "🚀 Starting SLA Dashboard deployment..."
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --domain)
                DOMAIN="$2"
                shift 2
                ;;
            --port)
                PORT="$2"
                shift 2
                ;;
            --help)
                echo "Usage: $0 [--domain DOMAIN] [--port PORT]"
                echo "  --domain DOMAIN  Set domain name for SSL setup"
                echo "  --port PORT      Set application port (default: 5000)"
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                ;;
        esac
    done
    
    # Run deployment steps
    check_root
    detect_os
    update_system
    install_python
    create_app_user
    setup_app_directory
    install_dependencies
    configure_app
    setup_systemd_service
    configure_nginx
    setup_firewall
    setup_ssl
    setup_monitoring
    create_backup_script
    start_services
    verify_deployment
    print_summary
    
    log "🎉 SLA Dashboard deployment completed successfully!"
}

# Run main function
main "$@"

