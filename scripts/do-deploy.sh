#!/bin/bash

# DigitalOcean One-Click Deployment Script for SLA Dashboard
# Usage: curl -sSL https://raw.githubusercontent.com/BalrogEG/sla-dashboard/main/scripts/do-deploy.sh | sudo bash -s -- --domain yourdomain.com

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
REPO_URL="https://github.com/BalrogEG/sla-dashboard.git"
INSTALL_DIR="/tmp/sla-dashboard-install"
DOMAIN=""

log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warning() {
    echo -e "${YELLOW}[WARNING] $1${NC}"
}

error() {
    echo -e "${RED}[ERROR] $1${NC}"
    exit 1
}

# Parse arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --domain)
            DOMAIN="$2"
            shift 2
            ;;
        --help)
            echo "DigitalOcean SLA Dashboard Deployment Script"
            echo ""
            echo "Usage: $0 [--domain DOMAIN]"
            echo ""
            echo "Options:"
            echo "  --domain DOMAIN    Domain name for SSL certificate"
            echo "  --help            Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0 --domain sla.yourdomain.com"
            echo "  $0"
            echo ""
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

# Detect DigitalOcean environment
detect_digitalocean() {
    log "Detecting DigitalOcean environment..."
    
    # Check for DigitalOcean metadata service
    if curl -s --connect-timeout 5 http://169.254.169.254/metadata/v1/id > /dev/null 2>&1; then
        DROPLET_ID=$(curl -s http://169.254.169.254/metadata/v1/id)
        DROPLET_REGION=$(curl -s http://169.254.169.254/metadata/v1/region)
        PUBLIC_IP=$(curl -s http://169.254.169.254/metadata/v1/interfaces/public/0/ipv4/address)
        
        log "✅ DigitalOcean Droplet detected"
        log "   Droplet ID: $DROPLET_ID"
        log "   Region: $DROPLET_REGION"
        log "   Public IP: $PUBLIC_IP"
    else
        warning "Not running on DigitalOcean droplet (metadata service not available)"
        PUBLIC_IP=$(curl -s ifconfig.me || echo "unknown")
        log "   Public IP: $PUBLIC_IP"
    fi
}

# Install prerequisites
install_prerequisites() {
    log "Installing prerequisites..."
    
    # Update system
    apt update
    
    # Install git if not present
    if ! command -v git &> /dev/null; then
        apt install -y git
    fi
    
    # Install curl if not present
    if ! command -v curl &> /dev/null; then
        apt install -y curl
    fi
    
    log "✅ Prerequisites installed"
}

# Download and deploy
download_and_deploy() {
    log "Downloading SLA Dashboard..."
    
    # Clean up any existing installation
    rm -rf "$INSTALL_DIR"
    
    # Clone repository
    git clone "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    
    log "✅ Repository downloaded"
    
    # Make deployment script executable
    chmod +x deploy.sh
    
    # Run deployment
    log "Starting deployment..."
    if [[ -n "$DOMAIN" ]]; then
        ./deploy.sh --domain "$DOMAIN"
    else
        ./deploy.sh
    fi
}

# Configure DigitalOcean specific settings
configure_digitalocean() {
    log "Configuring DigitalOcean specific settings..."
    
    # Enable DigitalOcean monitoring agent if available
    if command -v do-agent &> /dev/null; then
        systemctl enable do-agent
        systemctl start do-agent
        log "✅ DigitalOcean monitoring agent enabled"
    fi
    
    # Configure automatic security updates
    if ! dpkg -l | grep -q unattended-upgrades; then
        apt install -y unattended-upgrades
        echo 'Unattended-Upgrade::Automatic-Reboot "false";' >> /etc/apt/apt.conf.d/50unattended-upgrades
        systemctl enable unattended-upgrades
        log "✅ Automatic security updates enabled"
    fi
    
    # Configure log rotation for DigitalOcean
    cat > /etc/logrotate.d/sla-dashboard-do << 'EOF'
/opt/sla-dashboard/logs/*.log {
    daily
    missingok
    rotate 14
    compress
    delaycompress
    notifempty
    create 644 sla-dashboard sla-dashboard
    postrotate
        systemctl reload sla-dashboard
    endscript
}
EOF
    
    log "✅ DigitalOcean specific configuration completed"
}

# Setup monitoring
setup_monitoring() {
    log "Setting up monitoring..."
    
    # Create monitoring script
    cat > /opt/sla-dashboard/monitor-do.sh << 'EOF'
#!/bin/bash

# DigitalOcean SLA Dashboard Monitoring Script

LOGFILE="/opt/sla-dashboard/logs/monitor.log"
WEBHOOK_URL=""  # Add your webhook URL for alerts

log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] $1" >> "$LOGFILE"
}

send_alert() {
    local message="$1"
    log_message "ALERT: $message"
    
    # Send to webhook if configured
    if [[ -n "$WEBHOOK_URL" ]]; then
        curl -X POST -H "Content-Type: application/json" \
             -d "{\"text\":\"SLA Dashboard Alert: $message\"}" \
             "$WEBHOOK_URL" 2>/dev/null || true
    fi
}

# Check application health
if ! curl -f -s http://localhost/health > /dev/null; then
    send_alert "Application health check failed"
    systemctl restart sla-dashboard
    sleep 10
    
    if ! curl -f -s http://localhost/health > /dev/null; then
        send_alert "Application restart failed - manual intervention required"
    else
        log_message "Application restarted successfully"
    fi
else
    log_message "Application health check passed"
fi

# Check disk space
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [[ $DISK_USAGE -gt 85 ]]; then
    send_alert "Disk usage is ${DISK_USAGE}% - cleanup required"
fi

# Check memory usage
MEMORY_USAGE=$(free | awk 'NR==2{printf "%.0f", $3*100/$2}')
if [[ $MEMORY_USAGE -gt 90 ]]; then
    send_alert "Memory usage is ${MEMORY_USAGE}% - investigation required"
fi

log_message "Monitoring check completed"
EOF

    chmod +x /opt/sla-dashboard/monitor-do.sh
    chown sla-dashboard:sla-dashboard /opt/sla-dashboard/monitor-do.sh
    
    # Add to crontab
    (crontab -u sla-dashboard -l 2>/dev/null; echo "*/5 * * * * /opt/sla-dashboard/monitor-do.sh") | crontab -u sla-dashboard -
    
    log "✅ Monitoring setup completed"
}

# Display completion message
show_completion() {
    log "🎉 DigitalOcean deployment completed successfully!"
    echo ""
    echo "📊 SLA Dashboard Information:"
    echo "   Repository: $REPO_URL"
    echo "   Public IP: $PUBLIC_IP"
    
    if [[ -n "$DOMAIN" ]]; then
        echo "   Domain: https://$DOMAIN"
        echo "   Health Check: https://$DOMAIN/health"
    else
        echo "   Access URL: http://$PUBLIC_IP"
        echo "   Health Check: http://$PUBLIC_IP/health"
    fi
    
    echo ""
    echo "🔧 Management Commands:"
    echo "   Status: sudo systemctl status sla-dashboard"
    echo "   Logs: sudo journalctl -u sla-dashboard -f"
    echo "   Restart: sudo systemctl restart sla-dashboard"
    echo ""
    echo "📈 DigitalOcean Features:"
    echo "   • Monitoring: Enabled (if available)"
    echo "   • Auto Updates: Security updates enabled"
    echo "   • Log Rotation: Configured for 14 days"
    echo "   • Health Monitoring: Every 5 minutes"
    echo ""
    echo "🚀 Next Steps:"
    echo "   1. Access the dashboard using the URL above"
    echo "   2. Navigate to 'Data Management' to import Freshdesk data"
    echo "   3. Configure monitoring alerts (optional)"
    echo "   4. Set up backups (already automated)"
    echo ""
    
    if [[ -n "$DROPLET_ID" ]]; then
        echo "💡 DigitalOcean Tips:"
        echo "   • Create snapshots before major updates"
        echo "   • Monitor resource usage in the control panel"
        echo "   • Consider load balancers for high availability"
        echo "   • Use floating IPs for easier maintenance"
    fi
}

# Main execution
main() {
    log "🌊 Starting DigitalOcean SLA Dashboard deployment..."
    
    detect_digitalocean
    install_prerequisites
    download_and_deploy
    configure_digitalocean
    setup_monitoring
    show_completion
    
    # Cleanup
    rm -rf "$INSTALL_DIR"
}

main "$@"

