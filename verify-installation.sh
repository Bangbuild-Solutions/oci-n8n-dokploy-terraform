#!/bin/bash
# ====
# Dokploy Installation Verification Script with Anonymized Logging
# Tests all features deployed by cloud-init to ensure proper setup
# Produces two logs: verification.log (full) and verification-safe.log (anonymized)
# ====

# Log file paths
FULL_LOG="verification.log"
SAFE_LOG="verification-safe.log"

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: This script must be run as root (use sudo)"
    echo "Usage: sudo ./verify-installation.sh"
    exit 1
fi

# Enable debug mode if -d flag is passed
if [[ "${1:-}" == "-d" ]]; then
    set -x
    DEBUG=true
else
    DEBUG=false
fi

# Don't exit on error - we want to continue testing even if some commands fail
set -uo pipefail

# Trap errors and continue
trap 'echo "Error at line $LINENO. Continuing..." >&2 | tee -a "$FULL_LOG"' ERR

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Counters
PASSED=0
FAILED=0
WARNINGS=0

# Collect sensitive data for anonymization
declare -A SENSITIVE_DATA
SENSITIVE_DATA[hostname]=$(hostname 2>/dev/null || echo "unknown")
SENSITIVE_DATA[public_ip]=""
SENSITIVE_DATA[tailscale_ip]=""
SENSITIVE_DATA[tailscale_hostname]=""

# Helper function to log to both console and file
log_output() {
    # Strip ANSI color codes for log files
    local clean_output=$(echo -e "$1" | sed 's/\x1b\[[0-9;]*m//g')
    echo -e "$1"  # To console with colors
    echo "$clean_output" >> "$FULL_LOG"
}

# Helper functions
print_header() {
    log_output ""
    log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    log_output "${BLUE}$1${NC}"
    log_output "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_test() {
    log_output "\n${YELLOW}Testing:${NC} $1"
}

print_pass() {
    log_output "${GREEN}✓ PASS${NC}: $1"
    ((PASSED++))
}

print_fail() {
    log_output "${RED}✗ FAIL${NC}: $1"
    ((FAILED++))
}

print_warn() {
    log_output "${YELLOW}⚠ WARN${NC}: $1"
    ((WARNINGS++))
}

print_info() {
    log_output "${BLUE}ℹ INFO${NC}: $1"
}

