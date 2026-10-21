#!/bin/bash
# ====
# Bitwarden Secrets Manager CLI Integration Script for Terraform
# 
# This script fetches secrets from Bitwarden Secret Manager and outputs them
# in the format expected by Terraform's external data source.
#
# Required Environment Variables:
#   - BWS_ACCESS_TOKEN: Your Bitwarden Secret Manager access token
#   - BWS_PROJECT_ID: The project ID containing your secrets
#
# Required Secrets in Bitwarden (secret keys):
#   - tenancy_ocid: OCI tenancy OCID
#   - user_ocid: OCI user OCID
#   - fingerprint: OCI API key fingerprint
#   - oci_private_key: OCI API private key (full PEM content)
#   - tailscale_auth_key: Tailscale authentication key
#   - cf_tunnel_token: Cloudflare Tunnel token
#   - cf_account_id: (Optional) Cloudflare account ID
#   - cf_api_token: (Optional) Cloudflare API token
# ====

set -e
set -o pipefail

# --- Configuration ---
# NOTE: bitwarden/bws on Docker Hub is archived (no version tags remain, only
# `dev` and content-digest signatures) — Bitwarden's current official guidance
# points to ghcr.io/bitwarden/bws instead. Pinned to a real release tag rather
# than floating `latest`; bump deliberately when a newer bws release is needed.
BWS_IMAGE="ghcr.io/bitwarden/bws:2.1.0"

# --- Error Handling ---
error_exit() {
    echo "{\"error\": \"$1\"}" >&2
    exit 1
}

# --- Validation ---
if [ -z "$BWS_ACCESS_TOKEN" ]; then
    error_exit "BWS_ACCESS_TOKEN environment variable is not set"
fi

if [ -z "$BWS_PROJECT_ID" ]; then
    error_exit "BWS_PROJECT_ID environment variable is not set"
fi

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    error_exit "Docker is not installed or not in PATH"
fi

# --- Fetch and Transform Secrets ---
# This command:
# 1. Fetches all secrets from Bitwarden Secret Manager using Docker
# 2. Transforms the JSON array into a flat object with secret keys as keys
# 3. Ensures all values are strings (required by Terraform external data source)
# 4. Handles multi-line values (like private keys) by preserving newlines

SECRETS_JSON=$(docker run --rm \
  -e BWS_ACCESS_TOKEN="$BWS_ACCESS_TOKEN" \
  -e BWS_PROJECT_ID="$BWS_PROJECT_ID" \
  -e BWS_STATE_FOLDER="/tmp" \
  "$BWS_IMAGE" secret list "$BWS_PROJECT_ID" 2>/dev/null) || error_exit "Failed to fetch secrets from Bitwarden"

# Validate that we got JSON output
if [ -z "$SECRETS_JSON" ] || [ "$SECRETS_JSON" = "null" ]; then
    error_exit "No secrets returned from Bitwarden"
fi

# Transform the secrets JSON into the format Terraform expects
# The jq command:
# - Creates key-value pairs from the secret array
# - Ensures all values are strings
# - Preserves special characters and newlines in values (important for private keys)
# - Properly escapes the private key for JSON
RESULT=$(echo "$SECRETS_JSON" | jq -r '
  map({key: .key, value: .value}) | 
  from_entries | 
  to_entries | 
  map({
    key: .key, 
    value: (
      if .key == "oci_private_key" then
        (.value | tostring)
      else
        (.value | tostring)
      end
    )
  }) | 
  from_entries
') || error_exit "Failed to parse secrets JSON"

# Validate required secrets are present
REQUIRED_SECRETS=("tenancy_ocid" "user_ocid" "fingerprint" "oci_private_key" "tailscale_auth_key" "cf_tunnel_token")
for secret in "${REQUIRED_SECRETS[@]}"; do
    if ! echo "$RESULT" | jq -e "has(\"$secret\")" > /dev/null 2>&1; then
        error_exit "Required secret '$secret' not found in Bitwarden"
    fi
done

# Validate the private key format
PRIVATE_KEY=$(echo "$RESULT" | jq -r '.oci_private_key')
if [[ ! "$PRIVATE_KEY" =~ ^-----BEGIN.*PRIVATE\ KEY----- ]]; then
    error_exit "oci_private_key does not appear to be in valid PEM format. It should start with '-----BEGIN PRIVATE KEY-----' or '-----BEGIN RSA PRIVATE KEY-----'"
fi

if [[ ! "$PRIVATE_KEY" =~ -----END.*PRIVATE\ KEY-----$ ]]; then
    error_exit "oci_private_key does not appear to be in valid PEM format. It should end with '-----END PRIVATE KEY-----' or '-----END RSA PRIVATE KEY-----'"
fi

# Output the final JSON to stdout (this is what Terraform will read)
echo "$RESULT"
