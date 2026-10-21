# ====
# Terraform Variables for Secure Dokploy Deployment
# Dokploy accessible ONLY via Tailscale private network
# ====

# OCI Configuration (Non-Sensitive)
variable "region" {
  description = "The OCI region where resources will be created"
  type        = string
}

variable "compartment_ocid" {
  description = "The OCID of the compartment where resources will be created"
  type        = string
}

# SSH Configuration
variable "bootstrap_ssh_public_key" {
  description = "The temporary SSH public key for the initial 'ubuntu' user to bootstrap the system."
  type        = string
}

# Tailscale Configuration
variable "tailscale_hostname" {
  description = "The hostname to register with Tailscale. This enables 'ssh <hostname>' access."
  type        = string
  default     = "dokploy-server"
}

# System Configuration
variable "timezone" {
  description = "Server timezone (e.g., America/New_York, Europe/London, UTC)"
  type        = string
  default     = "UTC"
}

# Storage Configuration
variable "create_docker_volume" {
  description = "Whether to create an additional block volume for Docker data"
  type        = bool
  default     = true
}

variable "docker_volume_size" {
  description = "Size of the Docker data volume in GB (only used if create_docker_volume is true)"
  type        = number
  default     = 170

  validation {
    condition     = var.docker_volume_size >= 50 && var.docker_volume_size <= 200
    error_message = "Docker volume size must be between 50 and 200 GB. Note: Always Free total block volume capacity is 200 GB."
  }
}

variable "docker_device" {
  description = "Block device path for the attached Docker data volume (paravirtualized). Example: /dev/oracleoci/oraclevdb"
  type        = string
  default     = "/dev/oracleoci/oraclevdb"
}

# Instance Configuration
variable "instance_display_name" {
  description = "Display name for the compute instance"
  type        = string
  default     = "dokploy-server"
}

variable "boot_volume_size" {
  description = "Boot volume size in GB"
  type        = number
  default     = 30

  validation {
    condition     = var.boot_volume_size >= 20 && var.boot_volume_size <= 200
    error_message = "Boot volume size must be between 20 and 200 GB for Always Free tier."
  }
}

variable "instance_os_version" {
  description = "The operating system version for the instance image (e.g., 24.04, 22.04)."
  type        = string
  default     = "24.04"
}

# Primary User Configuration
variable "create_primary_user" {
  description = "Set to true to create a new primary user and optionally disable the default 'ubuntu' user."
  type        = bool
  default     = false
}

variable "primary_username" {
  description = "The username for the new permanent administrative user. Leave empty if create_primary_user is false. AVOID: admin, root, administrator, test, user."
  type        = string
  default     = ""

  validation {
    condition = var.primary_username == "" || (
      var.primary_username != "admin" &&
      var.primary_username != "root" &&
      var.primary_username != "administrator" &&
      var.primary_username != "test" &&
      var.primary_username != "user" &&
      length(var.primary_username) >= 3 &&
      can(regex("^[a-z][a-z0-9_-]*$", var.primary_username))
    )
    error_message = "Username must be at least 3 characters, start with a lowercase letter, contain only lowercase letters, numbers, hyphens, and underscores. FORBIDDEN usernames: admin, root, administrator, test, user (these cause conflicts or security issues)."
  }
}

variable "primary_user_ssh_public_key" {
  description = "The SSH public key for the new primary user. If left empty, the 'bootstrap_ssh_public_key' will be used."
  type        = string
  default     = ""
}

variable "disable_default_ubuntu_user" {
  description = "If creating a primary user, set this to true to lock the default 'ubuntu' user account for security."
  type        = bool
  default     = true
}



# Multi-Admin User Configuration
variable "admin_users" {
  description = <<-EOT
    List of admin users to create with sudo and Docker access.
    Each user must have a unique username and SSH public key.
    
    Example:
    admin_users = [
      {
        username = "alice"
        ssh_key  = "ssh-ed25519 AAAA..."
      },
      {
        username = "bob"
        ssh_key  = "ssh-ed25519 BBBB..."
      }
    ]
    
    Note: If admin_users is specified, it takes precedence over create_primary_user.
  EOT
  
  type = list(object({
    username = string
    ssh_key  = string
    disabled = optional(bool, false)
  }))
  
  default = []

  validation {
    condition     = length(var.admin_users) <= 10
    error_message = "Maximum 10 admin users allowed."
  }

  validation {
    condition = alltrue([
      for user in var.admin_users : (
        user.username != "admin" &&
        user.username != "root" &&
        user.username != "administrator" &&
        user.username != "test" &&
        user.username != "user" &&
        user.username != "ubuntu" &&
        length(user.username) >= 3 &&
        can(regex("^[a-z][a-z0-9_-]*$", user.username))
      )
    ])
    error_message = "Each username must be at least 3 characters, start with a lowercase letter, contain only lowercase letters, numbers, hyphens, and underscores. FORBIDDEN: admin, root, administrator, test, user, ubuntu."
  }

  validation {
    condition = alltrue([
      for user in var.admin_users : (
        length(user.ssh_key) > 0 &&
        can(regex("^ssh-(rsa|ed25519|ecdsa|dss) ", user.ssh_key))
      )
    ])
    error_message = "Each user must have a valid SSH public key starting with 'ssh-rsa', 'ssh-ed25519', 'ssh-ecdsa', or 'ssh-dss'."
  }

  validation {
    condition = length(var.admin_users) == length(distinct([for user in var.admin_users : user.username]))
    error_message = "Duplicate usernames detected. Each username must be unique."
  }
}

