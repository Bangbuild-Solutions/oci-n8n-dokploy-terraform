# ====
# Oracle Cloud Infrastructure Terraform Configuration
# Secure Dokploy Deployment on Always Free Ampere ARM Instance
# - Dokploy Dashboard: Private (Tailscale only) on port 3000
# - Cloudflare Tunnel: Available for applications
# - Traefik: Handles routing on ports 80/443 (accessed via Cloudflare Tunnel only)
# ====

terraform {
  required_version = ">= 1.0"
  required_providers {
    oci = {
      source  = "oracle/oci"
      version = "~> 6.37"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.1"
    }
    external = {
      source  = "hashicorp/external"
      version = "~> 2.2"
    }
  }
}

# ====
# Fetch secrets from Bitwarden
# ====
data "external" "bitwarden_secrets" {
  program = ["bash", "${path.module}/get-secrets.sh"]
}

# ====
# Write private key to file for OCI provider
# ====
resource "local_sensitive_file" "oci_private_key" {
  content         = data.external.bitwarden_secrets.result.oci_private_key
  filename        = "${path.module}/.oci_private_key.pem"
  file_permission = "0600"
}

# Configure the Oracle Cloud Infrastructure Provider
provider "oci" {
  tenancy_ocid = data.external.bitwarden_secrets.result.tenancy_ocid
  user_ocid    = data.external.bitwarden_secrets.result.user_ocid
  fingerprint  = data.external.bitwarden_secrets.result.fingerprint
  private_key  = data.external.bitwarden_secrets.result.oci_private_key
  region       = var.region
}

# Define local values
locals {
  os_version_to_codename = {
    "24.04" = "noble"
    "22.04" = "jammy"
    "20.04" = "focal"
  }
  version_codename = lookup(local.os_version_to_codename, var.instance_os_version, "noble")
}

# Data sources for availability domains and images
data "oci_identity_availability_domains" "ads" {
  compartment_id = data.external.bitwarden_secrets.result.tenancy_ocid
}

data "oci_core_images" "ubuntu_images" {
  compartment_id           = var.compartment_ocid
  operating_system         = "Canonical Ubuntu"
  operating_system_version = var.instance_os_version
  shape                    = "VM.Standard.A1.Flex"
  sort_by                  = "TIMECREATED"
  sort_order               = "DESC"
}

# Create Virtual Cloud Network (VCN)
resource "oci_core_vcn" "dokploy_vcn" {
  compartment_id = var.compartment_ocid
  display_name   = "dokploy-vcn"
  cidr_blocks    = ["10.0.0.0/16"]
  dns_label      = "dokployvcn"
}

# Create Internet Gateway
resource "oci_core_internet_gateway" "dokploy_igw" {
  compartment_id = var.compartment_ocid
  display_name   = "dokploy-internet-gateway"
  vcn_id         = oci_core_vcn.dokploy_vcn.id
  enabled        = true
}

# Create Route Table for Public Subnet
resource "oci_core_route_table" "dokploy_public_rt" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.dokploy_vcn.id
  display_name   = "dokploy-public-route-table"

  route_rules {
    destination       = "0.0.0.0/0"
    network_entity_id = oci_core_internet_gateway.dokploy_igw.id
  }
}

