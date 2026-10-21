# 9. Troubleshooting

This guide covers common issues you might encounter during or after deployment.

---

### **Terraform Error: Metadata size cannot be larger than 32000 bytes**

-   **Cause 1 (most common)**: Your `terraform.tfvars` contains many comment lines. Terraform includes all comments in the user data sent to OCI, exceeding the 32KB limit.
    -   **Solution**: Keep `terraform.tfvars` minimal — only actual variable assignments, no comment lines. Copy from `terraform.tfvars.example` and strip the comments, so the final file is ~1-2KB rather than 10-12KB.
-   **Cause 2 (less obvious — check this even with a clean `terraform.tfvars`)**: `main.tf` sends the cloud-init config to OCI via `base64encode()` (see the `user_data` field). Base64 encoding adds **~37% overhead** — a 25KB rendered template becomes ~34KB encoded, blowing the 32KB limit even though the *raw* template looks comfortably under it.
    -   **Solution**: When estimating headroom, always multiply the rendered `cloud-init.yaml.tpl` size (after variable substitution) by **1.37**, not just compare the raw template against 32,000 bytes. If you're near the limit, trim verbose `echo` messages/comments in `cloud-init.yaml.tpl` itself (the template, not just `terraform.tfvars`) to claw back headroom.

### **Terraform Error: 401-NotAuthenticated, Failed to verify the HTTP(S) Signature**

-   **Cause**: Your OCI API credentials (private key, fingerprint) are correct, but your OCI **user/group has no IAM policy** granting it permission to manage compute/network/storage resources. This is a permissions problem, not a credentials problem.
-   **Solution (personal/single-user accounts — simplest)**: In the OCI Console, go to **Identity & Security → Groups**, add your user to the **Administrators** group. For a shared/production tenancy, scope a dedicated policy instead (e.g. `Allow group TerraformAdmins to manage all-resources in compartment <your-compartment>`) rather than granting tenancy-wide admin.

### **Cannot Access Dokploy Dashboard at `http://<hostname>:3000`**

-   **Cause 1**: You are not connected to your Tailscale VPN.
    -   **Solution**: Ensure the Tailscale client is running and connected on your local machine.

-   **Cause 2**: The Dokploy containers are not running.
    -   **Solution**: SSH into the server (`ssh your_user@<hostname>`) and run `docker ps | grep dokploy`. If the containers are not running, check their logs with `docker logs <container_name>`.

-   **Cause 3**: A firewall is blocking the connection.
    -   **Solution**: The `cloud-init` script should automatically configure `iptables` to allow Tailscale traffic. Verify this with `sudo iptables -L DOCKER-USER -n | grep tailscale0`.

### **Application Shows a 502 Bad Gateway Error**

-   **Cause**: The Cloudflare Tunnel can connect to your server, but it cannot reach the application via Traefik.
    -   **Solution 1**: Check that the application is actually running in Dokploy.
    -   **Solution 2**: Verify the **Published application route** configuration in your Cloudflare Tunnel. It **must** use `HTTP` and `localhost:80`. Using `HTTPS` or any other port will fail.
    -   **Solution 3**: If you have set the **HTTP Host Header** (which is optional), ensure it exactly matches the domain you assigned in Dokploy (e.g., `app.your-domain.com`).
    -   **Solution 4**: Check the Traefik logs for errors: `docker logs dokploy-traefik`.

### **Cloudflare Tunnel is Not Running**

-   **Cause**: The `cloudflared` service may have failed to start.
-   **Solution**: SSH into the server and check the service status and logs.

    ```bash
    # Check status
    sudo systemctl status cloudflared

    # View logs
    sudo journalctl -u cloudflared -f

    # Restart the service
    sudo systemctl restart cloudflared
    ```

### **App Returns "No Available Server" (Cloudflare) or 502 After a Server Reboot**

-   **Cause**: A startup race condition, not a persistent misconfiguration. On boot, Docker starts all `restart: unless-stopped` containers ~simultaneously. Traefik's first service-discovery scan (via the Docker socket) can happen before an app container has fully registered with the Docker daemon — Traefik builds its routing table without that app's entry, and the table stays stale even after the app finishes starting seconds later. All underlying services (tunnel, `cloudflared`, Docker, the app container, `dokploy-traefik`) will show healthy despite this.
-   **Immediate fix**: `docker restart dokploy-traefik` — forces a fresh discovery scan, resolves instantly.
-   **Permanent fix**: add a one-shot `systemd` unit that restarts Traefik ~30s after Docker starts, every boot:

    ```ini
    # /etc/systemd/system/traefik-refresh.service
    [Unit]
    Description=Refresh Traefik routing after boot to ensure dynamic discovery
    After=docker.service
    Requires=docker.service

    [Service]
    Type=oneshot
    ExecStartPre=/bin/sleep 30
    ExecStart=/usr/bin/docker restart dokploy-traefik
    RemainAfterExit=yes

    [Install]
    WantedBy=multi-user.target
    ```

    ```bash
    sudo systemctl daemon-reload
    sudo systemctl enable traefik-refresh.service
    sudo systemctl start traefik-refresh.service   # test it once manually
    ```

    This fix has been verified in production. Rather than forcing a disruptive reboot, you can confirm the race via `docker inspect` container start-timestamps at the last boot: a spread of ~25-30s between `dokploy-traefik`'s start and the last app container to register is consistent with the race described above. Enabling persistent journal storage (`/var/log/journal`) at the same time is recommended, so the next occurrence has real logs to confirm against rather than only container-timestamp inference.

### **Docker Swarm is Not Active**

-   **Cause**: Dokploy requires Docker Swarm mode to be active. The `cloud-init` script should handle this, but it can sometimes fail.
-   **Solution**: SSH into the server and check the Swarm status. If it is inactive, re-initialize it.

    ```bash
    # Check Swarm status
    docker info | grep Swarm

    # If inactive, re-initialize
    docker swarm init
    ```