# Function to anonymize the log
anonymize_log() {
    local input_file="$1"
    local output_file="$2"
    
    # Start with a copy
    cp "$input_file" "$output_file"
    
    # Replace hostname
    if [ -n "${SENSITIVE_DATA[hostname]}" ] && [ "${SENSITIVE_DATA[hostname]}" != "unknown" ]; then
        sed -i "s/${SENSITIVE_DATA[hostname]}/<HOSTNAME>/g" "$output_file"
    fi
    
    # Replace public IP
    if [ -n "${SENSITIVE_DATA[public_ip]}" ] && [ "${SENSITIVE_DATA[public_ip]}" != "unknown" ]; then
        sed -i "s/${SENSITIVE_DATA[public_ip]}/<PUBLIC_IP>/g" "$output_file"
    fi
    
    # Replace Tailscale IP
    if [ -n "${SENSITIVE_DATA[tailscale_ip]}" ] && [ "${SENSITIVE_DATA[tailscale_ip]}" != "unknown" ]; then
        sed -i "s/${SENSITIVE_DATA[tailscale_ip]}/<TAILSCALE_IP>/g" "$output_file"
    fi
    
    # Replace Tailscale hostname
    if [ -n "${SENSITIVE_DATA[tailscale_hostname]}" ] && [ "${SENSITIVE_DATA[tailscale_hostname]}" != "unknown" ]; then
        sed -i "s/${SENSITIVE_DATA[tailscale_hostname]}/<TAILSCALE_HOSTNAME>/g" "$output_file"
    fi
    
    # Replace any remaining Tailscale IPs (100.x.x.x range)
    sed -i -E 's/100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/<TAILSCALE_IP>/g' "$output_file"
    
    # Replace any remaining public IPs (basic pattern)
    sed -i -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<IP_ADDRESS>/g' "$output_file"
    
    # Replace usernames (UIDs >= 1000, common patterns)
    local users=$(awk -F: '$3 >= 1000 && $1 != "nobody" {print $1}' /etc/passwd 2>/dev/null | tr '\n' '|' | sed 's/|$//')
    if [ -n "$users" ]; then
        sed -i -E "s/($users)/<USER>/g" "$output_file"
    fi
    
    # Replace SSH key fingerprints
    sed -i -E 's/ssh-[a-z0-9]+ [A-Za-z0-9+\/=]+ .*/<SSH_KEY>/g' "$output_file"
    
    # Replace email addresses
    sed -i -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/<EMAIL>/g' "$output_file"
    
    # Add header to anonymized log
    local temp_file=$(mktemp)
    cat > "$temp_file" << 'EOF'
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ANONYMIZED VERIFICATION LOG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This log has been automatically anonymized for safe sharing.
Sensitive information has been replaced with placeholders:
  - <HOSTNAME>: Server hostname
  - <TAILSCALE_IP>: Tailscale IP address (100.x.x.x)
  - <TAILSCALE_HOSTNAME>: Tailscale hostname
  - <PUBLIC_IP>: Public IP address
  - <IP_ADDRESS>: Other IP addresses
  - <USER>: Usernames
  - <SSH_KEY>: SSH keys
  - <EMAIL>: Email addresses

This log is safe to share for troubleshooting purposes.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

EOF
    cat "$output_file" >> "$temp_file"
    mv "$temp_file" "$output_file"
}

# Initialize log files
> "$FULL_LOG"
> "$SAFE_LOG"

# Start verification
clear
print_header "🔍 Dokploy Installation Verification Script"
log_output "This script will verify all components installed by cloud-init"
log_output "Run this script on the server via SSH"
if [ "$DEBUG" = true ]; then
    log_output "${YELLOW}DEBUG MODE ENABLED${NC}"
fi
log_output ""
log_output "Logging to:"
log_output "  - Full log: $FULL_LOG (keep private)"
log_output "  - Safe log: $SAFE_LOG (safe to share)"
log_output ""
log_output "Starting verification at: $(date)"
log_output "Tip: Run with -d flag for debug mode: sudo ./verify-installation.sh -d"
log_output ""

# ====
# 1. System Information
# ====
print_header "1. System Information"

print_test "Hostname"
HOSTNAME=$(hostname)
SENSITIVE_DATA[hostname]="$HOSTNAME"
print_info "Hostname: $HOSTNAME"

print_test "Ubuntu Version"
if [ -f /etc/os-release ]; then
    source /etc/os-release
    print_info "OS: $NAME $VERSION"
    if [[ "$VERSION_ID" =~ ^(20.04|22.04|24.04)$ ]]; then
        print_pass "Ubuntu version is supported"
    else
        print_warn "Ubuntu version may not be tested"
    fi
else
    print_fail "Cannot determine OS version"
fi

print_test "Timezone"
if command -v timedatectl >/dev/null 2>&1; then
    TIMEZONE=$(timeout 3 timedatectl show -p Timezone --value 2>/dev/null || echo "unknown")
    if [ "$TIMEZONE" != "unknown" ] && [ -n "$TIMEZONE" ]; then
        print_info "Timezone: $TIMEZONE"
        print_pass "Timezone is configured"
    else
        print_warn "Could not determine timezone"
    fi
else
    print_warn "timedatectl not available"
fi

print_test "System Uptime"
UPTIME=$(uptime -p 2>/dev/null || uptime)
print_info "Uptime: $UPTIME"

# ====
# 2. Network Configuration
# ====
print_header "2. Network Configuration"

