# Configuration Examples

This document provides practical examples for different use cases of the Terraform Dokploy deployment project.

---

## Table of Contents

1. [Single User Setup](#single-user-setup)
2. [Multi-Admin User Setup](#multi-admin-user-setup)
3. [Team Collaboration](#team-collaboration)
4. [Temporarily Disable User](#temporarily-disable-user)
5. [Migration from Single to Multi-User](#migration-from-single-to-multi-user)
6. [Development vs. Production](#development-vs-production)

---

## Single User Setup

**Use Case**: Personal project, single administrator

### terraform.tfvars

```hcl
# OCI Configuration
region           = "us-ashburn-1"
compartment_ocid = "ocid1.compartment.oc1..your-compartment-ocid"

# SSH Configuration
bootstrap_ssh_public_key = "ssh-ed25519 AAAAC3... bootstrap@example.com"

# Tailscale Configuration
tailscale_hostname = "my-dokploy"

# System Configuration
timezone = "America/New_York"

# Storage Configuration
create_docker_volume = false
boot_volume_size     = 50

# Single User Configuration
create_primary_user         = true
primary_username            = "john"
primary_user_ssh_public_key = "ssh-ed25519 AAAAC3... john@example.com"
disable_default_ubuntu_user = true
```

**Result**: One admin user (`john`) with full access, ubuntu user disabled.

---

## Multi-Admin User Setup

**Use Case**: Multiple administrators, each with their own SSH key

### terraform.tfvars

```hcl
# OCI Configuration
region           = "us-ashburn-1"
compartment_ocid = "ocid1.compartment.oc1..your-compartment-ocid"

# SSH Configuration
bootstrap_ssh_public_key = "ssh-ed25519 AAAAC3... bootstrap@example.com"

# Tailscale Configuration
tailscale_hostname = "team-dokploy"

# System Configuration
timezone = "America/New_York"

# Storage Configuration
create_docker_volume = false
boot_volume_size     = 50

# Multi-Admin User Configuration
admin_users = [
  {
    username = "alice"
    ssh_key  = "ssh-ed25519 AAAAC3... alice@example.com"
  },
  {
    username = "bob"
    ssh_key  = "ssh-ed25519 AAAAC3... bob@example.com"
  },
  {
    username = "charlie"
    ssh_key  = "ssh-ed25519 AAAAC3... charlie@example.com"
  }
]

disable_default_ubuntu_user = true
```

**Result**: Three admin users (`alice`, `bob`, `charlie`), each with their own SSH key, ubuntu user disabled.

---

## Team Collaboration

**Use Case**: Development team with shared and individual access

### terraform.tfvars

```hcl
# OCI Configuration
region           = "us-ashburn-1"
compartment_ocid = "ocid1.compartment.oc1..your-compartment-ocid"

# SSH Configuration
bootstrap_ssh_public_key = "ssh-ed25519 AAAAC3... bootstrap@example.com"

# Tailscale Configuration
tailscale_hostname = "company-dokploy"

# System Configuration
timezone = "UTC"

# Storage Configuration
create_docker_volume = true  # Separate volume for Docker data
docker_volume_size   = 150
boot_volume_size     = 50

# Multi-Admin User Configuration
admin_users = [
  {
    username = "devops"
    ssh_key  = "ssh-ed25519 AAAAC3... devops@company.com"
  },
  {
    username = "alice"
    ssh_key  = "ssh-ed25519 AAAAC3... alice@company.com"
  },
  {
    username = "bob"
    ssh_key  = "ssh-ed25519 AAAAC3... bob@company.com"
  },
  {
    username = "charlie"
    ssh_key  = "ssh-ed25519 AAAAC3... charlie@company.com"
  }
]

disable_default_ubuntu_user = true
```

**Result**: 
- One shared `devops` account (team key)
- Three individual accounts (`alice`, `bob`, `charlie`)
- Separate Docker volume for better performance
- Ubuntu user disabled

**Access**:
```bash
# Team access
ssh devops@company-dokploy

# Individual access
ssh alice@company-dokploy
ssh bob@company-dokploy
ssh charlie@company-dokploy
```

---

## Temporarily Disable User

**Use Case**: Team member on vacation or temporarily offboarded

### terraform.tfvars

```hcl
# ... (other configuration same as above)

# Multi-Admin User Configuration
admin_users = [
  {
    username = "alice"
    ssh_key  = "ssh-ed25519 AAAAC3... alice@example.com"
  },
  {
    username = "bob"
    ssh_key  = "ssh-ed25519 AAAAC3... bob@example.com"
    disabled = true  # Bob on vacation - temporarily disabled
  },
  {
    username = "charlie"
    ssh_key  = "ssh-ed25519 AAAAC3... charlie@example.com"
  }
]

disable_default_ubuntu_user = true
```

**Result**: 
- `alice` and `charlie` can access the server
- `bob` account is skipped during creation (not created or updated)
- When Bob returns, set `disabled = false` and run `terraform apply`

**Note**: Setting `disabled = true` prevents the user from being created/updated. It does NOT delete an existing user. To re-enable, set `disabled = false` and apply.

---

## Migration from Single to Multi-User

**Use Case**: Upgrading from single-user to multi-user setup

### Step 1: Current Configuration (v3.0.1)

```hcl
# terraform.tfvars (before)
create_primary_user         = true
primary_username            = "alice"
primary_user_ssh_public_key = "ssh-ed25519 AAAAC3... alice@example.com"
disable_default_ubuntu_user = true
```

### Step 2: New Configuration (v3.1.0)

```hcl
# terraform.tfvars (after)

# Comment out or remove old variables
# create_primary_user         = true
# primary_username            = "alice"
# primary_user_ssh_public_key = "ssh-ed25519 AAAAC3... alice@example.com"

# Add new admin_users variable
admin_users = [
  {
    username = "alice"  # Keep existing user
    ssh_key  = "ssh-ed25519 AAAAC3... alice@example.com"
  },
  {
    username = "bob"    # Add new user
    ssh_key  = "ssh-ed25519 AAAAC3... bob@example.com"
  }
]

disable_default_ubuntu_user = true
```

### Step 3: Apply Changes

```bash
# Review changes
terraform plan

# Apply changes
terraform apply

# Verify
ssh alice@<hostname>
ssh bob@<hostname>

# Run verification script
sudo ./verify-installation.sh
```

**Result**: 
- `alice` account remains functional (same username, same key)
- `bob` account is created
- Both users have sudo and Docker access

---

## Development vs. Production

### Development Setup

**Use Case**: Testing, development, frequent changes

```hcl
# terraform.tfvars (development)
region           = "us-ashburn-1"
compartment_ocid = "ocid1.compartment.oc1..dev-compartment-ocid"

bootstrap_ssh_public_key = "ssh-ed25519 AAAAC3... dev@example.com"
tailscale_hostname       = "dokploy-dev"
timezone                 = "UTC"

# Minimal storage for dev
create_docker_volume = false
boot_volume_size     = 50

# Single user for dev
create_primary_user         = true
primary_username            = "devuser"
primary_user_ssh_public_key = "ssh-ed25519 AAAAC3... dev@example.com"
disable_default_ubuntu_user = false  # Keep ubuntu user for recovery
```

### Production Setup

**Use Case**: Production deployment, team access, high availability

```hcl
# terraform.tfvars (production)
region           = "us-phoenix-1"
compartment_ocid = "ocid1.compartment.oc1..prod-compartment-ocid"

bootstrap_ssh_public_key = "ssh-ed25519 AAAAC3... bootstrap@company.com"
tailscale_hostname       = "dokploy-prod"
timezone                 = "America/New_York"

# Separate Docker volume for production
create_docker_volume = true
docker_volume_size   = 150
boot_volume_size     = 50

# Multi-admin for production
admin_users = [
  {
    username = "ops"
    ssh_key  = "ssh-ed25519 AAAAC3... ops@company.com"
  },
  {
    username = "alice"
    ssh_key  = "ssh-ed25519 AAAAC3... alice@company.com"
  },
  {
    username = "bob"
    ssh_key  = "ssh-ed25519 AAAAC3... bob@company.com"
  }
]

disable_default_ubuntu_user = true  # Disable ubuntu in production
```

**Key Differences**:
- **Development**: Single user, no separate Docker volume, ubuntu user kept for recovery
- **Production**: Multiple users, separate Docker volume, ubuntu user disabled for security

---

## Advanced: Role-Based Access

**Use Case**: Different users for different purposes

### terraform.tfvars

```hcl
# ... (other configuration)

admin_users = [
  {
    username = "deploy"
    ssh_key  = "ssh-ed25519 AAAAC3... deploy@company.com"
  },
  {
    username = "monitor"
    ssh_key  = "ssh-ed25519 AAAAC3... monitor@company.com"
  },
  {
    username = "emergency"
    ssh_key  = "ssh-ed25519 AAAAC3... emergency@company.com"
  }
]

disable_default_ubuntu_user = true
```

**Usage**:
- `deploy`: Used by CI/CD pipeline for deployments
- `monitor`: Used by monitoring tools (Prometheus, Grafana)
- `emergency`: Emergency access for on-call engineers

**Note**: All users have the same permissions (sudo + docker). For fine-grained access control, you would need to customize the cloud-init scripts.

---

## Common Patterns

### Pattern 1: Minimal Setup (Personal)

```hcl
create_primary_user         = true
primary_username            = "john"
primary_user_ssh_public_key = "ssh-ed25519 AAAAC3..."
disable_default_ubuntu_user = true
```

### Pattern 2: Small Team (2-3 people)

```hcl
admin_users = [
  {username = "alice", ssh_key = "ssh-ed25519 AAAAC3..."},
  {username = "bob", ssh_key = "ssh-ed25519 AAAAC3..."}
]
disable_default_ubuntu_user = true
```

### Pattern 3: Larger Team (4-10 people)

```hcl
admin_users = [
  {username = "ops", ssh_key = "ssh-ed25519 AAAAC3..."},  # Shared
  {username = "alice", ssh_key = "ssh-ed25519 AAAAC3..."},
  {username = "bob", ssh_key = "ssh-ed25519 AAAAC3..."},
  {username = "charlie", ssh_key = "ssh-ed25519 AAAAC3..."},
  {username = "diana", ssh_key = "ssh-ed25519 AAAAC3..."}
]
disable_default_ubuntu_user = true
```

---

## Tips

### Generating SSH Keys

```bash
# Generate a new ED25519 key (recommended)
ssh-keygen -t ed25519 -C "your_email@example.com"

# View public key
cat ~/.ssh/id_ed25519.pub
```

### Testing SSH Access

```bash
# Test with verbose output
ssh -v username@hostname

# Test with specific key
ssh -i ~/.ssh/id_ed25519 username@hostname
```

### Verification

```bash
# After deployment, verify all users
sudo ./verify-installation.sh

# Check specific user
id alice
groups alice
sudo -l -U alice
```

---

## Troubleshooting

### User Not Created

**Check**:
1. Is `disabled = true`? Remove or set to `false`
2. Is username valid? Check validation rules
3. Is SSH key valid? Must start with `ssh-`

### Cannot SSH

**Check**:
1. Connected to Tailscale? `tailscale status`
2. SSH key correct? `cat ~/.ssh/id_ed25519.pub`
3. User created? `id username`
4. SSH key added? `sudo cat /home/username/.ssh/authorized_keys`

### User Has No Sudo Access

**Check**:
```bash
# Check sudoers file
sudo cat /etc/sudoers.d/username

# Check groups
groups username

# Should see: username sudo docker
```

---

## Summary

- **Single User**: Use `create_primary_user` for simple setups
- **Multi-User**: Use `admin_users` for teams
- **Backward Compatible**: Both methods work
- **Precedence**: `admin_users` takes precedence if defined
- **Validation**: All usernames and SSH keys are validated
- **Security**: Each user has individual SSH key

For more information, see the main [README.md](README.md).
