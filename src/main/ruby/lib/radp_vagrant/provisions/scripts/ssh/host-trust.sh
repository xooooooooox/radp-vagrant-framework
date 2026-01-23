#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:ssh/host-trust
# Add host SSH public key to guest authorized_keys for passwordless SSH access
#
# Environment variables (one of the following is required):
#   HOST_SSH_PUBLIC_KEY      - The host's SSH public key content (e.g., "ssh-rsa AAAA... user@host")
#   HOST_SSH_PUBLIC_KEY_FILE - Path to the host's SSH public key file (e.g., ~/.ssh/id_rsa.pub)
#
# Optional environment variables:
#   SSH_USERS - Comma-separated list of users to configure (default: vagrant)
#
# Usage in vagrant.yaml:
#   provisions:
#     # Option 1: Specify key content directly
#     - name: radp:ssh/host-trust
#       enabled: true
#       env:
#         HOST_SSH_PUBLIC_KEY: "ssh-rsa AAAA... user@host"
#         SSH_USERS: "vagrant,root"
#
#     # Option 2: Specify key file path (will be read at provision time)
#     - name: radp:ssh/host-trust
#       enabled: true
#       env:
#         HOST_SSH_PUBLIC_KEY_FILE: "/vagrant/host_ssh_key.pub"
#         SSH_USERS: "vagrant,root"

echo "[INFO] Configuring SSH host trust..."

# Resolve public key from content or file
PUBLIC_KEY=""

if [[ -n "${HOST_SSH_PUBLIC_KEY:-}" ]]; then
  PUBLIC_KEY="$HOST_SSH_PUBLIC_KEY"
  echo "[INFO] Using SSH public key from HOST_SSH_PUBLIC_KEY"
elif [[ -n "${HOST_SSH_PUBLIC_KEY_FILE:-}" ]]; then
  if [[ -f "$HOST_SSH_PUBLIC_KEY_FILE" ]]; then
    PUBLIC_KEY=$(cat "$HOST_SSH_PUBLIC_KEY_FILE")
    echo "[INFO] Using SSH public key from file: $HOST_SSH_PUBLIC_KEY_FILE"
  else
    echo "[ERROR] SSH public key file not found: $HOST_SSH_PUBLIC_KEY_FILE"
    exit 1
  fi
else
  echo "[ERROR] Either HOST_SSH_PUBLIC_KEY or HOST_SSH_PUBLIC_KEY_FILE must be provided"
  exit 1
fi

# Validate key format (basic check)
if [[ ! "$PUBLIC_KEY" =~ ^ssh-(rsa|ed25519|ecdsa|dss) ]]; then
  echo "[WARN] SSH public key does not appear to be in standard format"
fi

# Default users to configure
SSH_USERS="${SSH_USERS:-vagrant}"

# Function to add public key for a user
add_key_for_user() {
  local user="$1"
  local key="$2"
  local home_dir

  # Get user's home directory
  if [[ "$user" == "root" ]]; then
    home_dir="/root"
  else
    home_dir=$(getent passwd "$user" | cut -d: -f6)
    if [[ -z "$home_dir" ]]; then
      echo "[WARN] User '$user' not found, skipping"
      return 0
    fi
  fi

  local ssh_dir="${home_dir}/.ssh"
  local auth_keys="${ssh_dir}/authorized_keys"

  # Create .ssh directory if needed
  if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown "${user}:$(id -gn "$user")" "$ssh_dir"
    echo "[INFO] Created ${ssh_dir}"
  fi

  # Create authorized_keys if needed
  if [[ ! -f "$auth_keys" ]]; then
    touch "$auth_keys"
    chmod 600 "$auth_keys"
    chown "${user}:$(id -gn "$user")" "$auth_keys"
    echo "[INFO] Created ${auth_keys}"
  fi

  # Check if key already exists
  if grep -qF "$key" "$auth_keys" 2>/dev/null; then
    echo "[OK] Host public key already exists for user '$user'"
  else
    echo "$key" >> "$auth_keys"
    echo "[INFO] Added host public key for user '$user'"
  fi
}

# Process each user
IFS=',' read -ra users <<< "$SSH_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    add_key_for_user "$user" "$PUBLIC_KEY"
  fi
done

echo "[INFO] SSH host trust configuration completed"
