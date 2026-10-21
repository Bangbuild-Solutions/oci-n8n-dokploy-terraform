# 6. Cloudflare Setup

[Cloudflare](https://www.cloudflare.com/) provides the public-facing side of this architecture. You will use two of its key features:

1.  **DNS**: To manage your domain.
2.  **Cloudflare Tunnel**: To securely connect your private server to the Cloudflare network, allowing you to expose applications without opening any firewall ports.

---

### **Step 1: Ensure Your Domain Uses Cloudflare DNS**

This is a prerequisite. Your domain must be active in your Cloudflare account and configured to use Cloudflare's nameservers. If you haven't done this, please follow the [official Cloudflare guide](https://developers.cloudflare.com/dns/zone-setups/full-setup/setup/) to add your site.

### **Step 2: Create a Cloudflare Tunnel**

A Tunnel is a secure, private connection between your server and the Cloudflare network.

1.  Log in to your [Cloudflare Dashboard](https://dash.cloudflare.com/).
2.  On the left-hand sidebar, go to **Zero Trust**.
3.  In the Zero Trust dashboard, go to **Networks** > **Tunnels**.
4.  Click the **Create a tunnel** button.
5.  Choose **Cloudflared** as the connector type and click **Next**.
6.  Give your tunnel a name (e.g., `dokploy-production-tunnel`) and click **Save tunnel**.

### **Step 3: Get Your Tunnel Token**

After saving the tunnel, you will be presented with a screen to install the connector. You don't need to run the commands, as Terraform will do this for you. You only need the **token**.

1.  In the code box provided, find the long string of characters that is your tunnel token. It is part of the `cloudflared service install <TOKEN>` command.
2.  **Copy this token**. It is a long alphanumeric string.
3.  Save this token. You will add it to Bitwarden Secrets Manager under the name `cf_tunnel_token`.

    *If you accidentally navigate away from this page, you can always find the token again by going to your tunnel's details page in the Cloudflare dashboard.*

### **A Note on the "Analytics" Section**

In some older documentation or guides, you may see references to an "Access" section in the Zero Trust dashboard. This has since been renamed. The key areas you will interact with are:

-   **Networks > Tunnels**: For creating and managing your tunnels and their Published application routes.
-   **Analytics & Logs > Access**: For viewing logs of who is accessing applications protected by Cloudflare Access policies (not directly used in this project's initial setup, but useful for monitoring later).

---

With your Cloudflare Tunnel created and the token saved to Bitwarden, you have all the necessary credentials. You are now ready to deploy the infrastructure.
