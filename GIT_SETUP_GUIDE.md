# Git Setup Guide for SLA Dashboard

## Overview
This guide will help you upload the SLA Dashboard application to Git and set up deployment from any machine using `git clone`.

## Option 1: GitHub (Recommended)

### Step 1: Create GitHub Repository

1. **Go to GitHub**: Visit [https://github.com](https://github.com)
2. **Sign in** to your GitHub account (or create one if needed)
3. **Create new repository**:
   - Click the "+" icon in the top right
   - Select "New repository"
   - Repository name: `sla-dashboard`
   - Description: `SLA Dashboard for Freshdesk Ticket Monitoring`
   - Set to **Public** or **Private** (your choice)
   - **DO NOT** initialize with README (we already have one)
   - Click "Create repository"

### Step 2: Initialize Local Git Repository

```bash
# Navigate to your SLA Dashboard directory
cd /home/ubuntu/sla-dashboard

# Initialize git repository
git init

# Add all files to git
git add .

# Create initial commit
git commit -m "Initial commit: SLA Dashboard application with deployment scripts"

# Add GitHub remote (replace YOUR_USERNAME with your GitHub username)
git remote add origin https://github.com/YOUR_USERNAME/sla-dashboard.git

# Push to GitHub
git branch -M main
git push -u origin main
```

### Step 3: Verify Upload
1. Go to your GitHub repository: `https://github.com/YOUR_USERNAME/sla-dashboard`
2. Verify all files are uploaded
3. Check that README.md displays properly

### Step 4: Clone on Target Machine
```bash
# On any Linux machine where you want to deploy
git clone https://github.com/YOUR_USERNAME/sla-dashboard.git
cd sla-dashboard

# Run deployment
sudo ./deploy.sh --domain yourdomain.com
```

## Option 2: GitLab

### Step 1: Create GitLab Repository

1. **Go to GitLab**: Visit [https://gitlab.com](https://gitlab.com)
2. **Sign in** to your GitLab account
3. **Create new project**:
   - Click "New project"
   - Select "Create blank project"
   - Project name: `sla-dashboard`
   - Project description: `SLA Dashboard for Freshdesk Ticket Monitoring`
   - Visibility level: **Private** or **Public**
   - **Uncheck** "Initialize repository with a README"
   - Click "Create project"

### Step 2: Push to GitLab

```bash
# Navigate to your SLA Dashboard directory
cd /home/ubuntu/sla-dashboard

# Initialize git repository (if not done already)
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: SLA Dashboard application"

# Add GitLab remote (replace YOUR_USERNAME with your GitLab username)
git remote add origin https://gitlab.com/YOUR_USERNAME/sla-dashboard.git

# Push to GitLab
git branch -M main
git push -u origin main
```

### Step 3: Clone on Target Machine
```bash
# On any Linux machine
git clone https://gitlab.com/YOUR_USERNAME/sla-dashboard.git
cd sla-dashboard
sudo ./deploy.sh
```

## Option 3: Bitbucket

### Step 1: Create Bitbucket Repository

1. **Go to Bitbucket**: Visit [https://bitbucket.org](https://bitbucket.org)
2. **Sign in** to your Bitbucket account
3. **Create repository**:
   - Click "Create" → "Repository"
   - Repository name: `sla-dashboard`
   - Access level: **Private** or **Public**
   - **Uncheck** "Include a README"
   - Click "Create repository"

### Step 2: Push to Bitbucket

```bash
cd /home/ubuntu/sla-dashboard

git init
git add .
git commit -m "Initial commit: SLA Dashboard application"

# Add Bitbucket remote
git remote add origin https://YOUR_USERNAME@bitbucket.org/YOUR_USERNAME/sla-dashboard.git

git branch -M main
git push -u origin main
```

## Option 4: Private Git Server (Advanced)

### Step 1: Set up Git Server

```bash
# On your git server
sudo apt update
sudo apt install git

# Create git user
sudo adduser git

# Create repository
sudo mkdir /opt/git
sudo chown git:git /opt/git
sudo -u git git init --bare /opt/git/sla-dashboard.git
```

### Step 2: Push to Private Server

```bash
cd /home/ubuntu/sla-dashboard

git init
git add .
git commit -m "Initial commit: SLA Dashboard application"

# Add private server remote
git remote add origin git@YOUR_SERVER_IP:/opt/git/sla-dashboard.git

git push -u origin main
```

## Complete Setup Script

Here's a complete script to automate the Git setup:

```bash
#!/bin/bash

# Git Setup Script for SLA Dashboard
# Usage: ./git-setup.sh <github|gitlab|bitbucket> <username> [repository-name]

PLATFORM=$1
USERNAME=$2
REPO_NAME=${3:-sla-dashboard}

if [[ -z "$PLATFORM" || -z "$USERNAME" ]]; then
    echo "Usage: $0 <github|gitlab|bitbucket> <username> [repository-name]"
    echo "Example: $0 github myusername sla-dashboard"
    exit 1
fi

# Set remote URL based on platform
case $PLATFORM in
    github)
        REMOTE_URL="https://github.com/$USERNAME/$REPO_NAME.git"
        ;;
    gitlab)
        REMOTE_URL="https://gitlab.com/$USERNAME/$REPO_NAME.git"
        ;;
    bitbucket)
        REMOTE_URL="https://$USERNAME@bitbucket.org/$USERNAME/$REPO_NAME.git"
        ;;
    *)
        echo "Unsupported platform: $PLATFORM"
        echo "Supported platforms: github, gitlab, bitbucket"
        exit 1
        ;;
esac

echo "Setting up Git repository for SLA Dashboard..."
echo "Platform: $PLATFORM"
echo "Username: $USERNAME"
echo "Repository: $REPO_NAME"
echo "Remote URL: $REMOTE_URL"

# Initialize git repository
git init

# Add all files
git add .

# Create initial commit
git commit -m "Initial commit: SLA Dashboard application with deployment scripts

Features:
- Complete SLA monitoring dashboard
- Freshdesk integration
- Customer segmentation (Enterprise, Local Enterprise, Wholesale)
- Outage analysis and tracking
- Executive reporting with export capabilities
- Automated deployment scripts for Linux
- Docker deployment option
- Comprehensive documentation"

# Add remote
git remote add origin $REMOTE_URL

# Set main branch
git branch -M main

# Push to remote
echo "Pushing to $PLATFORM..."
git push -u origin main

echo "✅ Git repository setup completed!"
echo ""
echo "🔗 Repository URL: $REMOTE_URL"
echo ""
echo "📋 Next steps:"
echo "1. Verify the repository is created on $PLATFORM"
echo "2. On target deployment machine, run:"
echo "   git clone $REMOTE_URL"
echo "   cd $REPO_NAME"
echo "   sudo ./deploy.sh --domain yourdomain.com"
echo ""
echo "📚 For detailed deployment instructions, see README.md"
```

Save this as `git-setup.sh` and run:

```bash
chmod +x git-setup.sh
./git-setup.sh github YOUR_USERNAME sla-dashboard
```

## Deployment Instructions for Team

Once uploaded to Git, share these instructions with your team:

### Quick Deployment on Any Linux Machine

```bash
# 1. Clone the repository
git clone https://github.com/YOUR_USERNAME/sla-dashboard.git

# 2. Navigate to directory
cd sla-dashboard

# 3. Deploy (choose one option)

# Option A: Native Linux deployment
sudo ./deploy.sh --domain yourdomain.com

# Option B: Docker deployment
sudo ./docker-deploy.sh --domain yourdomain.com

# 4. Access the dashboard
# Open browser to: http://your-server-ip or http://yourdomain.com
```

### Repository Structure
```
sla-dashboard/
├── src/                          # Application source code
│   ├── main.py                   # Flask application entry point
│   ├── models/                   # Database models
│   ├── routes/                   # API routes
│   └── static/                   # Frontend files (HTML, CSS, JS)
├── deploy.sh                     # Native Linux deployment script
├── docker-deploy.sh              # Docker deployment script
├── requirements.txt              # Python dependencies
├── README.md                     # Comprehensive documentation
├── DEPLOYMENT_CHECKLIST.md       # Operations checklist
├── LICENSE                       # MIT license
└── .gitignore                    # Git ignore rules
```

## Security Considerations

### For Public Repositories
- ✅ No sensitive data (API keys, passwords) in code
- ✅ Environment variables used for configuration
- ✅ .gitignore excludes sensitive files
- ✅ Database files excluded from repository

### For Private Repositories
- ✅ Additional security through access control
- ✅ Team collaboration features
- ✅ Branch protection rules can be enabled

## Updating the Repository

### Making Changes
```bash
# Make your changes to the code
# Then commit and push

git add .
git commit -m "Description of changes"
git push origin main
```

### Updating Deployment
```bash
# On deployment machine
cd sla-dashboard
git pull origin main

# Restart application
sudo systemctl restart sla-dashboard

# Or for Docker
./manage.sh restart
```

## Troubleshooting Git Setup

### Authentication Issues
```bash
# For HTTPS (will prompt for username/password)
git clone https://github.com/USERNAME/sla-dashboard.git

# For SSH (requires SSH key setup)
git clone git@github.com:USERNAME/sla-dashboard.git
```

### Large File Issues
If you have large files, consider using Git LFS:
```bash
git lfs install
git lfs track "*.db"
git add .gitattributes
```

### Permission Issues
```bash
# Fix file permissions
chmod +x deploy.sh
chmod +x docker-deploy.sh
git add .
git commit -m "Fix file permissions"
git push
```

This guide provides multiple options for hosting your SLA Dashboard code and ensures easy deployment across different environments.

