# 10. Maintenance and Backups

This guide covers routine maintenance tasks and critical backup procedures to keep your Dokploy instance healthy and secure.

---

## Routine Maintenance

Regular check-ups can prevent issues before they become critical.

### **Monthly Checks**

-   **Check for Kernel Updates**: The server automatically installs security updates but does not reboot. If a kernel update requires a reboot, a file will be created. It is best to reboot during a planned maintenance window.

    ```bash
    # Check if a reboot is required
    [ -f /var/run/reboot-required ] && echo "Reboot Required"
    ```

-   **Review Security Logs**: Check the unattended-upgrades log to ensure security patches are being applied correctly.

    ```bash
    cat /var/log/unattended-upgrades/unattended-upgrades.log
    ```

-   **Check Disk Space**: Monitor your disk usage to ensure you are not running out of space.

    ```bash
    df -h
    ```

-   **Review Fail2ban**: Check the status of Fail2ban to see if it has blocked any malicious IPs.

    ```bash
    sudo fail2ban-client status sshd
    ```

### **As Needed**

-   **Update Tailscale**: Keep your Tailscale client up-to-date.

    ```bash
    sudo tailscale update
    ```

-   **Prune Docker Resources**: If you frequently deploy and remove applications, you can free up disk space by pruning unused Docker images, networks, and volumes.

    ```bash
    # This will remove all unused Docker resources. Use with caution.
    docker system prune -a
    ```

---

## Backup and Restore

Backups are critical for disaster recovery. The most important data to protect is your Dokploy database and your Terraform state.

### **Critical Data to Back Up**

1.  **Dokploy PostgreSQL Database**: This contains all your Dokploy configuration, including users, applications, and deployment settings. It is stored in a Docker volume managed by Dokploy.
2.  **`terraform.tfstate` File**: This file, located in the root of your project directory, contains the state of your managed infrastructure. **Losing this file can be catastrophic**, as Terraform will lose track of the resources it created.
3.  **`terraform.tfvars` File**: This file contains your specific configuration.
4.  **Bitwarden Secrets**: Your secrets are already securely backed up by Bitwarden, but you should ensure you have access to your Bitwarden account.

### **Backup Methods**

-   **Dokploy Database**: Use Dokploy’s built-in backup feature (if available) or perform a manual `pg_dump`.

    ```bash
    # Find the name of your dokploy-postgres container
    docker ps | grep postgres

    # Perform the dump
    docker exec <postgres-container-name> pg_dump -U <db_user> -d <db_name> > dokploy_backup.sql
    ```

-   **Terraform State**: **Do not store the `.tfstate` file in a public Git repository.** The best practice is to use [Terraform Remote State](https://developer.hashicorp.com/terraform/language/state/remote), which stores the state file in a secure, remote location like an S3 bucket. For a simpler approach, ensure the `.tfstate` file is included in your regular local machine backups.