# Create Security List for Dokploy Instance
# SECURITY: Only Tailscale traffic allowed for SSH and Dokploy dashboard
# Applications accessed via Cloudflare Tunnel (outbound only, no inbound ports needed)
resource "oci_core_security_list" "dokploy_security_list" {
  compartment_id = var.compartment_ocid
  vcn_id         = oci_core_vcn.dokploy_vcn.id
  display_name   = "dokploy-security-list"

  # Allow all outbound traffic
  egress_security_rules {
    destination = "0.0.0.0/0"
    protocol    = "all"
  }

  # SSH: Restricted to Tailscale network only
  ingress_security_rules {
    protocol = "6" # TCP
    source   = "100.64.0.0/10"
    tcp_options {
      min = 22
      max = 22
    }
    description = "SSH restricted to Tailscale network (100.64.0.0/10)"
  }

  # Tailscale UDP: Required for Tailscale mesh networking
  ingress_security_rules {
    protocol = "17" # UDP
    source   = "0.0.0.0/0"
    udp_options {
      min = 41641
      max = 41641
    }
    description = "Tailscale mesh networking"
  }

  # NOTE: No HTTP/HTTPS ports needed at cloud firewall level
  # Traefik binds to ports 80/443 on localhost
  # Cloudflare Tunnel creates outbound connections, doesn't need inbound ports
  # Applications are accessed through the tunnel, not direct ports
  # Dokploy dashboard (port 3000) is accessed via Tailscale only
}

# Create Public Subnet
resource "oci_core_subnet" "dokploy_public_subnet" {
  compartment_id    = var.compartment_ocid
  vcn_id            = oci_core_vcn.dokploy_vcn.id
  display_name      = "dokploy-public-subnet"
  cidr_block        = "10.0.1.0/24"
  dns_label         = "dokploysubnet"
  route_table_id    = oci_core_route_table.dokploy_public_rt.id
  security_list_ids = [oci_core_security_list.dokploy_security_list.id]
  dhcp_options_id   = oci_core_vcn.dokploy_vcn.default_dhcp_options_id
}

# Generate cloud-init configuration
locals {
  # Generate JSON for multi-admin users
  admin_users_json = jsonencode({
    users = [
      for user in var.admin_users : {
        username = user.username
        ssh_key  = user.ssh_key
        disabled = user.disabled
      } if !user.disabled
    ]
  })

  cloud_init_config = templatefile("${path.module}/cloud-init.yaml.tpl", {
    # Secrets from Bitwarden
    tailscale_auth_key = data.external.bitwarden_secrets.result.tailscale_auth_key
    cf_tunnel_token    = data.external.bitwarden_secrets.result.cf_tunnel_token

    # System configuration
    tailscale_hostname   = var.tailscale_hostname
    timezone             = var.timezone
    docker_device        = var.docker_device
    create_docker_volume = var.create_docker_volume
    version_codename     = local.version_codename

    # User management (legacy single-user)
    bootstrap_ssh_public_key    = var.bootstrap_ssh_public_key
    create_primary_user         = var.create_primary_user
    primary_username            = var.primary_username
    primary_user_ssh_public_key = var.primary_user_ssh_public_key
    disable_default_ubuntu_user = var.disable_default_ubuntu_user
    
    # User management (multi-admin users)
    admin_users_json = local.admin_users_json
  })
}

# Create Dokploy Compute Instance
resource "oci_core_instance" "dokploy_instance" {
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = var.instance_display_name
  shape               = "VM.Standard.A1.Flex"

  shape_config {
    ocpus         = 4
    memory_in_gbs = 24
  }

  create_vnic_details {
    subnet_id        = oci_core_subnet.dokploy_public_subnet.id
    display_name     = "dokploy-vnic"
    assign_public_ip = true
    hostname_label   = "dokploy"
  }

  source_details {
    source_type             = "image"
    source_id               = data.oci_core_images.ubuntu_images.images[0].id
    boot_volume_size_in_gbs = var.boot_volume_size
  }

  metadata = {
    user_data = base64encode(local.cloud_init_config)
  }
}

# Create and attach block volume (optional)
resource "oci_core_volume" "dokploy_docker_volume" {
  count               = var.create_docker_volume ? 1 : 0
  availability_domain = data.oci_identity_availability_domains.ads.availability_domains[0].name
  compartment_id      = var.compartment_ocid
  display_name        = "dokploy-docker-volume"
  size_in_gbs         = var.docker_volume_size
}

resource "oci_core_volume_attachment" "dokploy_docker_volume_attachment" {
  count           = var.create_docker_volume ? 1 : 0
  attachment_type = "paravirtualized"
  instance_id     = oci_core_instance.dokploy_instance.id
  volume_id       = oci_core_volume.dokploy_docker_volume[0].id
  device          = var.docker_device
}

