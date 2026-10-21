# Anonymized Logging Feature

The verification script now includes **automatic anonymized logging** to make troubleshooting safe and secure.

## How It Works

When you run the verification script:

```bash
sudo ./verify-installation.sh
```

It automatically creates **two log files**:

### 1. verification.log (Full Log)
**⚠️ KEEP PRIVATE**

Contains all details including:
- Your actual hostname
- Tailscale IP addresses
- Public IP address
- Usernames
- SSH keys
- Container names
- Full system information

**Use this for:** Your own records and detailed troubleshooting

**Never share this file** - it contains sensitive infrastructure information

### 2. verification-safe.log (Anonymized Log)
**✅ SAFE TO SHARE**

All sensitive information is automatically replaced with placeholders:

| Original | Replaced With |
|----------|---------------|
| `dokploy-server` | `<HOSTNAME>` |
| `100.x.y.z` (Tailscale IP) | `<TAILSCALE_IP>` |
| `203.0.113.42` (public IP) | `<PUBLIC_IP>` |
| `alice` | `<USER>` |
| `ssh-ed25519 AAAAC3...` | `<SSH_KEY>` |
| `admin@example.com` | `<EMAIL>` |

**Use this for:** Sharing with support, posting in forums, or sending to consultants

## Example Output

### Before Anonymization (verification.log)
```
Testing: Tailscale Connection Status
✓ PASS: Tailscale is connected
ℹ INFO: Tailscale IP: 100.x.y.z
ℹ INFO: Tailscale Hostname: dokploy-server
```

### After Anonymization (verification-safe.log)
```
Testing: Tailscale Connection Status
✓ PASS: Tailscale is connected
ℹ INFO: Tailscale IP: <TAILSCALE_IP>
ℹ INFO: Tailscale Hostname: <TAILSCALE_HOSTNAME>
```

## What Gets Anonymized

### Network Information
- **Hostnames**: Your server's hostname
- **Tailscale IPs**: All 100.x.x.x addresses
- **Public IPs**: Your server's public IP
- **Other IPs**: Any other IP addresses found

### User Information
- **Usernames**: System and custom usernames
- **Email addresses**: Any email addresses in output
- **SSH keys**: Public key content

### System Information
**NOT anonymized** (safe to share):
- Ubuntu version
- Service status (running/stopped)
- Software versions (Docker, Dokploy, etc.)
- Error messages
- Test results (pass/fail/warn)
- Container counts
- Disk usage

## Usage Examples

### Normal Run
```bash
sudo ./verify-installation.sh
```

Output:
```
Logs saved:
  - Full log: verification.log (keep private)
  - Safe log: verification-safe.log (safe to share for troubleshooting)
```

### Debug Mode
```bash
sudo ./verify-installation.sh -d
```

Both logs are still created, even in debug mode.

### Sharing for Troubleshooting

If you need help:

1. Run the verification script
2. **Share ONLY** `verification-safe.log`
3. Keep `verification.log` private

Example:
```bash
# Run verification
sudo ./verify-installation.sh

# Upload the safe log
cat verification-safe.log
# Copy and paste this output to support/forums
```

## What's Safe in the Anonymized Log?

The anonymized log is designed to be **safe to share publicly**. It contains:

✅ **Safe Information:**
- Service status (running/stopped)
- Software versions
- Test results
- Error messages
- Configuration issues
- Container counts
- Disk usage statistics

❌ **Removed Information:**
- Your server's identity
- Network addresses
- User accounts
- Authentication details
- Domain names (partially)

## Technical Details

### Anonymization Process

The script uses `sed` to perform pattern matching and replacement:

1. **Collect sensitive data** during the verification process
2. **Store in associative array** for later replacement
3. **Create full log** with all details
4. **Copy and anonymize** to create safe log
5. **Add header** to safe log explaining anonymization

### Anonymization Rules

```bash
# Hostname
sed -i "s/${HOSTNAME}/<HOSTNAME>/g"

# Tailscale IPs (100.x.x.x)
sed -i -E 's/100\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}/<TAILSCALE_IP>/g'

# Public IPs
sed -i -E 's/([0-9]{1,3}\.){3}[0-9]{1,3}/<IP_ADDRESS>/g'

# Usernames (UID >= 1000)
sed -i -E "s/($users)/<USER>/g"

# SSH keys
sed -i -E 's/ssh-[a-z0-9]+ [A-Za-z0-9+\/=]+ .*/<SSH_KEY>/g'

# Email addresses
sed -i -E 's/[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}/<EMAIL>/g'
```

## Limitations

### What's NOT Anonymized

Some information may still be present:
- **Common domain names** (google.com, github.com, etc.) - kept for context
- **Generic paths** (/var/log, /home, etc.) - standard paths
- **Software names** (Docker, Dokploy, etc.) - needed for troubleshooting
- **Error messages** - needed to diagnose issues

### Edge Cases

If you have:
- **Custom domain names** in error messages
- **Proprietary software names** in logs
- **Company-specific identifiers** in container names

You may want to manually review `verification-safe.log` before sharing.

## Best Practices

### For Users

1. **Always run the script** when troubleshooting
2. **Keep verification.log private** - it's for your records
3. **Share verification-safe.log** when asking for help
4. **Review the safe log** before sharing if you have custom/proprietary information

### For Support Staff

When requesting logs from users:
1. Ask for `verification-safe.log` specifically
2. Explain that it's anonymized and safe to share
3. If more details are needed, request specific sections from `verification.log`

## Security Considerations

### What Could Still Be Identified?

Even with anonymization:
- **Infrastructure patterns** (number of containers, services used)
- **Configuration choices** (Ubuntu version, software versions)
- **Deployment issues** (error patterns)

This is intentional - you need this information for troubleshooting.

### Additional Privacy

If you need even more privacy:
1. Review `verification-safe.log` manually
2. Remove any additional sensitive information
3. Consider using a private support channel

## Troubleshooting the Anonymization

### Verify Anonymization Worked

```bash
# Check for your hostname (replace with your real hostname)
grep "your-hostname" verification-safe.log
# Should return nothing

# Check for placeholders
grep "<HOSTNAME>" verification-safe.log
# Should show replacements
```

### Manual Anonymization

If you need to anonymize additional information:

```bash
# Copy the safe log
cp verification-safe.log verification-custom.log

# Replace custom information
sed -i 's/my-company/COMPANY/g' verification-custom.log
sed -i 's/secret-project/PROJECT/g' verification-custom.log
```

## Example Anonymized Log Header

```
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
ANONYMIZED VERIFICATION LOG
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
This log has been automatically anonymized for safe sharing.
Sensitive information has been replaced with placeholders:
  - <HOSTNAME>: Server hostname
  - <TAILSCALE_IP>: Tailscale IP address (100.x.x.x)
  - <TAILSCALE_HOSTNAME>: Tailscale hostname
  - <PUBLIC_IP>: Public IP address
  - <IP_ADDRESS>: Other IP addresses
  - <USER>: Usernames
  - <SSH_KEY>: SSH keys
  - <EMAIL>: Email addresses

This log is safe to share for troubleshooting purposes.
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
```

## Summary

The anonymized logging feature makes it **safe and easy** to get help with your Dokploy deployment:

- ✅ **Automatic** - no manual redaction needed
- ✅ **Comprehensive** - removes all sensitive information
- ✅ **Useful** - keeps diagnostic information intact
- ✅ **Transparent** - clearly labeled with what was anonymized

You can confidently share `verification-safe.log` for troubleshooting without exposing your infrastructure details.
