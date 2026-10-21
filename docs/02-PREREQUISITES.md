# 2. Prerequisites

Before you begin, you must have accounts with the following services and the necessary tools installed on your local machine.

## Required Accounts

1.  **Oracle Cloud Infrastructure (OCI) Account**
    -   **URL**: [cloud.oracle.com](https://www.oracle.com/cloud/free/)
    -   **Requirement**: A Free Tier or Pay-As-You-Go (PAYG) account. This project is designed to fit within the "Always Free" resource limits.

2.  **Bitwarden Account with Secrets Manager**
    -   **URL**: [bitwarden.com](https://bitwarden.com/products/secrets-manager/)
    -   **Requirement**: A Bitwarden account with the Secrets Manager add-on enabled. This is used to securely store and retrieve all the credentials needed for the deployment.

3.  **Tailscale Account**
    -   **URL**: [tailscale.com](https://tailscale.com/)
    -   **Requirement**: A free "Personal" plan is sufficient. This will create the private VPN for accessing your server's management interfaces.

4.  **Cloudflare Account**
    -   **URL**: [cloudflare.com](https://www.cloudflare.com/)
    -   **Requirement**: A free account is all you need. Your domain must be managed by Cloudflare's DNS to use Cloudflare Tunnel.

5.  **A Domain Name**
    -   **Requirement**: You must own a domain name and have it configured to use Cloudflare's nameservers.

## Required Local Tools

1.  **Terraform (v1.0 or higher)**
    -   **Purpose**: The Infrastructure as Code tool used to automate the entire deployment.
    -   **Installation**: Follow the official [Terraform Install Guide](https://developer.hashicorp.com/terraform/downloads).

2.  **Bitwarden CLI (`bws`)**
    -   **Purpose**: The command-line tool for interacting with Bitwarden Secrets Manager.
    -   **Installation**: Follow the official [Bitwarden Secrets Manager CLI Guide](https://bitwarden.com/help/secrets-manager-cli/).

3.  **An SSH Key Pair**
    -   **Purpose**: Used for secure access to your server. You will provide the public key to Terraform.
    -   **Generation**: If you don't have one, follow the [GitHub guide on generating SSH keys](https://docs.github.com/en/authentication/connecting-to-github-with-ssh/generating-a-new-ssh-key-and-adding-it-to-the-ssh-agent).

---

Once you have all these prerequisites in place, you can proceed to the setup guides for each service.
