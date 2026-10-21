#cloud-config
# ====
# Production Cloud-Init Template for Dokploy
# - Dokploy Dashboard: Private (Tailscale only) on port 3000
# - Traefik: Handles HTTP/HTTPS traffic on ports 80/443
# - Cloudflare Tunnel: Available for applications deployed by Dokploy
# ====

hostname: ${tailscale_hostname}
fqdn: ${tailscale_hostname}.local
timezone: ${timezone}
package_update: false
package_upgrade: false
ssh_pwauth: false

users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    groups: [sudo, docker]
    shell: /bin/bash
    ssh_authorized_keys:
      - ${bootstrap_ssh_public_key}

packages:
  - curl, wget, git, htop, unzip, fail2ban, ufw, jq, ca-certificates, gnupg, lsb-release, apt-transport-https, software-properties-common, psmisc, unattended-upgrades, update-notifier-common

write_files:
  # Primary user creation script
  - path: /tmp/create-primary-user.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      PRIMARY_USER="${primary_username}"
      CREATE_USER="${create_primary_user}"
      DISABLE_UBUNTU="${disable_default_ubuntu_user}"
      PRIMARY_SSH_KEY="${primary_user_ssh_public_key}"
      BOOTSTRAP_SSH_KEY="${bootstrap_ssh_public_key}"
      
      if [ "$CREATE_USER" = "true" ] && [ -n "$PRIMARY_USER" ]; then        
        if id "$PRIMARY_USER" >/dev/null 2>&1; then
          echo "User exists"
        else
          useradd --create-home --shell /bin/bash --user-group "$PRIMARY_USER"
          echo "✓ User $PRIMARY_USER created"
        fi
        
        usermod -aG sudo,docker "$PRIMARY_USER"
        echo "$PRIMARY_USER ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$PRIMARY_USER"
        chmod 440 "/etc/sudoers.d/$PRIMARY_USER"
        
        mkdir -p "/home/$PRIMARY_USER/.ssh"
        chmod 700 "/home/$PRIMARY_USER/.ssh"
        
        if [ -n "$PRIMARY_SSH_KEY" ]; then
          echo "$PRIMARY_SSH_KEY" > "/home/$PRIMARY_USER/.ssh/authorized_keys"
        else
          echo "$BOOTSTRAP_SSH_KEY" > "/home/$PRIMARY_USER/.ssh/authorized_keys"
        fi
        
        chmod 600 "/home/$PRIMARY_USER/.ssh/authorized_keys"
        chown -R "$PRIMARY_USER:" "/home/$PRIMARY_USER/.ssh"
        
        if su - "$PRIMARY_USER" -c "sudo whoami" >/dev/null 2>&1; then
          echo "✓ Primary user OK"
          
          if [ "$DISABLE_UBUNTU" = "true" ]; then
            usermod -L -e 1 ubuntu
            echo "✓ Ubuntu disabled"
          fi
        else
          echo "⚠ Test failed"
        fi
      fi

  # Multi-admin user creation script
  - path: /tmp/admin-users.json
    permissions: '0644'
    content: |
      ${admin_users_json}

  - path: /tmp/create-admin-users.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      ADMIN_USERS_JSON="/tmp/admin-users.json"
      DISABLE_UBUNTU="${disable_default_ubuntu_user}"
      BOOTSTRAP_SSH_KEY="${bootstrap_ssh_public_key}"
      
      USER_COUNT=$(jq -r '.users | length' "$ADMIN_USERS_JSON" 2>/dev/null || echo "0")
      
      if [ "$USER_COUNT" -eq 0 ]; then
        echo "No admin users to create (using legacy single-user or ubuntu only)"
        exit 0
      fi      
      
      jq -c '.users[]' "$ADMIN_USERS_JSON" | while read -r user_obj; do
        USERNAME=$(echo "$user_obj" | jq -r '.username')
        SSH_KEY=$(echo "$user_obj" | jq -r '.ssh_key')
        DISABLED=$(echo "$user_obj" | jq -r '.disabled // false')
        
        if [ "$DISABLED" = "true" ]; then
          echo "⚠ Skipping disabled user: $USERNAME"
          continue
        fi
        
        echo "Creating user: $USERNAME"
        
        if id "$USERNAME" >/dev/null 2>&1; then
          echo "  User $USERNAME already exists, updating configuration..."
        else
          useradd --create-home --shell /bin/bash --user-group "$USERNAME"
          echo "  ✓ User created"
        fi
        
        usermod -aG sudo,docker "$USERNAME"
        
        echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME"
        chmod 440 "/etc/sudoers.d/$USERNAME"
        echo "  ✓ Sudo access configured"
        
        mkdir -p "/home/$USERNAME/.ssh"
        chmod 700 "/home/$USERNAME/.ssh"
        
        if [ -n "$SSH_KEY" ]; then
          echo "$SSH_KEY" > "/home/$USERNAME/.ssh/authorized_keys"
        else
          echo "$BOOTSTRAP_SSH_KEY" > "/home/$USERNAME/.ssh/authorized_keys"
        fi
        
        chmod 600 "/home/$USERNAME/.ssh/authorized_keys"
        chown -R "$USERNAME:" "/home/$USERNAME/.ssh"
        echo "  ✓ SSH key configured"
        
        if su - "$USERNAME" -c "sudo whoami" >/dev/null 2>&1; then
          echo "  ✓ User $USERNAME is functional"
        else
          echo "  ⚠ User $USERNAME sudo test failed"
        fi
      done
      
      if [ "$DISABLE_UBUNTU" = "true" ] && [ "$USER_COUNT" -gt 0 ]; then
        FUNCTIONAL_USERS=0
        
        while IFS= read -r user_obj; do
          USERNAME=$(echo "$user_obj" | jq -r '.username')
          DISABLED=$(echo "$user_obj" | jq -r '.disabled // false')
          
          if [ "$DISABLED" = "false" ] && id "$USERNAME" >/dev/null 2>&1; then
            if su - "$USERNAME" -c "sudo -n whoami" >/dev/null 2>&1; then
              FUNCTIONAL_USERS=$((FUNCTIONAL_USERS + 1))
              echo "✓ Verified $USERNAME has functional sudo access"
            fi
          fi
        done < <(jq -c '.users[]' "$ADMIN_USERS_JSON")
        
        echo "Found $FUNCTIONAL_USERS functional admin user(s)"
        
        if [ "$FUNCTIONAL_USERS" -gt 0 ]; then
          usermod -L -e 1 ubuntu
          echo "✓ Ubuntu user disabled (admin users are functional)"
        else
          echo "⚠ Keeping ubuntu user active (no functional admin users found)"
        fi
      fi
      
      echo "✓ Admin users"

  # Robust apt-get wrapper
  - path: /tmp/run-apt.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      while fuser /var/lib/dpkg/lock-frontend >/dev/null 2>&1 || fuser /var/lib/apt/lists/lock >/dev/null 2>&1; do 
        sleep 10
      done
      apt-get -o Dpkg::Lock::Timeout=600 "$@"

  # Early network/DNS setup
  - path: /tmp/early-network-setup.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      systemctl enable --now systemd-resolved || true
      sed -i 's/^#\?DNS=.*/DNS=1.1.1.1 8.8.8.8/' /etc/systemd/resolved.conf
      sed -i 's/^#\?FallbackDNS=.*/FallbackDNS=9.9.9.9 1.0.0.1/' /etc/systemd/resolved.conf
      systemctl restart systemd-resolved
      rm -f /etc/resolv.conf
      ln -s /run/systemd/resolve/stub-resolv.conf /etc/resolv.conf

  # Docker setup with optional volume
  - path: /tmp/setup-docker-volume-and-install.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      if [ "${create_docker_volume}" = "true" ]; then
        DEV_PATH="${docker_device}"
        MNT_POINT="/var/lib/docker"
        
        if [ -b "$DEV_PATH" ]; then
          echo "Setup Docker volume"
          
          if ! blkid "$DEV_PATH" >/dev/null 2>&1; then
            mkfs.ext4 -F "$DEV_PATH"
          fi
          
          UUID=$(blkid -s UUID -o value "$DEV_PATH")
          mkdir -p "$MNT_POINT"
          
          if ! grep -q "$UUID" /etc/fstab; then
            echo "UUID=$UUID  $MNT_POINT  ext4  defaults,nofail  0  2" >> /etc/fstab
          fi
          
          mount -a
          echo "✓ Docker volume mounted"
          
          # Setup containerd to use docker volume
          # This prevents containerd from storing 20+ GB on the boot volume
          mkdir -p "$MNT_POINT/containerd"
          ln -sf "$MNT_POINT/containerd" /var/lib/containerd
          echo "✓ Containerd symlink created"
        else
          echo "⚠ Volume not found"
        fi
      fi
      
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://download.docker.com/linux/ubuntu/gpg | gpg --dearmor -o /etc/apt/keyrings/docker.gpg
      chmod a+r /etc/apt/keyrings/docker.gpg
      echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu ${version_codename} stable" > /etc/apt/sources.list.d/docker.list
      /tmp/run-apt.sh update -y
      /tmp/run-apt.sh install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
      systemctl enable --now docker
      usermod -aG docker ubuntu
      echo "✓ Docker"

  # Tailscale installation
  - path: /tmp/install-tailscale.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      install -m 0755 -d /etc/apt/keyrings
      curl -fsSL https://pkgs.tailscale.com/stable/ubuntu/${version_codename}.noarmor.gpg | gpg --dearmor -o /etc/apt/keyrings/tailscale.gpg
      echo "deb [signed-by=/etc/apt/keyrings/tailscale.gpg] https://pkgs.tailscale.com/stable/ubuntu ${version_codename} main" | tee /etc/apt/sources.list.d/tailscale.list
      /tmp/run-apt.sh update -y
      /tmp/run-apt.sh install -y tailscale
      tailscale up --authkey=${tailscale_auth_key} --hostname=${tailscale_hostname} --ssh --accept-routes --accept-dns=false
      echo "✓ Tailscale"

  # Cloudflare Tunnel setup (for applications, NOT for Dokploy dashboard)
  - path: /tmp/setup-cloudflare-tunnel.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      echo "Installing Cloudflare Tunnel..."
      curl -L --output cloudflared.deb https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-arm64.deb
      dpkg -i cloudflared.deb
      rm cloudflared.deb
      
      # Create systemd service for cloudflared
      cat > /etc/systemd/system/cloudflared.service << 'EOF'
      [Unit]
      Description=Cloudflare Tunnel
      After=network.target
      
      [Service]
      Type=simple
      User=root
      ExecStart=/usr/bin/cloudflared tunnel --no-autoupdate run --token ${cf_tunnel_token}
      Restart=on-failure
      RestartSec=5s
      
      [Install]
      WantedBy=multi-user.target
      EOF
      
      systemctl daemon-reload
      systemctl enable cloudflared
      systemctl start cloudflared
      
      echo "✓ Cloudflare Tunnel installed and started"
      echo "⚠️  IMPORTANT: Cloudflare Tunnel Configuration"
      echo "   The tunnel is running but has NO public routes configured."
      echo "   This is intentional for security."
      echo "   To expose applications deployed by Dokploy:"
      echo "   1. Deploy your app in Dokploy"
      echo "   2. Note the domain configured in Traefik"
      echo "   3. Go to Cloudflare Zero Trust dashboard"
      echo "   4. Add a public hostname route for that domain"
      echo "   5. Example: app.yourdomain.com → http://localhost:80"
      echo "   DO NOT create a route to localhost:3000 (Dokploy dashboard)"

  # Dokploy installation
  - path: /tmp/install-dokploy.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      usermod -aG docker ubuntu
      
      echo "Installing Dokploy..."
      curl -sSL https://dokploy.com/install.sh | sh
      
      echo "Waiting for Dokploy to start..."
      for i in {1..60}; do 
        if curl -s http://localhost:3000 >/dev/null 2>&1; then 
          echo "✓ Dokploy is ready"
          break
        fi
        sleep 10
      done
      
      # Create access information file
      TAILSCALE_IP=$(tailscale ip -4 2>/dev/null || echo "unknown")
      echo "Dokploy: http://${tailscale_hostname}:3000" > /root/dokploy-access-info.txt
      echo "Tailscale IP: $TAILSCALE_IP" >> /root/dokploy-access-info.txt
      echo "Traefik: Ports 80 (HTTP) and 443 (HTTPS)" >> /root/dokploy-access-info.txt
      
      echo "✓ Access information saved to /root/dokploy-access-info.txt"
      
      # Fix Docker + Tailscale connectivity for Dokploy
      echo "Configuring iptables for Tailscale access to Dokploy..."
      
      sleep 5
      
      # Get the dokploy-network bridge interface
      DOKPLOY_BRIDGE=$(docker network inspect dokploy-network -f '{{.Id}}' 2>/dev/null | cut -c1-12)
      if [ -n "$DOKPLOY_BRIDGE" ]; then
        DOKPLOY_BRIDGE="br-$DOKPLOY_BRIDGE"
        
        if iptables -C DOCKER-USER -i tailscale0 -o "$DOKPLOY_BRIDGE" -j ACCEPT 2>/dev/null; then
          echo "✓ iptables rule already exists"
        else
          iptables -I DOCKER-USER -i tailscale0 -o "$DOKPLOY_BRIDGE" -j ACCEPT
          echo "✓ iptables rule added for Tailscale → Dokploy"
        fi
        
        echo "Installing iptables-persistent..."
        echo iptables-persistent iptables-persistent/autosave_v4 boolean true | debconf-set-selections
        echo iptables-persistent iptables-persistent/autosave_v6 boolean true | debconf-set-selections
        apt-get install -y iptables-persistent
        
        netfilter-persistent save
        
        echo "✓ iptables rules saved persistently"
        echo "✓ Dokploy is now accessible via Tailscale on port 3000"
      else
        echo "WARNING: Could not find Dokploy bridge interface"
        echo "You may need to manually add iptables rules for Tailscale access"
      fi

  # SSH hardening
  - path: /tmp/harden-ssh.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive      
      mkdir -p /run/sshd
      chmod 0755 /run/sshd
      
      cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup
      
      sed -i 's/^#\?PermitRootLogin.*/PermitRootLogin no/' /etc/ssh/sshd_config
      sed -i 's/^#\?PasswordAuthentication.*/PasswordAuthentication no/' /etc/ssh/sshd_config
      sed -i 's/^#\?PubkeyAuthentication.*/PubkeyAuthentication yes/' /etc/ssh/sshd_config
      sed -i 's/^#\?ChallengeResponseAuthentication.*/ChallengeResponseAuthentication no/' /etc/ssh/sshd_config
      sed -i 's/^#\?KbdInteractiveAuthentication.*/KbdInteractiveAuthentication no/' /etc/ssh/sshd_config
      
      echo "" >> /etc/ssh/sshd_config
      echo "# Allow root login from localhost and Docker network (for Dokploy)" >> /etc/ssh/sshd_config
      echo "Match Address 127.0.0.1,::1,10.0.0.0/24,10.0.2.0/24,172.17.0.0/16" >> /etc/ssh/sshd_config
      echo "    PermitRootLogin yes" >> /etc/ssh/sshd_config
      echo "Match all" >> /etc/ssh/sshd_config
      
      if sshd -t; then
        echo "✓ SSH configuration is valid"
      else
        echo "ERROR: SSH configuration is invalid, restoring backup"
        cp /etc/ssh/sshd_config.backup /etc/ssh/sshd_config
        exit 1
      fi
      
      systemctl restart ssh
      
      echo "✓ SSH hardened (root login disabled, password auth disabled)"

  # Server hardening
  - path: /tmp/harden-server.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive      
      /tmp/run-apt.sh install -y ufw fail2ban
      
      systemctl enable fail2ban
      systemctl start fail2ban
      
      cat > /etc/fail2ban/jail.local << 'EOF'
      [DEFAULT]
      bantime = 3600
      findtime = 600
      maxretry = 5
      
      [sshd]
      enabled = true
      port = ssh
      logpath = /var/log/auth.log
      EOF
      
      systemctl restart fail2ban
      echo "✓ Fail2ban configured"
      
      # UFW is managed by OCI security lists, so we'll keep it disabled
      # to avoid conflicts with Docker and Tailscale
      ufw --force disable
      echo "✓ UFW disabled (using OCI security lists)"

  # Automatic security updates
  - path: /tmp/setup-auto-updates.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      /tmp/run-apt.sh install -y unattended-upgrades update-notifier-common
      
      cat > /etc/apt/apt.conf.d/50unattended-upgrades << 'EOF'
      Unattended-Upgrade::Allowed-Origins {
          "$${distro_id}:$${distro_codename}-security";
          "$${distro_id}ESMApps:$${distro_codename}-apps-security";
          "$${distro_id}ESM:$${distro_codename}-infra-security";
      };
      Unattended-Upgrade::AutoFixInterruptedDpkg "true";
      Unattended-Upgrade::MinimalSteps "true";
      Unattended-Upgrade::Remove-Unused-Kernel-Packages "true";
      Unattended-Upgrade::Remove-Unused-Dependencies "true";
      Unattended-Upgrade::Automatic-Reboot "false";
      EOF
      
      cat > /etc/apt/apt.conf.d/20auto-upgrades << 'EOF'
      APT::Periodic::Update-Package-Lists "1";
      APT::Periodic::Unattended-Upgrade "1";
      APT::Periodic::AutocleanInterval "7";
      EOF
      
      systemctl enable unattended-upgrades
      systemctl start unattended-upgrades
      
      if systemctl is-active --quiet unattended-upgrades; then
        echo "✓ Automatic security updates enabled"
      else
        echo "WARNING: Automatic updates configuration may have failed"
      fi

  # Main deployment script
  - path: /tmp/deploy-dokploy.sh
    permissions: '0755'
    content: |
      #!/bin/bash
      set -euo pipefail
      export DEBIAN_FRONTEND=noninteractive
      
      /tmp/early-network-setup.sh
      /tmp/run-apt.sh update -y && /tmp/run-apt.sh upgrade -y
      /tmp/install-tailscale.sh
      /tmp/harden-ssh.sh
      /tmp/setup-docker-volume-and-install.sh
      /tmp/setup-cloudflare-tunnel.sh
      /tmp/install-dokploy.sh
      /tmp/harden-server.sh
      /tmp/setup-auto-updates.sh
      
      # User creation: multi-admin takes precedence over single-user
      ADMIN_USER_COUNT=$(jq -r '.users | length' /tmp/admin-users.json 2>/dev/null || echo "0")
      if [ "$ADMIN_USER_COUNT" -gt 0 ]; then
        echo "Using multi-admin user configuration ($ADMIN_USER_COUNT users)"
        /tmp/create-admin-users.sh
      else
        echo "Using legacy single-user configuration"
        /tmp/create-primary-user.sh
        
        if [ "${create_primary_user}" = "true" ] && [ -n "${primary_username}" ]; then
          if id "${primary_username}" >/dev/null 2>&1; then
            usermod -aG docker "${primary_username}"
            echo "✓ Primary user added to docker group"
          fi
        fi
      fi
      
      echo ""
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo "🎉 Deployment Complete!"
      echo "🔒 Dashboard: http://${tailscale_hostname}:3000"
      echo "   IP: $(tailscale ip -4 2>/dev/null || echo 'tailscale ip -4')"
      echo "🌐 Traefik: Ports 80 (HTTP) and 443 (HTTPS)"
      echo "☁️  CF Tunnel: Configure in dashboard"
      echo "📋 Next: Connect Tailscale → Open dashboard"
      echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
      echo ""
      USER_NAME="${primary_username}"
      if [ "${create_primary_user}" != "true" ] || [ -z "$USER_NAME" ]; then
        USER_NAME="ubuntu"
      fi

runcmd:
  - stdbuf -o0 /tmp/deploy-dokploy.sh 2>&1 | tee /var/log/dokploy-deployment.log


