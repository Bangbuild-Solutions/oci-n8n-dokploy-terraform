# 7. Deployment

With all prerequisites met and secrets configured, you are now ready to deploy the Dokploy server using Terraform.

---

### **Step 1: Clone the Repository**

If you haven't already, clone this repository to your local machine and navigate into the directory.

```bash
git clone https://github.com/your-org-name/dokploy-terraform-production.git
cd dokploy-terraform-production/
```

### **Step 2: Configure Terraform Variables**

This project uses a `terraform.tfvars` file to define your specific configuration. Keep it minimal (only actual variable assignments, no comment lines) to avoid exceeding OCI's cloud-init size limits.

1.  **Copy the Example File**:

    ```bash
    cp terraform.tfvars.example terraform.tfvars
    ```

2.  **Edit the Configuration**:

    Open the `terraform.tfvars` file in a text editor and replace the placeholder values with your actual settings. This includes your OCI Compartment OCID, your SSH public key, and the username(s) you wish to create.

    ```bash
    nano terraform.tfvars
    ```

    Refer to the `EXAMPLES.md` file for different configuration scenarios, such as setting up a single admin user versus multiple users, or enabling a dedicated Docker volume.

### **Step 3: Initialize Terraform**

This command initializes your Terraform working directory, downloading the necessary providers (like the OCI provider).

```bash
make init
```

### **Step 4: Plan the Deployment**

This command creates an execution plan. It will connect to OCI, check your configuration, and show you exactly what resources it is going to create, modify, or destroy. This is a great way to review your changes before applying them.

```bash
make plan
```

### **Step 5: Apply the Configuration**

This is the final step that actually builds your infrastructure. Terraform will provision the OCI compute instance, set up networking, and run the `cloud-init` script to install Dokploy and all other software. This entire process can take **15-20 minutes**.

```bash
make apply
```

Terraform will stream the output of the `cloud-init` script, so you can monitor the installation progress in real-time. Wait for the `terraform apply` command to complete successfully.

---

Once the command finishes, your server is built and Dokploy is installed. The next step is to verify the installation and learn how to expose your first application.