# Outputs
output "instance_public_ip" {
  description = "Public IP address of the Dokploy instance"
  value       = oci_core_instance.dokploy_instance.public_ip
}

output "dokploy_dashboard_url" {
  description = "Dokploy dashboard URL (Tailscale private network only)"
  value       = "http://${var.tailscale_hostname}:3000"
}

output "ssh_connection_command" {
  description = "SSH connection command via Tailscale"
  value       = "ssh ${var.create_primary_user ? var.primary_username : "ubuntu"}@${var.tailscale_hostname}"
}

output "tailscale_hostname" {
  description = "Tailscale hostname for the server"
  value       = var.tailscale_hostname
}

output "cloudflare_tunnel_status" {
  description = "Cloudflare Tunnel configuration status"
  value       = "Installed and running. Configure public routes in Cloudflare dashboard for your applications."
}

output "traefik_info" {
  description = "Traefik reverse proxy information"
  value       = "Traefik is running on ports 80/443 (localhost). Access applications via Cloudflare Tunnel routing to http://localhost:80"
}

# Create a local file with connection details
resource "local_file" "connection_info" {
  content = <<-EOT
    # Dokploy Server Connection Information
    # Generated: ${formatdate("YYYY-MM-DD hh:mm:ss ZZZ", timestamp())}
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    🔒 SECURE DEPLOYMENT
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

    ## Instance Details
    Public IP:          ${oci_core_instance.dokploy_instance.public_ip}
    Tailscale Hostname: ${var.tailscale_hostname}
    
    ## Dokploy Dashboard (PRIVATE - Tailscale Only)
    URL: http://${var.tailscale_hostname}:3000
    
    ⚠️  Dokploy dashboard is NOT publicly accessible.
    You MUST be connected to Tailscale to access it.
    
    ## Traefik Reverse Proxy
    Ports: 80 (HTTP) and 443 (HTTPS) on localhost
    Access: Via Cloudflare Tunnel only (no direct public access)
    
    ## Cloudflare Tunnel (For Your Applications)
    Status: Installed and running
    Routes: None configured (by design)
    
    To expose applications:
    1. Deploy app in Dokploy (configure domain in Traefik settings)
    2. Go to Cloudflare Zero Trust dashboard
    3. Add public hostname route: yourdomain.com → http://localhost:80
    4. Traefik will route based on the domain name
    
    ⚠️  DO NOT create a route to localhost:3000 (Dokploy dashboard)
    
    ## SSH Access (Tailscale Only)
    Command: ssh ${var.create_primary_user ? var.primary_username : "ubuntu"}@${var.tailscale_hostname}
    
    ## First-Time Setup
    1. Connect to Tailscale on your local machine
    2. Open http://${var.tailscale_hostname}:3000 in your browser
    3. Create your admin account IMMEDIATELY
    4. Deploy applications in Dokploy
    5. Configure Cloudflare routes for public apps
    
    ## Monitoring
    Deployment log:
      ssh ${var.create_primary_user ? var.primary_username : "ubuntu"}@${var.tailscale_hostname}
      tail -f /var/log/dokploy-deployment.log
    
    Access info:
      cat /root/dokploy-access-info.txt
    
    ## Architecture
    - Dokploy Dashboard: Private (Tailscale only) - Port 3000
    - Traefik: Localhost only - Ports 80/443
    - SSH: Private (Tailscale only)
    - Applications: Can be public (via Cloudflare Tunnel → Traefik)
    - Cloudflare Tunnel: Ready, no routes configured
    
    ## Security Model
    - No inbound ports 80/443 at firewall level
    - All public traffic goes through Cloudflare Tunnel (outbound connection)
    - Traefik handles routing based on domain names
    - Dashboard accessible only via Tailscale private network
    
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
  EOT

  filename = "${path.module}/dokploy-connection-info.txt"
}