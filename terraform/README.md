# Terraform Deployment for DigitalOcean

This directory contains Terraform configuration files for deploying the SLA Dashboard on DigitalOcean infrastructure.

## 🚀 Quick Start

### Prerequisites

1. **Terraform installed** (>= 1.0)
   ```bash
   # Install Terraform
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform
   ```

2. **DigitalOcean API Token**
   - Go to [DigitalOcean API Tokens](https://cloud.digitalocean.com/account/api/tokens)
   - Create new token with read/write permissions

3. **SSH Key Pair**
   ```bash
   ssh-keygen -t rsa -b 4096 -C "your_email@example.com"
   ```

### Deployment Steps

1. **Configure Variables**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   nano terraform.tfvars
   ```

2. **Initialize Terraform**
   ```bash
   terraform init
   ```

3. **Plan Deployment**
   ```bash
   terraform plan
   ```

4. **Deploy Infrastructure**
   ```bash
   terraform apply
   ```

5. **Access Dashboard**
   ```bash
   # Get outputs
   terraform output
   
   # Access dashboard
   curl $(terraform output -raw dashboard_url)/health
   ```

## 📁 File Structure

```
terraform/
├── digitalocean.tf          # Main Terraform configuration
├── cloud-init.yml           # Cloud-init script for automatic deployment
├── terraform.tfvars.example # Example variables file
└── README.md                # This file
```

## ⚙️ Configuration Options

### Variables

| Variable | Description | Default | Required |
|----------|-------------|---------|----------|
| `do_token` | DigitalOcean API token | - | Yes |
| `ssh_public_key` | SSH public key content | - | Yes |
| `ssh_key_name` | SSH key name in DO | `sla-dashboard-key` | No |
| `domain_name` | Domain for SSL certificate | `""` | No |
| `environment` | Environment name | `prod` | No |
| `region` | DigitalOcean region | `nyc3` | No |
| `droplet_size` | Droplet size | `s-2vcpu-2gb` | No |

### Droplet Sizes

| Size | vCPUs | RAM | Disk | Price/Month | Use Case |
|------|-------|-----|------|-------------|----------|
| `s-1vcpu-1gb` | 1 | 1GB | 25GB | $6 | Development |
| `s-2vcpu-2gb` | 1 | 2GB | 50GB | $12 | Small Production |
| `s-4vcpu-8gb` | 4 | 8GB | 160GB | $48 | High Traffic |

### Regions

| Region | Location | Code |
|--------|----------|------|
| New York | USA East Coast | `nyc1`, `nyc3` |
| San Francisco | USA West Coast | `sfo3` |
| Amsterdam | Europe | `ams3` |
| London | Europe | `lon1` |
| Frankfurt | Europe | `fra1` |
| Singapore | Asia | `sgp1` |
| Bangalore | Asia | `blr1` |

## 🏗️ Infrastructure Components

### Basic Deployment

- **Droplet**: Ubuntu 22.04 with SLA Dashboard
- **Floating IP**: Static IP address
- **Firewall**: SSH, HTTP, HTTPS access
- **SSH Key**: Secure access

### Production Deployment (`environment = "prod"`)

Additional components:
- **Load Balancer**: High availability and SSL termination
- **Database**: Managed PostgreSQL cluster
- **Volume**: Persistent data storage

### Optional Components

- **VPC**: Network isolation
- **Domain**: DNS management
- **SSL Certificate**: Automatic HTTPS

## 🔧 Management Commands

### View Infrastructure

```bash
# Show current state
terraform show

# List resources
terraform state list

# Show outputs
terraform output
```

### Update Infrastructure

```bash
# Plan changes
terraform plan

# Apply changes
terraform apply

# Target specific resource
terraform apply -target=digitalocean_droplet.sla_dashboard
```

### Destroy Infrastructure

```bash
# Plan destruction
terraform plan -destroy

# Destroy all resources
terraform destroy

# Destroy specific resource
terraform destroy -target=digitalocean_droplet.sla_dashboard
```

## 📊 Monitoring and Maintenance

### Access Droplet

```bash
# SSH to droplet
ssh root@$(terraform output -raw floating_ip)

# Check application status
ssh root@$(terraform output -raw floating_ip) "systemctl status sla-dashboard"
```

### View Logs

```bash
# Deployment logs
ssh root@$(terraform output -raw floating_ip) "tail -f /var/log/sla-dashboard-deployment.log"

# Application logs
ssh root@$(terraform output -raw floating_ip) "journalctl -u sla-dashboard -f"
```

### Health Checks

```bash
# Application health
curl $(terraform output -raw health_check_url)

# Infrastructure status
terraform refresh
```

## 🔒 Security Features

### Automatic Configuration

- **Firewall**: UFW with minimal required ports
- **Fail2ban**: Intrusion prevention
- **Auto Updates**: Security patches
- **SSL/TLS**: Let's Encrypt certificates

### Manual Security Hardening

```bash
# Connect to droplet
ssh root@$(terraform output -raw floating_ip)

# Change SSH port (optional)
sed -i 's/#Port 22/Port 2222/' /etc/ssh/sshd_config
systemctl restart ssh

# Update firewall
ufw allow 2222
ufw delete allow OpenSSH

# Disable root login (after setting up user)
sed -i 's/PermitRootLogin yes/PermitRootLogin no/' /etc/ssh/sshd_config
systemctl restart ssh
```

## 🚨 Troubleshooting

### Common Issues

#### Terraform Init Fails

```bash
# Clear cache and retry
rm -rf .terraform
terraform init
```

#### API Token Issues

```bash
# Test token
curl -X GET \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $DO_TOKEN" \
  "https://api.digitalocean.com/v2/account"
```

#### SSH Key Issues

```bash
# Verify key format
ssh-keygen -l -f ~/.ssh/id_rsa.pub

# Test SSH connection
ssh -i ~/.ssh/id_rsa root@DROPLET_IP
```

#### Deployment Fails

```bash
# Check cloud-init logs
ssh root@DROPLET_IP "tail -f /var/log/cloud-init-output.log"

# Check deployment logs
ssh root@DROPLET_IP "tail -f /var/log/sla-dashboard-deployment.log"

# Manual deployment
ssh root@DROPLET_IP
cd /tmp
git clone https://github.com/BalrogEG/sla-dashboard.git
cd sla-dashboard
./deploy.sh
```

### Recovery Procedures

#### Restore from Snapshot

```bash
# Create snapshot before changes
doctl compute droplet-action snapshot $(terraform output -raw droplet_id) --snapshot-name "backup-$(date +%Y%m%d)"

# Restore from snapshot (via DigitalOcean control panel)
```

#### Rebuild Infrastructure

```bash
# Destroy and recreate
terraform destroy
terraform apply
```

## 💰 Cost Optimization

### Estimated Monthly Costs

| Configuration | Components | Monthly Cost |
|---------------|------------|--------------|
| Development | 1 Droplet (s-1vcpu-1gb) | $6 |
| Small Production | 1 Droplet (s-2vcpu-2gb) + Floating IP | $12 |
| High Availability | Load Balancer + 2 Droplets + Database | $100+ |

### Cost Saving Tips

1. **Use snapshots** instead of keeping multiple droplets
2. **Destroy development** environments when not in use
3. **Monitor usage** with DigitalOcean monitoring
4. **Right-size droplets** based on actual usage

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
# .github/workflows/deploy.yml
name: Deploy to DigitalOcean
on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      
      - name: Setup Terraform
        uses: hashicorp/setup-terraform@v2
        
      - name: Terraform Init
        run: terraform init
        working-directory: terraform
        
      - name: Terraform Plan
        run: terraform plan
        working-directory: terraform
        env:
          TF_VAR_do_token: ${{ secrets.DO_TOKEN }}
          TF_VAR_ssh_public_key: ${{ secrets.SSH_PUBLIC_KEY }}
          
      - name: Terraform Apply
        run: terraform apply -auto-approve
        working-directory: terraform
        env:
          TF_VAR_do_token: ${{ secrets.DO_TOKEN }}
          TF_VAR_ssh_public_key: ${{ secrets.SSH_PUBLIC_KEY }}
```

## 📞 Support

- **Terraform Documentation**: [terraform.io](https://terraform.io)
- **DigitalOcean API**: [docs.digitalocean.com](https://docs.digitalocean.com)
- **SLA Dashboard**: [GitHub Repository](https://github.com/BalrogEG/sla-dashboard)

---

**Quick Deploy**: `terraform init && terraform apply`  
**Estimated Time**: 5-10 minutes  
**Monthly Cost**: Starting at $6/month

