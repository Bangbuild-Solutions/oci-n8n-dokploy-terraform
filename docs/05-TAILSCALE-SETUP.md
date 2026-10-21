# 5. Tailscale Setup

[Tailscale](https://tailscale.com/) creates a secure, private network (a "tailnet") for your devices. This project uses it to ensure that your Dokploy dashboard and SSH access are never exposed to the public internet.

---

### **Step 1: Generate a Tailscale Auth Key**

An auth key is a single-use token that allows your new server to join your tailnet without manual approval.

1.  Log in to your [Tailscale Admin Console](https://login.tailscale.com/admin).
2.  Go to **Settings** > **Auth keys**.
3.  Click **Generate auth key...**.
4.  Configure the key:
    *   **Description**: `Dokploy OCI Server`
    *   **Reusable**: Keep this disabled (for single use).
    *   **Ephemeral**: Keep this disabled (so the server stays in your tailnet).
    *   **Tags**: Leave this blank for now.
5.  Click **Generate key**.
6.  **Copy the generated key** (it will start with `tskey-auth-` ) and save it. You will add this to Bitwarden Secrets Manager.

### **Step 2: Configure Tailscale ACLs (Access Control Lists)**

ACLs define what users and devices can access on your tailnet. For this project, we will create a secure policy that allows admins to access the server via SSH.

1.  In the Tailscale Admin Console, go to **Access Controls**.
2.  You will see a default policy. **Replace the entire content** with the policy below.

    ```json
    {
      // Define a group of administrators
      "groups": {
        "group:admins": [
          "your-tailscale-login-email@example.com"
        ]
      },

      // Define who can apply tags to devices
      "tagOwners": {
        "tag:server": ["group:admins"]
      },

      // Define access rules
      "acls": [
        // Allow all devices to connect to each other (standard for a trusted tailnet)
        {
          "action": "accept",
          "src":    ["autogroup:members"],
          "dst":    ["*:*"]
        }
      ],

      // Define SSH access rules
      "ssh": [
        {
          "action": "check",
          "src": ["group:admins"],
          "dst": ["tag:server"],
          "users": ["autogroup:nonroot", "ubuntu"]
        }
      ]
    }
    ```

3.  **IMPORTANT**: In the `"group:admins"` section, replace `"your-tailscale-login-email@example.com"` with the actual email address you use to log in to Tailscale.

4.  Click **Save**.

### **What This ACL Policy Does**

-   **`groups`**: Creates a group named `admins` that contains your user account.
-   **`tagOwners`**: Specifies that only users in the `admins` group can assign the `server` tag to a device. The Terraform script will automatically tag your new Dokploy server with `tag:server`.
-   **`acls`**: Allows all devices within your tailnet to communicate with each other. This is the default, trusted behavior.
-   **`ssh`**: This is the critical part. It allows any user in the `admins` group to initiate an SSH connection to any server tagged as `server`, and they can log in as any non-root user (like `ubuntu` or the custom users you create).

---

With your auth key generated and ACLs configured, you are ready to set up Cloudflare.