print_test "DNS Resolution"
if timeout 3 systemctl is-active --quiet systemd-resolved 2>/dev/null; then
    print_pass "systemd-resolved is active"
    DNS_SERVERS=$(timeout 3 resolvectl status 2>/dev/null | grep "DNS Servers" | head -1 || echo "DNS Servers: unknown")
    print_info "$DNS_SERVERS"
else
    print_fail "systemd-resolved is not active"
fi

print_test "Internet Connectivity"
if ping -c 1 -W 2 1.1.1.1 >/dev/null 2>&1; then
    print_pass "Can reach internet (1.1.1.1)"
else
    print_fail "Cannot reach internet"
fi

print_test "DNS Query Test"
if nslookup google.com >/dev/null 2>&1; then
    print_pass "DNS queries working"
else
    print_fail "DNS queries failing"
fi

# ====
# 3. Tailscale
# ====
print_header "3. Tailscale VPN"

print_test "Tailscale Installation"
if command -v tailscale >/dev/null 2>&1; then
    TAILSCALE_VERSION=$(tailscale version | head -1)
    print_pass "Tailscale installed: $TAILSCALE_VERSION"
else
    print_fail "Tailscale not installed"
fi

print_test "Tailscale Service"
if timeout 3 systemctl is-active --quiet tailscaled; then
    print_pass "tailscaled service is running"
else
    print_fail "tailscaled service is not running"
fi

print_test "Tailscale Connection Status"
if tailscale status >/dev/null 2>&1; then
    print_pass "Tailscale is connected"
    TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
    SENSITIVE_DATA[tailscale_ip]="$TAILSCALE_IP"
    print_info "Tailscale IP: $TAILSCALE_IP"
    TAILSCALE_HOSTNAME=$(tailscale status --json 2>/dev/null | jq -r '.Self.HostName' 2>/dev/null || echo "unknown")
    SENSITIVE_DATA[tailscale_hostname]="$TAILSCALE_HOSTNAME"
    print_info "Tailscale Hostname: $TAILSCALE_HOSTNAME"
else
    print_fail "Tailscale not connected"
fi

print_test "Tailscale SSH"
if tailscale status --json 2>/dev/null | jq -e '.Self.KeyExpiry' >/dev/null 2>&1; then
    print_pass "Tailscale SSH is available"
else
    print_warn "Tailscale SSH status unclear"
fi

# ====
# 4. Docker
# ====
print_header "4. Docker"

print_test "Docker Installation"
if command -v docker >/dev/null 2>&1; then
    DOCKER_VERSION=$(docker --version)
    print_pass "Docker installed: $DOCKER_VERSION"
else
    print_fail "Docker not installed"
fi

print_test "Docker Service"
if timeout 3 systemctl is-active --quiet docker; then
    print_pass "Docker service is running"
else
    print_fail "Docker service is not running"
fi

print_test "Docker Socket Permissions"
if [ -S /var/run/docker.sock ]; then
    print_pass "Docker socket exists"
    SOCKET_PERMS=$(stat -c '%a' /var/run/docker.sock)
    print_info "Socket permissions: $SOCKET_PERMS"
else
    print_fail "Docker socket not found"
fi

print_test "Docker Compose Plugin"
if docker compose version >/dev/null 2>&1; then
    COMPOSE_VERSION=$(docker compose version)
    print_pass "Docker Compose plugin installed: $COMPOSE_VERSION"
else
    print_fail "Docker Compose plugin not installed"
fi

print_test "Docker Swarm Mode"
SWARM_STATUS=$(docker info --format '{{.Swarm.LocalNodeState}}' 2>/dev/null || echo "unknown")
if [ "$SWARM_STATUS" = "active" ]; then
    print_pass "Docker Swarm mode is active (required by Dokploy)"
    SWARM_ROLE=$(docker info --format '{{.Swarm.ControlAvailable}}' 2>/dev/null)
    if [ "$SWARM_ROLE" = "true" ]; then
        print_info "Node role: Manager"
    else
        print_info "Node role: Worker"
    fi
