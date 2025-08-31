# SLA Dashboard - DigitalOcean Deployment Guide

## 🌊 Complete DigitalOcean Deployment Instructions

This guide provides step-by-step instructions for deploying the SLA Dashboard on DigitalOcean droplets, from droplet creation to production deployment.

## 📋 Prerequisites

- DigitalOcean account
- Domain name (optional but recommended)
- SSH key pair (recommended for security)
- Basic command line knowledge

## 🚀 Quick Deployment (5 Minutes)

### Option 1: One-Click Deployment Script

```bash
# Create and deploy in one command (after droplet creation)
curl -sSL https://raw.githubusercontent.com/BalrogEG/sla-dashboard/main/scripts/do-deploy.sh | sudo bash -s -- --domain yourdomain.com
```

### Option 2: Manual Deployment

```bash
# Clone and deploy
git clone https://github.com/BalrogEG/sla-dashboard.git
cd sla-dashboard
sudo ./deploy.sh --domain yourdomain.com
```

## 🖥️ Step 1: Create DigitalOcean Droplet

### Via DigitalOcean Control Panel

1. **Login to DigitalOcean**: [https://cloud.digitalocean.com](https://cloud.digitalocean.com)

2. **Create Droplet**:
   - Click "Create" → "Droplets"
   - **Image**: Ubuntu 22.04 (LTS) x64 (recommended)
   - **Plan**: 
     - **Basic**: $6/month (1GB RAM, 1 vCPU, 25GB SSD) - Minimum
     - **Regular**: $12/month (2GB RAM, 1 vCPU, 50GB SSD) - Recommended
     - **Regular**: $24/month (4GB RAM, 2 vCPUs, 80GB SSD) - Production
   - **Datacenter**: Choose closest to your users
   - **Authentication**: SSH Key (recommended) or Password
   - **Hostname**: `sla-dashboard-prod`
   - **Tags**: `sla-dashboard`, `production`

3. **Click "Create Droplet"**

### Via DigitalOcean CLI (doctl)

```bash
# Install doctl
curl -sL https://github.com/digitalocean/doctl/releases/download/v1.104.0/doctl-1.104.0-linux-amd64.tar.gz | tar -xzv
sudo mv doctl /usr/local/bin

# Authenticate
doctl auth init

# Create droplet
doctl compute droplet create sla-dashboard-prod \
  --image ubuntu-22-04-x64 \
  --size s-2vcpu-2gb \
  --region nyc3 \
  --ssh-keys YOUR_SSH_KEY_ID \
  --tag-names sla-dashboard,production \
  --wait
```

### Via Terraform (Infrastructure as Code)

```hcl
# main.tf
terraform {
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

variable "do_token" {}
variable "ssh_key_id" {}

provider "digitalocean" {
  token = var.do_token
}

resource "digitalocean_droplet" "sla_dashboard" {
  image    = "ubuntu-22-04-x64"
  name     = "sla-dashboard-prod"
  region   = "nyc3"
  size     = "s-2vcpu-2gb"
  ssh_keys = [var.ssh_key_id]
  
  tags = ["sla-dashboard", "production"]
  
  user_data = file("cloud-init.yml")
}

resource "digitalocean_domain" "sla_dashboard" {
  name = "yourdomain.com"
}

resource "digitalocean_record" "sla_dashboard" {
  domain = digitalocean_domain.sla_dashboard.name
  type   = "A"
  name   = "@"
  value  = digitalocean_droplet.sla_dashboard.ipv4_address
}

output "droplet_ip" {
  value = digitalocean_droplet.sla_dashboard.ipv4_address
}
```

## 🔧 Step 2: Initial Server Setup

### Connect to Your Droplet

```bash
# Replace YOUR_DROPLET_IP with actual IP
ssh root@YOUR_DROPLET_IP

# Or if using SSH key
ssh -i ~/.ssh/your_key root@YOUR_DROPLET_IP
```

### Basic Security Setup (Recommended)

```bash
# Update system
apt update && apt upgrade -y

# Create non-root user (optional)
adduser sladmin
usermod -aG sudo sladmin
rsync --archive --chown=sladmin:sladmin ~/.ssh /home/sladmin

# Configure firewall
ufw allow OpenSSH
ufw allow 'Nginx Full'
ufw --force enable

# Install fail2ban
apt install fail2ban -y
systemctl enable fail2ban
```

## 🚀 Step 3: Deploy SLA Dashboard

### Automated Deployment

```bash
# Clone repository
git clone https://github.com/BalrogEG/sla-dashboard.git
cd sla-dashboard

# Deploy with domain (recommended)
sudo ./deploy.sh --domain yourdomain.com

# Or deploy without domain (IP access only)
sudo ./deploy.sh
```

### What the Deployment Does

The script automatically:
1. ✅ Installs Python 3.11+ and dependencies
2. ✅ Creates `sla-dashboard` system user
3. ✅ Sets up application in `/opt/sla-dashboard/`
4. ✅ Configures systemd service for auto-start
5. ✅ Sets up Nginx reverse proxy
6. ✅ Configures SSL with Let's Encrypt (if domain provided)
7. ✅ Sets up firewall rules
8. ✅ Creates monitoring and backup scripts
9. ✅ Starts all services

### Deployment Output

```
🚀 Starting SLA Dashboard deployment...
✅ System packages updated
✅ Python 3.11 installed
✅ Application user created
✅ Application deployed to /opt/sla-dashboard
✅ Virtual environment created
✅ Dependencies installed
✅ Database initialized
✅ Systemd service configured
✅ Nginx configured
✅ SSL certificate obtained
✅ Firewall configured
✅ Monitoring scripts installed
✅ Backup scripts configured

🎉 Deployment completed successfully!
🌐 Application available at: https://yourdomain.com
📊 Health check: https://yourdomain.com/health
```

## 🌐 Step 4: Domain Configuration

### Option A: DigitalOcean DNS

1. **Add Domain to DigitalOcean**:
   - Go to Networking → Domains
   - Add your domain
   - Create A record pointing to droplet IP

2. **Update Domain Nameservers**:
   - Point your domain to DigitalOcean nameservers:
     - `ns1.digitalocean.com`
     - `ns2.digitalocean.com`
     - `ns3.digitalocean.com`

### Option B: External DNS Provider

```bash
# Create A record at your DNS provider
# Type: A
# Name: @ (or subdomain like 'sla')
# Value: YOUR_DROPLET_IP
# TTL: 300 (5 minutes)
```

### SSL Certificate (Automatic)

The deployment script automatically obtains SSL certificates using Let's Encrypt when a domain is provided.

## 📊 Step 5: Access Your Dashboard

### URLs

- **Main Dashboard**: `https://yourdomain.com`
- **Health Check**: `https://yourdomain.com/health`
- **API Documentation**: `https://yourdomain.com/api/docs`

### Default Access

If deployed without domain:
- **HTTP**: `http://YOUR_DROPLET_IP`
- **Health**: `http://YOUR_DROPLET_IP/health`

## 🔧 Step 6: Post-Deployment Configuration

### Import Freshdesk Data

1. **Access Dashboard**: Open `https://yourdomain.com`
2. **Navigate to Data Management**
3. **Click "Import Freshdesk Data"**
4. **Wait for import completion**

### Configure Monitoring

```bash
# Check application status
sudo systemctl status sla-dashboard

# View logs
sudo journalctl -u sla-dashboard -f

# Check Nginx status
sudo systemctl status nginx

# Test SSL certificate
curl -I https://yourdomain.com
```

## 🔄 Management Commands

### Service Management

```bash
# Start/Stop/Restart application
sudo systemctl start sla-dashboard
sudo systemctl stop sla-dashboard
sudo systemctl restart sla-dashboard

# Enable/Disable auto-start
sudo systemctl enable sla-dashboard
sudo systemctl disable sla-dashboard

# Check service status
sudo systemctl status sla-dashboard
```

### Application Management

```bash
# View real-time logs
sudo journalctl -u sla-dashboard -f

# Check application health
curl https://yourdomain.com/health

# View error logs
sudo tail -f /opt/sla-dashboard/logs/error.log

# View access logs
sudo tail -f /var/log/nginx/access.log
```

### Backup and Restore

```bash
# Manual backup
sudo /opt/sla-dashboard/backup.sh

# List backups
ls -la /opt/sla-dashboard/backups/

# Restore from backup
cd /opt/sla-dashboard
sudo tar -xzf backups/sla_dashboard_backup_YYYYMMDD_HHMMSS.tar.gz
sudo systemctl restart sla-dashboard
```

## 📈 Scaling and Performance

### Vertical Scaling (Resize Droplet)

```bash
# Via doctl
doctl compute droplet-action resize DROPLET_ID --size s-4vcpu-8gb --wait

# Via Control Panel
# Droplets → Your Droplet → Resize → Choose new size
```

### Horizontal Scaling (Load Balancer)

```bash
# Create additional droplets
doctl compute droplet create sla-dashboard-02 \
  --image ubuntu-22-04-x64 \
  --size s-2vcpu-2gb \
  --region nyc3 \
  --ssh-keys YOUR_SSH_KEY_ID

# Deploy to additional droplets
# Set up DigitalOcean Load Balancer
```

### Performance Optimization

```bash
# Increase Gunicorn workers
sudo nano /opt/sla-dashboard/app/start.sh
# Change: --workers 4 to --workers 8

# Enable Redis caching
sudo apt install redis-server
sudo systemctl enable redis-server

# Restart application
sudo systemctl restart sla-dashboard
```

## 🔒 Security Best Practices

### Firewall Configuration

```bash
# Check firewall status
sudo ufw status

# Allow specific IPs only (optional)
sudo ufw allow from YOUR_OFFICE_IP to any port 22
sudo ufw allow from YOUR_OFFICE_IP to any port 443

# Block all other SSH access
sudo ufw delete allow OpenSSH
sudo ufw allow from YOUR_OFFICE_IP to any port 22
```

### SSL/TLS Security

```bash
# Test SSL configuration
curl -I https://yourdomain.com
openssl s_client -connect yourdomain.com:443

# Check SSL certificate expiry
sudo certbot certificates

# Renew SSL certificate (automatic via cron)
sudo certbot renew --dry-run
```

### Application Security

```bash
# Change default secret key
sudo nano /opt/sla-dashboard/config/.env
# Update SECRET_KEY=your-new-secret-key

# Restart application
sudo systemctl restart sla-dashboard
```

## 📊 Monitoring and Alerts

### DigitalOcean Monitoring

1. **Enable Monitoring**: Droplets → Your Droplet → Monitoring
2. **Set up Alerts**: 
   - CPU usage > 80%
   - Memory usage > 90%
   - Disk usage > 85%

### Application Monitoring

```bash
# Install monitoring tools
sudo apt install htop iotop nethogs

# Monitor resources
htop
iotop
nethogs

# Check application metrics
curl https://yourdomain.com/api/dashboard/metrics
```

### Log Monitoring

```bash
# Set up log rotation
sudo nano /etc/logrotate.d/sla-dashboard

# Monitor error patterns
sudo tail -f /opt/sla-dashboard/logs/error.log | grep ERROR

# Set up log alerts (optional)
sudo apt install logwatch
```

## 🚨 Troubleshooting

### Common Issues

#### Deployment Fails

```bash
# Check system requirements
free -h  # Ensure 2GB+ RAM
df -h    # Ensure 10GB+ disk space

# Check logs
sudo journalctl -u sla-dashboard -n 50

# Retry deployment
cd /opt/sla-dashboard
sudo ./deploy.sh
```

#### Application Won't Start

```bash
# Check service status
sudo systemctl status sla-dashboard

# Check Python environment
sudo -u sla-dashboard /opt/sla-dashboard/app/venv/bin/python --version

# Fix permissions
sudo chown -R sla-dashboard:sla-dashboard /opt/sla-dashboard
```

#### SSL Certificate Issues

```bash
# Check certificate status
sudo certbot certificates

# Renew certificate manually
sudo certbot renew

# Check Nginx configuration
sudo nginx -t
sudo systemctl reload nginx
```

#### Performance Issues

```bash
# Check resource usage
htop
df -h
free -h

# Check application logs
sudo journalctl -u sla-dashboard -n 100

# Restart services
sudo systemctl restart sla-dashboard nginx
```

## 💰 Cost Optimization

### Droplet Sizing Guide

| Use Case | Droplet Size | Monthly Cost | Specs |
|----------|--------------|--------------|-------|
| Development | Basic | $6 | 1GB RAM, 1 vCPU |
| Small Production | Regular | $12 | 2GB RAM, 1 vCPU |
| Medium Production | Regular | $24 | 4GB RAM, 2 vCPUs |
| High Traffic | Regular | $48 | 8GB RAM, 4 vCPUs |

### Cost Saving Tips

1. **Use Snapshots**: Create snapshots before major changes
2. **Reserved Instances**: Consider reserved pricing for long-term use
3. **Monitoring**: Set up billing alerts
4. **Cleanup**: Remove unused droplets and volumes

## 🔄 Updates and Maintenance

### Application Updates

```bash
# Pull latest changes
cd /opt/sla-dashboard/app
sudo -u sla-dashboard git pull origin main

# Restart application
sudo systemctl restart sla-dashboard
```

### System Updates

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Python dependencies
cd /opt/sla-dashboard/app
sudo -u sla-dashboard ./venv/bin/pip install --upgrade -r requirements.txt

# Restart application
sudo systemctl restart sla-dashboard
```

### Backup Strategy

```bash
# Automated daily backups (already configured)
# Manual backup before updates
sudo /opt/sla-dashboard/backup.sh

# Create droplet snapshot
doctl compute droplet-action snapshot DROPLET_ID --snapshot-name "sla-dashboard-$(date +%Y%m%d)"
```

## 📞 Support and Resources

### DigitalOcean Resources

- **Documentation**: [https://docs.digitalocean.com](https://docs.digitalocean.com)
- **Community**: [https://www.digitalocean.com/community](https://www.digitalocean.com/community)
- **Support**: Available via control panel

### SLA Dashboard Resources

- **Repository**: [https://github.com/BalrogEG/sla-dashboard](https://github.com/BalrogEG/sla-dashboard)
- **Documentation**: See README.md in repository
- **Issues**: GitHub Issues for bug reports

## 🎯 Production Checklist

### Pre-Deployment

- [ ] DigitalOcean account set up
- [ ] Domain name configured
- [ ] SSH keys generated
- [ ] Droplet created and accessible

### Deployment

- [ ] Application deployed successfully
- [ ] SSL certificate obtained
- [ ] Firewall configured
- [ ] Services running

### Post-Deployment

- [ ] Dashboard accessible via domain
- [ ] Health check responding
- [ ] Data imported successfully
- [ ] Monitoring configured
- [ ] Backups scheduled
- [ ] Team access configured

### Production Ready

- [ ] Performance tested
- [ ] Security hardened
- [ ] Monitoring alerts set up
- [ ] Backup/restore tested
- [ ] Documentation updated
- [ ] Team trained

---

**Repository**: https://github.com/BalrogEG/sla-dashboard  
**Deployment Time**: ~10 minutes  
**Monthly Cost**: Starting at $6/month  
**Support**: DigitalOcean + GitHub Issues

