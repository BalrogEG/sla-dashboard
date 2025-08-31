# SLA Dashboard - Quick Start Guide

## 🚀 Deploy in 5 Minutes

### Prerequisites
- Linux server (Ubuntu 20.04+ recommended)
- Root access
- Internet connection

### Option 1: GitHub Deployment (Recommended)

#### Step 1: Upload to GitHub
1. **Create GitHub repository**:
   - Go to [GitHub.com](https://github.com)
   - Click "+" → "New repository"
   - Name: `sla-dashboard`
   - Set to Public or Private
   - Click "Create repository"

2. **Upload your code**:
   ```bash
   # In your current sla-dashboard directory
   git remote add origin https://github.com/YOUR_USERNAME/sla-dashboard.git
   git branch -M main
   git push -u origin main
   ```

#### Step 2: Deploy on Target Server
```bash
# On your Linux server
git clone https://github.com/YOUR_USERNAME/sla-dashboard.git
cd sla-dashboard
sudo ./deploy.sh --domain yourdomain.com
```

### Option 2: Direct File Transfer

#### Step 1: Create Deployment Package
```bash
# Create a deployment package
cd /home/ubuntu
tar -czf sla-dashboard-deployment.tar.gz sla-dashboard/
```

#### Step 2: Transfer and Deploy
```bash
# Transfer to target server (replace SERVER_IP with your server IP)
scp sla-dashboard-deployment.tar.gz root@SERVER_IP:/tmp/

# On target server
cd /tmp
tar -xzf sla-dashboard-deployment.tar.gz
cd sla-dashboard
sudo ./deploy.sh --domain yourdomain.com
```

### Option 3: Docker Deployment

```bash
# Clone or transfer the application
git clone https://github.com/YOUR_USERNAME/sla-dashboard.git
cd sla-dashboard

# Deploy with Docker
sudo ./docker-deploy.sh --domain yourdomain.com
```

## 🎯 What Happens During Deployment

The deployment script automatically:
1. ✅ Updates system packages
2. ✅ Installs Python 3.11 and dependencies
3. ✅ Creates application user and directories
4. ✅ Sets up systemd service
5. ✅ Configures Nginx reverse proxy
6. ✅ Sets up firewall rules
7. ✅ Configures SSL (if domain provided)
8. ✅ Creates monitoring and backup scripts
9. ✅ Starts all services

## 🌐 Access Your Dashboard

After deployment:
- **Local access**: `http://your-server-ip`
- **Domain access**: `http://yourdomain.com` (if domain configured)
- **Health check**: `http://your-server-ip/health`

## 📊 Import Your Data

1. **Open the dashboard** in your browser
2. **Click "Data Management"** in the sidebar
3. **Click "Import Freshdesk Data"** button
4. **Wait for import to complete**
5. **Navigate to different sections** to view analytics

## 🔧 Management Commands

```bash
# Check application status
sudo systemctl status sla-dashboard

# View logs
sudo journalctl -u sla-dashboard -f

# Restart application
sudo systemctl restart sla-dashboard

# For Docker deployment
./manage.sh status
./manage.sh logs
./manage.sh restart
```

## 🆘 Troubleshooting

### Application won't start
```bash
# Check logs
sudo journalctl -u sla-dashboard -n 50

# Check file permissions
sudo chown -R sla-dashboard:sla-dashboard /opt/sla-dashboard
```

### Can't access dashboard
```bash
# Check if service is running
curl http://localhost/health

# Check firewall
sudo ufw status

# Check nginx
sudo systemctl status nginx
```

### Data import fails
1. Ensure you have the `raw_tickets_data.json` file in the application directory
2. Check that the file has proper JSON format
3. Verify file permissions

## 📞 Support

- **Documentation**: See `README.md` for detailed information
- **Deployment Checklist**: See `DEPLOYMENT_CHECKLIST.md`
- **Git Setup**: See `GIT_SETUP_GUIDE.md`

## 🎉 Success!

Once deployed, you'll have:
- ✅ Real-time SLA monitoring dashboard
- ✅ Customer segmentation analytics
- ✅ Outage tracking and analysis
- ✅ Executive reporting with exports
- ✅ Automated monitoring and backups
- ✅ Production-ready security setup

**Dashboard URL**: `http://your-server-ip` or `http://yourdomain.com`