else
    print_fail "Docker Swarm mode is not active (required by Dokploy)"
fi

print_test "Docker Containers"
CONTAINER_COUNT=$(docker ps -q 2>/dev/null | wc -l)
print_info "Running containers: $CONTAINER_COUNT"
if [ "$CONTAINER_COUNT" -gt 0 ]; then
    print_pass "Docker containers are running"
else
    print_warn "No Docker containers running"
fi

# ====
# 5. Cloudflare Tunnel
# ====
print_header "5. Cloudflare Tunnel"

print_test "Cloudflared Installation"
if command -v cloudflared >/dev/null 2>&1; then
    CLOUDFLARED_VERSION=$(cloudflared --version 2>&1 | head -1)
    print_pass "Cloudflared installed: $CLOUDFLARED_VERSION"
else
    print_fail "Cloudflared not installed"
fi

print_test "Cloudflared Service"
if timeout 3 systemctl is-active --quiet cloudflared 2>/dev/null; then
    print_pass "Cloudflared service is running"
else
    print_fail "Cloudflared service is not running"
fi

print_test "Cloudflare Tunnel Connection"
if systemctl status cloudflared 2>/dev/null | grep -q "Registered tunnel connection"; then
    print_pass "Cloudflare Tunnel is connected"
elif systemctl is-active --quiet cloudflared 2>/dev/null; then
    print_warn "Cloudflared is running but connection status unclear"
else
    print_fail "Cloudflare Tunnel is not connected"
fi

# ====
# 6. Dokploy
# ====
print_header "6. Dokploy"

print_test "Dokploy Installation"
if [ -d /etc/dokploy ]; then
    print_pass "Dokploy configuration directory exists"
else
    print_warn "Dokploy configuration directory not found at /etc/dokploy"
fi

print_test "Dokploy Health Check"
if curl -s http://localhost:3000 >/dev/null 2>&1; then
    print_pass "Dokploy is responding on port 3000"
else
    print_fail "Dokploy is not responding on port 3000"
fi

