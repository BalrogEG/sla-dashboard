# DigitalOcean Terraform Configuration for SLA Dashboard
# This file creates the infrastructure needed for SLA Dashboard deployment

terraform {
  required_version = ">= 1.0"
  required_providers {
    digitalocean = {
      source  = "digitalocean/digitalocean"
      version = "~> 2.0"
    }
  }
}

# Variables
variable "do_token" {
  description = "DigitalOcean API token"
  type        = string
  sensitive   = true
}

variable "ssh_key_name" {
  description = "Name of the SSH key in DigitalOcean"
  type        = string
  default     = "sla-dashboard-key"
}

variable "ssh_public_key" {
  description = "SSH public key content"
  type        = string
}

variable "domain_name" {
  description = "Domain name for the SLA Dashboard"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
  default     = "prod"
}

variable "region" {
  description = "DigitalOcean region"
  type        = string
  default     = "nyc3"
}

variable "droplet_size" {
  description = "Droplet size"
  type        = string
  default     = "s-2vcpu-2gb"
}

# Provider configuration
provider "digitalocean" {
  token = var.do_token
}

# SSH Key
resource "digitalocean_ssh_key" "sla_dashboard" {
  name       = var.ssh_key_name
  public_key = var.ssh_public_key
}

# VPC (Optional - for better network isolation)
resource "digitalocean_vpc" "sla_dashboard" {
  name     = "sla-dashboard-${var.environment}"
  region   = var.region
  ip_range = "10.10.0.0/24"
}

# Droplet for SLA Dashboard
resource "digitalocean_droplet" "sla_dashboard" {
  image    = "ubuntu-22-04-x64"
  name     = "sla-dashboard-${var.environment}"
  region   = var.region
  size     = var.droplet_size
  vpc_uuid = digitalocean_vpc.sla_dashboard.id
  
  ssh_keys = [digitalocean_ssh_key.sla_dashboard.id]
  
  tags = [
    "sla-dashboard",
    var.environment,
    "web-server",
    "monitoring"
  ]
  
  # Cloud-init user data for automatic deployment
  user_data = templatefile("${path.module}/cloud-init.yml", {
    domain_name = var.domain_name
  })
  
  # Ensure the droplet is created before trying to configure DNS
  lifecycle {
    create_before_destroy = true
  }
}

# Floating IP (Optional - for easier maintenance)
resource "digitalocean_floating_ip" "sla_dashboard" {
  droplet = digitalocean_droplet.sla_dashboard.id
  region  = var.region
}

# Domain (if provided)
resource "digitalocean_domain" "sla_dashboard" {
  count = var.domain_name != "" ? 1 : 0
  name  = var.domain_name
}

# DNS A record pointing to the floating IP
resource "digitalocean_record" "sla_dashboard_a" {
  count  = var.domain_name != "" ? 1 : 0
  domain = digitalocean_domain.sla_dashboard[0].name
  type   = "A"
  name   = "@"
  value  = digitalocean_floating_ip.sla_dashboard.ip_address
  ttl    = 300
}

# DNS CNAME record for www subdomain
resource "digitalocean_record" "sla_dashboard_www" {
  count  = var.domain_name != "" ? 1 : 0
  domain = digitalocean_domain.sla_dashboard[0].name
  type   = "CNAME"
  name   = "www"
  value  = "@"
  ttl    = 300
}

# Load Balancer (Optional - for high availability)
resource "digitalocean_loadbalancer" "sla_dashboard" {
  count = var.environment == "prod" ? 1 : 0
  
  name   = "sla-dashboard-lb-${var.environment}"
  region = var.region
  
  forwarding_rule {
    entry_protocol  = "http"
    entry_port      = 80
    target_protocol = "http"
    target_port     = 80
  }
  
  forwarding_rule {
    entry_protocol  = "https"
    entry_port      = 443
    target_protocol = "http"
    target_port     = 80
    tls_passthrough = false
  }
  
  healthcheck {
    protocol               = "http"
    port                   = 80
    path                   = "/health"
    check_interval_seconds = 10
    response_timeout_seconds = 5
    unhealthy_threshold    = 3
    healthy_threshold      = 2
  }
  
  droplet_ids = [digitalocean_droplet.sla_dashboard.id]
  
  # SSL certificate
  redirect_http_to_https = true
}

