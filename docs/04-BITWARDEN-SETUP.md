# 4. Bitwarden Secrets Manager Setup

This project uses [Bitwarden Secrets Manager](https://bitwarden.com/products/secrets-manager/) to securely handle all your credentials. Instead of writing sensitive information directly into your Terraform files, you will store them in Bitwarden, and the `get-secrets.sh` script will fetch them at runtime.

---

### **Step 1: Create a Project in Bitwarden**

First, you need to create a project to hold the secrets for this deployment.

1.  Log in to your Bitwarden Web Vault.
2.  In the top navigation, click on **Secrets Manager**.
3.  In the Secrets Manager interface, click the **New project** button.
4.  Give your project a name (e.g., `Dokploy OCI Production`) and click **Save**.

### **Step 2: Create a Service Account and Access Token**

A Service Account is a machine user that will be used to programmatically access your secrets.

1.  In the Secrets Manager interface, go to the **Service Accounts** tab.
2.  Click **New service account**.
3.  Give it a name (e.g., `Terraform Deployer`) and select the project you just created.
4.  Grant it **Read** access.
5.  Click **Save**. A new **Access Token** will be generated. **Copy this token immediately and save it somewhere safe.** You will not be able to see it again.

### **Step 3: Add Your Secrets**

Now, you will add the six required secrets to your project. For each secret, click the **New secret** button and enter the name and value.

| Secret Name | Value | Source |
| :--- | :--- | :--- |
| `tenancy_ocid` | `ocid1.tenancy.oc1..` | From the [OCI Setup Guide](./03-OCI-SETUP.md) |
| `user_ocid` | `ocid1.user.oc1..` | From the [OCI Setup Guide](./03-OCI-SETUP.md) |
| `fingerprint` | `aa:bb:cc:dd:...` | From the [OCI Setup Guide](./03-OCI-SETUP.md) |
| `oci_private_key` | `-----BEGIN RSA PRIVATE KEY-----...` | The full content of the `.pem` file you downloaded from OCI |
| `tailscale_auth_key` | `tskey-auth-xxxxxxxxxx` | From the [Tailscale Setup Guide](./05-TAILSCALE-SETUP.md) |
| `cf_tunnel_token` | `eyJhIjoixxxxxxxxxx...` | From the [Cloudflare Setup Guide](./06-CLOUDFLARE-SETUP.md) |

**Important**: When adding the `oci_private_key`, make sure you copy the *entire content* of the `.pem` file, including the `-----BEGIN...` and `-----END...` lines.

### **Step 4: Configure the Bitwarden CLI**

Finally, you need to configure your local environment so the `get-secrets.sh` script can authenticate with Bitwarden.

1.  **Install the `bws` CLI** if you haven't already by following the [official guide](https://bitwarden.com/help/secrets-manager-cli/).

    ```bash
    # macOS
    brew install bitwarden/tap/bws
    
    # Linux
    wget https://github.com/bitwarden/sdk/releases/latest/download/bws-x86_64-unknown-linux-gnu.zip
    unzip bws-x86_64-unknown-linux-gnu.zip
    sudo mv bws /usr/local/bin/
    chmod +x /usr/local/bin/bws
    ```

2.  **Set Environment Variables**: Open your shell profile file (e.g., `~/.bashrc`, `~/.zshrc`) and add the following lines, replacing the placeholder values with your actual Access Token and Project ID.

    ```bash
    export BWS_ACCESS_TOKEN=\"your_bitwarden_access_token\"
    export BWS_PROJECT_ID=\"your_bitwarden_project_id\"
    ```

3.  **Reload Your Shell**: Close and reopen your terminal or run `source ~/.bashrc` (or `source ~/.zshrc`) to apply the changes.

---

Your environment is now configured to securely fetch secrets from Bitwarden. You can test this by running the `make secrets` command from the root of the repository, which should display a JSON object containing your secrets.
