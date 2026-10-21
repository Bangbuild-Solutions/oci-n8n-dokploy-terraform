# 8. Post-Deployment: Verification and Exposing Applications

Your server is now running, but there are two final steps: verifying that everything installed correctly and learning how to expose an application to the public internet.

---

### **Step 1: Verify the Installation**

This project includes a comprehensive verification script that checks the status of all key components.

1.  **Connect to your Tailscale network** on your local machine.

2.  **Run the verification command**:

    ```bash
    make verify
    ```

    This command will automatically SSH into your new server and execute the `verify-installation.sh` script. It will print a detailed report, checking the status of Tailscale, Dokploy, Traefik, Docker Swarm, Cloudflare Tunnel, and more.

3.  **Access the Dokploy Dashboard**:

    -   Open your browser and navigate to `http://<your-tailscale-hostname>:3000` (replace `<your-tailscale-hostname>` with the hostname you set in `terraform.tfvars`).
    -   On your first visit, you will be prompted to create your Dokploy admin account. **Do this immediately.**

### **Step 2: Expose Your First Application**

Now, let's deploy a sample application and make it public.

1.  **Deploy an App in Dokploy**: In the Dokploy dashboard, deploy a new application (e.g., a simple Nginx or Ghost blog). During setup, assign it a public domain, such as `app.your-domain.com`.

2.  **Configure the Cloudflare Tunnel Route**:

    -   Navigate to the [Cloudflare Zero Trust Dashboard](https://one.dash.cloudflare.com/).
    -   Go to **Networks** > **Tunnels**.
    -   Find your tunnel, click the three dots, and select **Configure**.
    -   Go to the **Published application routes** tab and click **Add a route**.

3.  **Fill in the Route Details**:

| Setting | Value |
| :--- | :--- |
| **Subdomain** | `app` |
| **Domain** | `your-domain.com` |
| **Type** | `HTTP` |
| **URL** | `localhost:80` |

4.  **Save** the route. You do not need to set the HTTP Host Header unless you have a specific use case that requires overriding it.

### **Why This Works: The Traefik Handoff**

This configuration is simple but powerful. Here is the flow:

1.  Cloudflare receives a request for `https://app.your-domain.com`.
2.  It sends the request through the secure tunnel to your server.
3.  The `cloudflared` service on your server receives the request and forwards it to `localhost:80`, but it also passes along the original `Host: app.your-domain.com` header.
4.  **Traefik**, which is listening on `localhost:80`, sees this header and knows exactly which application container to route the request to.

This allows you to manage all your public routing from the Cloudflare dashboard without ever touching the server's firewall or reverse proxy configuration directly.
