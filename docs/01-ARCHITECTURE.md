# 1. Project Architecture

This document provides a high-level overview of the technical architecture and security model for the Dokploy Terraform deployment.

## Technical Stack

| Component | Technology | Purpose |
| :--- | :--- | :--- |
| Infrastructure | Terraform | Infrastructure as Code |
| Secrets Management | Bitwarden | Secure credential storage |
| VPN | Tailscale | Private network access |
| Tunnel | Cloudflare Tunnel | Public application exposure |
| Reverse Proxy | Traefik v3 | Application routing (integrated in Dokploy) |
| Platform | Dokploy | Modern self-hosted PaaS |
| Database | PostgreSQL | Dokploy data storage |
| Queue | Redis | Deployment queue management |
| Container Orchestration | Docker Swarm | Required by Dokploy |
| SSH Protection | Fail2ban | Brute force prevention |
| Updates | Unattended-Upgrades | Automatic security patches |

## Security Model Explained

### Network Segmentation

The core of this architecture is the strict separation between private management interfaces and public-facing applications.

-   **Private Network (Tailscale)**: The Dokploy dashboard (port 3000) and SSH (port 22) are only accessible to authenticated users on your private Tailscale network. These ports are **never** exposed to the public internet.
-   **Public Network (Cloudflare Tunnel)**: Your deployed applications are exposed publicly via an outbound-only connection from the `cloudflared` service on your server to the Cloudflare edge. This means you do not need to open any inbound firewall ports (like 80 or 443) on your server, significantly reducing the attack surface.

### Traffic Flow

1.  **Admin Traffic**: A user on your Tailscale network connects directly to the server's Tailscale IP address to access the Dokploy dashboard or SSH.
2.  **Public Traffic**: A visitor to your application is routed through Cloudflare's network. The request is then sent through the secure tunnel to the `cloudflared` service on your server. `cloudflared` forwards the request to Traefik on `localhost:80`, and Traefik routes it to the appropriate application container.

This model ensures that all administrative access is encrypted and authenticated through a separate, private channel, while all public traffic benefits from Cloudflare's security features (DDoS protection, WAF, etc.).
