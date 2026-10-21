> **Note:** The Oracle Cloud Infrastructure (OCI) console can be complex. This guide provides direct links and step-by-step instructions to help you find the exact information you need.

# 3. Oracle Cloud Infrastructure (OCI) Setup

This guide will walk you through finding the four essential pieces of OCI information required by Terraform and Bitwarden:

1.  **Tenancy OCID**: The unique identifier for your entire OCI account.
2.  **User OCID**: The unique identifier for your specific user account.
3.  **API Key Fingerprint**: A short identifier for the API key you will generate.
4.  **API Private Key**: The actual private key file used to authenticate API requests.

---

### **Step 1: Find Your Tenancy OCID**

Your Tenancy OCID is the top-level identifier for your account.

1.  Log in to the [OCI Console](https://cloud.oracle.com/).
2.  Click the **Profile icon** in the top-right corner.
3.  Click on your **Tenancy name** (e.g., `your-tenancy-name`).
4.  On the Tenancy Details page, you will see your **Tenancy OCID**. Click the **Copy** link to copy it to your clipboard.

    *You will need this for your Bitwarden secrets.*

### **Step 2: Find Your User OCID**

Next, you need the OCID for the user you will be using to run Terraform.

1.  Click the **Profile icon** in the top-right corner.
2.  Click on your **username** to go to your User Details page.
3.  On this page, you will find your **User OCID**. Click **Copy**.

    *You will need this for your Bitwarden secrets.*

### **Step 3: Generate an API Key**

Terraform uses an API key to authenticate with OCI. You will generate a key pair directly in the OCI console.

1.  While on your User Details page, scroll down to the **API keys** section on the left-hand side.
2.  Click the **Add API key** button.
3.  In the dialog box, select **Generate API key pair**.
4.  Click **Download private key** and save the `.pem` file to a secure location on your local machine (e.g., `~/.oci/oci_api_key.pem`). **You will not be able to download this key again.**
5.  Click the **Add** button.

### **Step 4: Get the API Key Fingerprint**

Once the key is added, a **Configuration File** preview will be displayed. This contains the **fingerprint** you need.

1.  In the Configuration File preview box, find the `fingerprint` line.
2.  Copy the value of the fingerprint (it will look like `aa:bb:cc:dd:...`).

    *You will need this for your Bitwarden secrets.*

---

## Cost Management: Setting Up a Budget Alert

To ensure you never receive an unexpected bill, you can set up a budget alert that notifies you if your spending exceeds a certain amount (e.g., $1).

1.  In the OCI console, use the top search bar to search for **Budgets**.
2.  Click on **Budgets** under the "Billing & Cost Management" service.
3.  Select your **Compartment** and click **Create budget**.
4.  Configure the budget:
    *   **Name**: `Always Free Alert`
    *   **Budget Amount**: `1`
5.  Configure the alert rule:
    *   **Threshold**: `100` percent of the budget amount.
    *   **Email Recipients**: Enter your email address.
6.  Click **Create**.

Now, if your account usage ever results in a charge of $1 or more, you will receive an immediate email notification, giving you complete peace of mind.

---

With your Tenancy OCID, User OCID, API Key Fingerprint, and the content of your downloaded `.pem` file, you are ready to proceed to the Bitwarden setup.
