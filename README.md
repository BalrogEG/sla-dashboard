# SLA Dashboard - Deployment Guide

## Overview

The SLA Dashboard is a comprehensive web application for monitoring Service Level Agreements (SLA) for Freshdesk tickets. It provides real-time analytics, outage tracking, and executive reporting capabilities.

## Features

- 📊 **Real-time SLA Monitoring** - Track compliance rates and breaches
- 🎯 **Customer Segmentation** - Separate views for Enterprise, Local Enterprise, and Wholesale customers
- 🚨 **Outage Analysis** - Monitor service disruptions and MTTR
- 📈 **Trend Analysis** - Historical performance tracking
- 📋 **Executive Reporting** - High-level summaries and export capabilities
- 🔄 **Data Import** - Automated Freshdesk data integration
- 📱 **Responsive Design** - Works on desktop and mobile devices

## Deployment Options

### Option 1: Native Linux Deployment (Recommended for Production)

#### Prerequisites
- Ubuntu 20.04+ or CentOS 8+ Linux server
- Root access
- Internet connection
- 2GB+ RAM, 10GB+ disk space

#### Quick Deployment
```bash
# Download the application
git clone <repository-url> sla-dashboard
cd sla-dashboard

# Run deployment script
sudo ./deploy.sh

# Optional: Set domain and custom port
sudo ./deploy.sh --domain yourdomain.com --port 8080
```

#### What the script does:
1. ✅ Updates system packages
2. ✅ Installs Python 3.11 and dependencies
3. ✅ Creates dedicated application user
4. ✅ Sets up application directory structure
5. ✅ Configures systemd service
6. ✅ Sets up Nginx reverse proxy
7. ✅ Configures firewall (UFW/firewalld)
8. ✅ Sets up SSL with Let's Encrypt (if domain provided)
9. ✅ Creates monitoring and backup scripts
10. ✅ Starts all services

#### Post-deployment Management
```bash
# Service management
sudo systemctl start sla-dashboard
sudo systemctl stop sla-dashboard
sudo systemctl restart sla-dashboard
sudo systemctl status sla-dashboard

# View logs
sudo journalctl -u sla-dashboard -f

# Application files
/opt/sla-dashboard/app/          # Application code
/opt/sla-dashboard/logs/         # Log files
/opt/sla-dashboard/backups/      # Automated backups
/opt/sla-dashboard/config/       # Configuration files
```

### Option 2: Docker Deployment (Recommended for Development)

#### Prerequisites
- Linux server with Docker support
- Root access
- 2GB+ RAM, 5GB+ disk space

#### Quick Docker Deployment
```bash
# Download the application
git clone <repository-url> sla-dashboard
cd sla-dashboard

# Run Docker deployment
sudo ./docker-deploy.sh

# Optional: Set domain and custom port
sudo ./docker-deploy.sh --domain yourdomain.com --port 8080
```

#### Docker Management
```bash
# Use the management script
./manage.sh start      # Start services
./manage.sh stop       # Stop services
./manage.sh restart    # Restart services
./manage.sh logs       # View logs
./manage.sh status     # Check status
./manage.sh backup     # Create backup
./manage.sh rebuild    # Rebuild and restart
./manage.sh update     # Update from git
./manage.sh clean      # Clean unused resources

# Direct docker-compose commands
docker-compose up -d           # Start in background
docker-compose down            # Stop and remove containers
docker-compose logs -f         # Follow logs
docker-compose ps              # Show running containers
```

## Configuration

### Environment Variables
```bash
# Application settings
FLASK_ENV=production
SECRET_KEY=your-secret-key
PORT=5000

# Database settings
DATABASE_URL=sqlite:///path/to/database.db

# Freshdesk API settings (for data import)
FRESHDESK_DOMAIN=your-domain.freshdesk.com
FRESHDESK_API_KEY=your-api-key
```

### Nginx Configuration
The deployment automatically configures Nginx with:
- Reverse proxy to Flask application
- Static file serving with caching
- Security headers
- Gzip compression
- Rate limiting for API endpoints

### SSL/HTTPS Setup
For production deployments with a domain:
```bash
# Automatic SSL with Let's Encrypt
sudo ./deploy.sh --domain yourdomain.com

# Manual SSL certificate
# Place certificates in /etc/nginx/ssl/
# Update nginx configuration accordingly
```

## Data Import

### Freshdesk Integration
1. **Access Data Management**: Click "Data Management" in the dashboard
2. **Import Data**: Click "Import Freshdesk Data" button
3. **Automatic Processing**: The system will process and categorize tickets

### Manual Data Import
```bash
# Place your ticket data JSON file in the application directory
cp your-tickets.json /opt/sla-dashboard/app/

# The application will automatically detect and import the data
```

## Monitoring and Maintenance

### Health Checks
- **Application Health**: `http://your-server/health`
- **API Health**: `http://your-server/api/dashboard/health`