print_test "Dokploy Containers"
DOKPLOY_CONTAINERS=$(docker ps --filter "name=dokploy" --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$DOKPLOY_CONTAINERS" -gt 0 ]; then
    print_pass "Dokploy containers found: $DOKPLOY_CONTAINERS"
    log_output ""
    docker ps --filter "name=dokploy" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null | while IFS= read -r line; do
        log_output "$line"
    done
else
    print_fail "No Dokploy containers found"
fi

print_test "Traefik (Reverse Proxy)"
TRAEFIK_CONTAINERS=$(docker ps --filter "name=traefik" --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$TRAEFIK_CONTAINERS" -gt 0 ]; then
    print_pass "Traefik container is running"
    # Check if Traefik is listening on ports 80/443
    if ss -tlnp 2>/dev/null | grep -q ":80 "; then
        print_pass "Traefik is listening on port 80"
    else
        print_warn "Traefik may not be listening on port 80"
    fi
    if ss -tlnp 2>/dev/null | grep -q ":443 "; then
        print_pass "Traefik is listening on port 443"
    else
        print_warn "Traefik may not be listening on port 443"
    fi
else
    print_fail "Traefik container not found"
fi

print_test "PostgreSQL (Database)"
POSTGRES_CONTAINERS=$(docker ps --filter "name=postgres" --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$POSTGRES_CONTAINERS" -gt 0 ]; then
    print_pass "PostgreSQL container is running"
else
    print_warn "PostgreSQL container not found (may use different name)"
fi

print_test "Redis (Queue)"
REDIS_CONTAINERS=$(docker ps --filter "name=redis" --format "{{.Names}}" 2>/dev/null | wc -l)
if [ "$REDIS_CONTAINERS" -gt 0 ]; then
    print_pass "Redis container is running"
else
    print_warn "Redis container not found (may use different name)"
fi

print_test "Dokploy Access Information"
if [ -f /root/dokploy-access-info.txt ]; then
    print_pass "Access information file exists"
else
    print_warn "Access information file not found"
fi

# ====
# 7. Firewall (UFW)
# ====
print_header "7. Firewall (UFW)"

print_test "UFW Installation"
if command -v ufw >/dev/null 2>&1; then
    print_pass "UFW is installed"
else
    print_fail "UFW not installed"
fi

print_test "UFW Status"
UFW_STATUS_OUTPUT=$(ufw status 2>&1)
UFW_STATUS_RESULT=$?
if [ $UFW_STATUS_RESULT -eq 0 ] && echo "$UFW_STATUS_OUTPUT" | grep -q "Status: inactive"; then
    print_pass "UFW is disabled (using OCI security lists)"
    print_info "This is correct - OCI security lists handle firewall rules"
elif [ $UFW_STATUS_RESULT -eq 0 ] && echo "$UFW_STATUS_OUTPUT" | grep -q "Status: active"; then
    print_warn "UFW is active (may conflict with Docker/OCI security lists)"
else
    print_warn "UFW status unclear"
fi

# ====
# 8. SSH Hardening
# ====
print_header "8. SSH Hardening"

print_test "SSH Configuration File"
if [ -f /etc/ssh/sshd_config ]; then
    print_pass "SSH configuration file exists"
else
    print_fail "SSH configuration file not found"
fi

print_test "Root Login Disabled (with exceptions)"
if grep -q "^PermitRootLogin no" /etc/ssh/sshd_config 2>/dev/null; then
    print_pass "Root login is disabled by default"
    if grep -q "Match Address.*PermitRootLogin yes" /etc/ssh/sshd_config 2>/dev/null; then
        print_info "Root login allowed from localhost/Docker (required for Dokploy)"
    fi
elif grep -q "^PermitRootLogin" /etc/ssh/sshd_config 2>/dev/null; then
    ROOT_LOGIN_VALUE=$(grep "^PermitRootLogin" /etc/ssh/sshd_config | awk '{print $2}')
    print_fail "Root login is set to: $ROOT_LOGIN_VALUE (should be 'no' with Match exceptions)"
else
    print_warn "PermitRootLogin setting not found (using default)"
fi

print_test "Password Authentication Disabled"
if grep -q "^PasswordAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    print_pass "Password authentication is disabled"
elif grep -q "^PasswordAuthentication" /etc/ssh/sshd_config 2>/dev/null; then
    PASS_AUTH_VALUE=$(grep "^PasswordAuthentication" /etc/ssh/sshd_config | awk '{print $2}')
    print_fail "Password authentication is set to: $PASS_AUTH_VALUE (should be 'no')"
else
    print_warn "PasswordAuthentication setting not found (using default)"
fi

print_test "Public Key Authentication Enabled"
if grep -q "^PubkeyAuthentication yes" /etc/ssh/sshd_config 2>/dev/null; then
    print_pass "Public key authentication is enabled"
elif grep -q "^PubkeyAuthentication no" /etc/ssh/sshd_config 2>/dev/null; then
    print_fail "Public key authentication is disabled"
else
    print_info "PubkeyAuthentication not explicitly set (default is yes)"
fi

print_test "SSH Configuration Backup"
if [ -f /etc/ssh/sshd_config.backup ]; then
    print_pass "SSH configuration backup exists"
else
    print_warn "SSH configuration backup not found"
fi

# ====
# 9. Fail2ban
# ====
print_header "9. Fail2ban"

print_test "Fail2ban Installation"
if command -v fail2ban-client >/dev/null 2>&1; then
    print_pass "Fail2ban is installed"
else
    print_fail "Fail2ban not installed"
fi

print_test "Fail2ban Service"
if timeout 3 systemctl is-active --quiet fail2ban 2>/dev/null; then
    print_pass "Fail2ban service is running"
else
    print_fail "Fail2ban service is not running"
fi

print_test "Fail2ban Status"
if fail2ban-client status >/dev/null 2>&1; then
    JAILS=$(fail2ban-client status 2>/dev/null | grep "Jail list" | cut -d: -f2 | xargs)
    print_info "Active jails: $JAILS"
    print_pass "Fail2ban is operational"
else
    print_warn "Cannot query fail2ban status"
fi

# ====
# 10. Automatic Security Updates
# ====
print_header "10. Automatic Security Updates"

print_test "Unattended-Upgrades Installation"
if dpkg -l | grep -q "^ii.*unattended-upgrades"; then
    print_pass "Unattended-upgrades is installed"
else
    print_fail "Unattended-upgrades not installed"
fi

print_test "Automatic Updates Configuration"
if [ -f /etc/apt/apt.conf.d/20auto-upgrades ]; then
    print_pass "Auto-updates configuration file exists"
    
    # Check if automatic updates are enabled
    if grep -q "APT::Periodic::Unattended-Upgrade \"1\"" /etc/apt/apt.conf.d/20auto-upgrades 2>/dev/null; then
        print_pass "Automatic security updates are ENABLED"
    else
        print_warn "Automatic updates may not be fully enabled"
    fi
else
    print_fail "Auto-updates configuration file missing"
fi

print_test "Unattended-Upgrades Configuration"
if [ -f /etc/apt/apt.conf.d/50unattended-upgrades ]; then
    print_pass "Unattended-upgrades configuration exists"
    print_info "Security updates will be installed automatically"
else
    print_warn "Unattended-upgrades configuration file missing"
fi

# ====
# 11. User Configuration
# ====
print_header "11. User Configuration"

print_test "Ubuntu User"
if id ubuntu >/dev/null 2>&1; then
    print_pass "Ubuntu user exists"
    UBUNTU_GROUPS=$(groups ubuntu)
    print_info "Groups: $UBUNTU_GROUPS"
    
    if echo "$UBUNTU_GROUPS" | grep -q "docker"; then
        print_pass "Ubuntu user is in docker group"
    else
        print_warn "Ubuntu user not in docker group"
    fi
    
    if echo "$UBUNTU_GROUPS" | grep -q "sudo"; then
        print_pass "Ubuntu user is in sudo group"
    else
        print_warn "Ubuntu user not in sudo group"
    fi
else
    print_fail "Ubuntu user does not exist"
fi

print_test "Admin Users"
# Check if any non-system user exists (UID >= 1000, not ubuntu, not nobody)
ADMIN_USERS=$(awk -F: '$3 >= 1000 && $1 != "ubuntu" && $1 != "nobody" {print $1}' /etc/passwd)
ADMIN_USER_COUNT=$(echo "$ADMIN_USERS" | wc -w)

if [ -n "$ADMIN_USERS" ] && [ "$ADMIN_USER_COUNT" -gt 0 ]; then
    print_pass "Found $ADMIN_USER_COUNT admin user(s): $ADMIN_USERS"
    
    # Check each admin user
    USERS_WITH_SUDO=0
    USERS_WITH_DOCKER=0
    USERS_WITH_SSH=0
    
    for user in $ADMIN_USERS; do
        USER_GROUPS=$(groups "$user")
        print_info "$user groups: $USER_GROUPS"
        
        # Count users with proper access
        if echo "$USER_GROUPS" | grep -q "sudo"; then
            USERS_WITH_SUDO=$((USERS_WITH_SUDO + 1))
        fi
        
        if echo "$USER_GROUPS" | grep -q "docker"; then
            USERS_WITH_DOCKER=$((USERS_WITH_DOCKER + 1))
        fi
        
        # Check SSH keys
        if [ -f "/home/$user/.ssh/authorized_keys" ] && [ -s "/home/$user/.ssh/authorized_keys" ]; then
            KEY_COUNT=$(grep -c "^ssh-" /home/$user/.ssh/authorized_keys 2>/dev/null || echo 0)
            if [ "$KEY_COUNT" -gt 0 ]; then
                USERS_WITH_SSH=$((USERS_WITH_SSH + 1))
            fi
        fi
    done
    
    # Summary checks
    if [ "$USERS_WITH_SUDO" -eq "$ADMIN_USER_COUNT" ]; then
        print_pass "All admin users have sudo access"
    else
        print_warn "Only $USERS_WITH_SUDO of $ADMIN_USER_COUNT admin users have sudo access"
    fi
    
    if [ "$USERS_WITH_DOCKER" -eq "$ADMIN_USER_COUNT" ]; then
        print_pass "All admin users have docker access"
    else
        print_warn "Only $USERS_WITH_DOCKER of $ADMIN_USER_COUNT admin users have docker access"
    fi
    
    if [ "$USERS_WITH_SSH" -eq "$ADMIN_USER_COUNT" ]; then
        print_pass "All admin users have SSH keys configured"
    else
        print_warn "Only $USERS_WITH_SSH of $ADMIN_USER_COUNT admin users have SSH keys"
    fi
else
    print_info "No admin users configured (using ubuntu user only)"
fi

print_test "SSH Keys Detail"
# Check ubuntu user
if [ -f "/home/ubuntu/.ssh/authorized_keys" ] && [ -s "/home/ubuntu/.ssh/authorized_keys" ]; then
    KEY_COUNT=$(grep -c "^ssh-" /home/ubuntu/.ssh/authorized_keys 2>/dev/null || echo 0)
    if [ "$KEY_COUNT" -gt 0 ]; then
        print_pass "ubuntu has $KEY_COUNT SSH key(s)"
    else
        print_warn "ubuntu authorized_keys file exists but contains no valid keys"
    fi
else
    print_warn "ubuntu has no SSH keys configured"
fi

# Check admin users
if [ -n "$ADMIN_USERS" ]; then
    for user in $ADMIN_USERS; do
        if [ -f "/home/$user/.ssh/authorized_keys" ] && [ -s "/home/$user/.ssh/authorized_keys" ]; then
            KEY_COUNT=$(grep -c "^ssh-" /home/$user/.ssh/authorized_keys 2>/dev/null || echo 0)
            if [ "$KEY_COUNT" -gt 0 ]; then
                print_pass "$user has $KEY_COUNT SSH key(s)"
            else
                print_warn "$user authorized_keys file exists but contains no valid keys"
            fi
        else
            print_warn "$user has no SSH keys configured"
        fi
    done
fi

# ====
# 12. Deployment Logs
# ====
print_header "12. Deployment Logs"

print_test "Cloud-init Logs"
if [ -f /var/log/cloud-init-output.log ]; then
    print_pass "Cloud-init output log exists"
    LOG_SIZE=$(du -h /var/log/cloud-init-output.log | cut -f1)
    print_info "Log size: $LOG_SIZE"
else
    print_warn "Cloud-init output log not found"
fi

print_test "Dokploy Deployment Log"
if [ -f /var/log/dokploy-deployment.log ]; then
    print_pass "Dokploy deployment log exists"
    LOG_SIZE=$(du -h /var/log/dokploy-deployment.log | cut -f1)
    print_info "Log size: $LOG_SIZE"
    
    if grep -q "Deployment Complete" /var/log/dokploy-deployment.log 2>/dev/null; then
        print_pass "Deployment completed successfully"
    else
        print_warn "Deployment may not have completed (check log)"
    fi
else
    print_fail "Dokploy deployment log not found"
fi

# ====
# 13. Security Checks
# ====
print_header "13. Security Checks"

print_test "Public Port Exposure"
print_info "Checking if Dokploy is accessible from public IP..."
PUBLIC_IP=$(curl -s ifconfig.me 2>/dev/null || echo "unknown")
SENSITIVE_DATA[public_ip]="$PUBLIC_IP"
print_info "Public IP: $PUBLIC_IP"

if [ "$PUBLIC_IP" != "unknown" ]; then
    if timeout 3 curl -s http://$PUBLIC_IP:3000 >/dev/null 2>&1; then
        print_fail "⚠️  SECURITY ISSUE: Dokploy is accessible from public IP!"
    else
        print_pass "Dokploy is NOT accessible from public IP (correct)"
    fi
    
    if timeout 3 curl -s http://$PUBLIC_IP:80 >/dev/null 2>&1; then
        print_fail "⚠️  SECURITY ISSUE: Port 80 is accessible from public IP!"
    else
        print_pass "Port 80 is NOT accessible from public IP (correct)"
    fi
    
    if timeout 3 curl -s -k https://$PUBLIC_IP:443 >/dev/null 2>&1; then
        print_fail "⚠️  SECURITY ISSUE: Port 443 is accessible from public IP!"
    else
        print_pass "Port 443 is NOT accessible from public IP (correct)"
    fi
else
    print_warn "Cannot determine public IP"
fi

print_test "SSH Port Exposure"
if ss -tlnp 2>/dev/null | grep -q ":22 "; then
    print_info "SSH is listening on port 22"
    print_pass "SSH should be restricted to Tailscale network by OCI security list"
else
    print_fail "SSH is not listening"
fi

print_test "Dokploy Network (iptables)"
# Check if iptables rules allow Tailscale to Dokploy network
if iptables -L DOCKER-USER -n 2>/dev/null | grep -q "tailscale0"; then
    print_pass "iptables rules allow Tailscale access to Dokploy network"
else
    print_warn "Tailscale iptables rule not found (may affect dashboard access)"
fi

# ====
# Summary
# ====
print_header "📊 Verification Summary"

TOTAL=$((PASSED + FAILED + WARNINGS))
log_output ""
log_output "${GREEN}✓ Passed:${NC}   $PASSED"
log_output "${RED}✗ Failed:${NC}   $FAILED"
log_output "${YELLOW}⚠ Warnings:${NC} $WARNINGS"
log_output "━━━━━━━━━━━━━━━━━━━━━━━━"
log_output "Total Tests: $TOTAL"
log_output ""

# Generate anonymized log
print_info "Generating anonymized log..."
anonymize_log "$FULL_LOG" "$SAFE_LOG"
print_pass "Anonymized log created: $SAFE_LOG"
log_output ""

if [ $FAILED -eq 0 ]; then
    log_output "${GREEN}🎉 All critical tests passed!${NC}"
    log_output ""
    log_output "Your Dokploy installation is working correctly."
    log_output ""
    log_output "Next steps:"
    log_output "  1. Access Dokploy at: http://${SENSITIVE_DATA[tailscale_hostname]}:3000"
    log_output "  2. Or use Tailscale IP: http://${SENSITIVE_DATA[tailscale_ip]}:3000"
    log_output "  3. Create your admin account immediately"
    log_output "  4. Deploy applications via Dokploy"
    log_output "  5. Configure Cloudflare Tunnel routes for public access"
    log_output ""
    log_output "Logs saved:"
    log_output "  - Full log: $FULL_LOG (keep private)"
    log_output "  - Safe log: $SAFE_LOG (safe to share for troubleshooting)"
    log_output ""
    exit 0
else
    log_output "${RED}⚠️  Some tests failed!${NC}"
    log_output ""
    log_output "Please review the failed tests above and check:"
    log_output "  - /var/log/dokploy-deployment.log"
    log_output "  - /var/log/cloud-init-output.log"
    log_output "  - journalctl -xe"
    log_output ""
    log_output "Logs saved:"
    log_output "  - Full log: $FULL_LOG (keep private)"
    log_output "  - Safe log: $SAFE_LOG (safe to share for troubleshooting)"
    log_output ""
    exit 1
fi