# Firewall
resource "digitalocean_firewall" "sla_dashboard" {
  name = "sla-dashboard-${var.environment}"
  
  droplet_ids = [digitalocean_droplet.sla_dashboard.id]
  
  # SSH access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "22"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # HTTP access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "80"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # HTTPS access
  inbound_rule {
    protocol         = "tcp"
    port_range       = "443"
    source_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  # Allow all outbound traffic
  outbound_rule {
    protocol              = "tcp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  outbound_rule {
    protocol              = "udp"
    port_range            = "1-65535"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
  
  outbound_rule {
    protocol              = "icmp"
    destination_addresses = ["0.0.0.0/0", "::/0"]
  }
}

# Volume for data persistence (Optional)
resource "digitalocean_volume" "sla_dashboard_data" {
  region                  = var.region
  name                    = "sla-dashboard-data-${var.environment}"
  size                    = 10
  initial_filesystem_type = "ext4"
  description             = "SLA Dashboard data volume"
}

# Attach volume to droplet
resource "digitalocean_volume_attachment" "sla_dashboard_data" {
  droplet_id = digitalocean_droplet.sla_dashboard.id
  volume_id  = digitalocean_volume.sla_dashboard_data.id
}

# Database (Optional - for production use)
resource "digitalocean_database_cluster" "sla_dashboard" {
  count = var.environment == "prod" ? 1 : 0
  
  name       = "sla-dashboard-db-${var.environment}"
  engine     = "pg"
  version    = "15"
  size       = "db-s-1vcpu-1gb"
  region     = var.region
  node_count = 1
  
  tags = ["sla-dashboard", var.environment, "database"]
}

# Database user
resource "digitalocean_database_user" "sla_dashboard" {
  count      = var.environment == "prod" ? 1 : 0
  cluster_id = digitalocean_database_cluster.sla_dashboard[0].id
  name       = "sla_dashboard_user"
}

# Database
resource "digitalocean_database_db" "sla_dashboard" {
  count      = var.environment == "prod" ? 1 : 0
  cluster_id = digitalocean_database_cluster.sla_dashboard[0].id
  name       = "sla_dashboard"
}

# Outputs
output "droplet_ip" {
  description = "Public IP address of the droplet"
  value       = digitalocean_droplet.sla_dashboard.ipv4_address
}

output "floating_ip" {
  description = "Floating IP address"
  value       = digitalocean_floating_ip.sla_dashboard.ip_address
}

output "domain_name" {
  description = "Domain name (if configured)"
  value       = var.domain_name != "" ? var.domain_name : "Not configured"
}

output "ssh_command" {
  description = "SSH command to connect to the droplet"
  value       = "ssh root@${digitalocean_floating_ip.sla_dashboard.ip_address}"
}

output "dashboard_url" {
  description = "URL to access the SLA Dashboard"
  value = var.domain_name != "" ? "https://${var.domain_name}" : "http://${digitalocean_floating_ip.sla_dashboard.ip_address}"
}

output "health_check_url" {
  description = "Health check URL"
  value = var.domain_name != "" ? "https://${var.domain_name}/health" : "http://${digitalocean_floating_ip.sla_dashboard.ip_address}/health"
}

output "load_balancer_ip" {
  description = "Load balancer IP (if created)"
  value = var.environment == "prod" ? digitalocean_loadbalancer.sla_dashboard[0].ip : "Not created"
}

output "database_connection" {
  description = "Database connection details (if created)"
  value = var.environment == "prod" ? {
    host     = digitalocean_database_cluster.sla_dashboard[0].host
    port     = digitalocean_database_cluster.sla_dashboard[0].port
    database = digitalocean_database_db.sla_dashboard[0].name
    user     = digitalocean_database_user.sla_dashboard[0].name
  } : "Not created"
  sensitive = true
}