### Automated Monitoring
The deployment includes:
- **Application monitoring** (every 5 minutes)
- **Automatic restart** on failure
- **Daily backups** (kept for 7 days)
- **Log rotation** (daily, kept for 52 weeks)

### Manual Monitoring
```bash
# Check application status
curl http://localhost/health

# Check system resources
htop
df -h
free -h

# Check logs
tail -f /opt/sla-dashboard/logs/app.log
tail -f /opt/sla-dashboard/logs/error.log
```

### Backup and Recovery
```bash
# Manual backup
sudo /opt/sla-dashboard/backup.sh

# Restore from backup
cd /opt/sla-dashboard
sudo tar -xzf backups/sla_dashboard_backup_YYYYMMDD_HHMMSS.tar.gz

# Restart application
sudo systemctl restart sla-dashboard
```

## Troubleshooting

### Common Issues

#### Application won't start
```bash
# Check service status
sudo systemctl status sla-dashboard

# Check logs
sudo journalctl -u sla-dashboard -n 50

# Check file permissions
sudo chown -R sla-dashboard:sla-dashboard /opt/sla-dashboard
```

#### Database issues
```bash
# Check database file
ls -la /opt/sla-dashboard/app/src/database/

# Reset database (WARNING: This will delete all data)
sudo systemctl stop sla-dashboard
sudo rm /opt/sla-dashboard/app/src/database/app.db
sudo systemctl start sla-dashboard
```

#### Nginx issues
```bash
# Test nginx configuration
sudo nginx -t

# Check nginx status
sudo systemctl status nginx

# Check nginx logs
sudo tail -f /var/log/nginx/error.log
```

#### Port conflicts
```bash
# Check what's using the port
sudo netstat -tlnp | grep :5000

# Kill process using the port
sudo kill -9 <PID>

# Or change the port in configuration
sudo nano /opt/sla-dashboard/config/.env
```

### Performance Tuning

#### For high-traffic deployments:
1. **Increase Gunicorn workers**:
   ```bash
   # Edit /opt/sla-dashboard/app/start.sh
   # Change --workers 4 to --workers 8 (or 2x CPU cores)
   ```

2. **Enable database connection pooling**:
   ```bash
   # Consider switching to PostgreSQL for better performance
   # Update DATABASE_URL in /opt/sla-dashboard/config/.env
   ```

3. **Add Redis for caching**:
   ```bash
   # Install Redis
   sudo apt install redis-server
   
   # Configure application to use Redis for session storage
   ```

## Security Considerations

### Firewall Configuration
The deployment automatically configures firewall rules:
- **SSH (22)**: Allowed
- **HTTP (80)**: Allowed
- **HTTPS (443)**: Allowed
- **All other ports**: Denied

### Application Security
- **Secret key**: Automatically generated
- **SQL injection**: Protected by SQLAlchemy ORM
- **XSS protection**: Security headers enabled
- **CSRF protection**: Flask-WTF integration
- **Rate limiting**: Nginx-based API rate limiting

### Regular Security Updates
```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Python dependencies
cd /opt/sla-dashboard/app
source venv/bin/activate
pip install --upgrade -r requirements.txt

# Restart application
sudo systemctl restart sla-dashboard
```

## API Documentation

### Health Check
```
GET /api/dashboard/health
Response: {"status": "healthy", "timestamp": "2025-08-31T12:00:00Z"}
```

### SLA Metrics
```
GET /api/dashboard/sla-metrics?start_date=2025-08-01&end_date=2025-08-31
Response: {
  "total_tickets": 210,
  "sla_compliance_rate": 85.5,
  "sla_breaches": 30,
  "avg_response_time_hours": 2.5
}
```

### Customer Segments
```
GET /api/dashboard/customer-segments?start_date=2025-08-01&end_date=2025-08-31
Response: [
  {
    "customer_type": "enterprise",
    "total_tickets": 50,
    "sla_breaches": 5,
    "compliance_rate": 90.0
  }
]
```

## Support and Maintenance

### Regular Maintenance Tasks
- **Weekly**: Review logs and performance metrics
- **Monthly**: Update system packages and dependencies
- **Quarterly**: Review and update security configurations
- **Annually**: Review backup and disaster recovery procedures

### Getting Help
1. **Check logs**: Always start with application and system logs
2. **Review documentation**: This README and inline code comments
3. **Test in isolation**: Use health check endpoints to isolate issues
4. **Community support**: Check GitHub issues and discussions

## License

This project is licensed under the MIT License. See LICENSE file for details.

## Contributing

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Add tests if applicable
5. Submit a pull request

## Changelog

### Version 1.0.0 (2025-08-31)
- Initial release
- Complete SLA monitoring dashboard
- Freshdesk integration
- Multi-deployment options
- Comprehensive documentation

