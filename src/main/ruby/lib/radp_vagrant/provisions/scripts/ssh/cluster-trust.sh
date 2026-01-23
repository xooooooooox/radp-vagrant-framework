#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:ssh/cluster-trust
# Configure SSH trust between same users across VMs in the same cluster
#
# Each user gets their own key pair to ensure:
#   - vagrant@vmA <-> vagrant@vmB (same user trust)
#   - root@vmA <-> root@vmB (same user trust)
#   - vagrant@vmA cannot SSH to root@vmB (no cross-user trust)
#
# Required environment variables:
#   CLUSTER_SSH_KEY_DIR - Directory containing per-user key pairs
#                         Key naming: {dir}/id_{env}_{cluster}_{user} and {dir}/id_{env}_{cluster}_{user}.pub
#
# Optional environment variables:
#   SSH_USERS            - Comma-separated list of users to configure (default: vagrant)
#   TRUSTED_HOST_PATTERN - Custom host pattern for SSH config (default: auto-detect)
#
# Key file structure example (for env "dev", cluster "hadoop"):
#   /vagrant/keys/
#   ├── id_dev_hadoop_vagrant        # vagrant user's private key
#   ├── id_dev_hadoop_vagrant.pub    # vagrant user's public key
#   ├── id_dev_hadoop_root           # root user's private key
#   └── id_dev_hadoop_root.pub       # root user's public key
#
# Usage in vagrant.yaml (cluster level):
#   clusters:
#     - name: hadoop
#       common:
#         provisions:
#           - name: radp:ssh/cluster-trust
#             enabled: true
#             env:
#               CLUSTER_SSH_KEY_DIR: "/vagrant/keys"
#               SSH_USERS: "vagrant,root"

echo "[INFO] Configuring cluster SSH trust (per-user keys)..."

# Validate required environment variable
if [[ -z "${CLUSTER_SSH_KEY_DIR:-}" ]]; then
  echo "[ERROR] CLUSTER_SSH_KEY_DIR environment variable is required"
  exit 1
fi

if [[ ! -d "$CLUSTER_SSH_KEY_DIR" ]]; then
  echo "[ERROR] Key directory not found: $CLUSTER_SSH_KEY_DIR"
  exit 1
fi

# Default values
SSH_USERS="${SSH_USERS:-vagrant}"
TRUSTED_HOST_PATTERN="${TRUSTED_HOST_PATTERN:-}"

# Auto-detect env and cluster name from hostname convention: {id}.{cluster}.{env}
full_hostname=$(hostname -f 2>/dev/null || hostname)
dot_count=$(echo "$full_hostname" | tr -cd '.' | wc -c)

if [[ $dot_count -ge 2 ]]; then
  CLUSTER_NAME=$(echo "$full_hostname" | awk -F. '{print $(NF-1)}')
  ENV_NAME=$(echo "$full_hostname" | awk -F. '{print $NF}')
  if [[ -z "$TRUSTED_HOST_PATTERN" ]]; then
    TRUSTED_HOST_PATTERN="*.${CLUSTER_NAME}.${ENV_NAME}"
  fi
  echo "[INFO] Detected env: $ENV_NAME"
  echo "[INFO] Detected cluster: $CLUSTER_NAME"
  echo "[INFO] Host pattern: $TRUSTED_HOST_PATTERN"
else
  echo "[ERROR] Cannot detect env/cluster from hostname '$full_hostname'"
  echo "[ERROR] Hostname must follow convention: {id}.{cluster}.{env}"
  exit 1
fi

# Function to configure SSH for a user with their own key pair
configure_user_ssh() {
  local user="$1"
  local key_dir="$2"
  local env_name="$3"
  local cluster="$4"
  local host_pattern="$5"
  local home_dir

  # Key file paths based on naming convention: id_{env}_{cluster}_{user}
  local key_name="id_${env_name}_${cluster}_${user}"
  local private_key_src="${key_dir}/${key_name}"
  local public_key_src="${key_dir}/${key_name}.pub"

  # Check if key files exist
  if [[ ! -f "$private_key_src" ]]; then
    echo "[WARN] Private key not found for user '$user': $private_key_src, skipping"
    return 0
  fi
  if [[ ! -f "$public_key_src" ]]; then
    echo "[WARN] Public key not found for user '$user': $public_key_src, skipping"
    return 0
  fi

  # Get user's home directory
  if [[ "$user" == "root" ]]; then
    home_dir="/root"
  else
    home_dir=$(getent passwd "$user" 2>/dev/null | cut -d: -f6)
    if [[ -z "$home_dir" ]]; then
      echo "[WARN] User '$user' not found, skipping"
      return 0
    fi
  fi

  local ssh_dir="${home_dir}/.ssh"
  local private_key_dest="${ssh_dir}/${key_name}"
  local public_key_dest="${ssh_dir}/${key_name}.pub"
  local auth_keys="${ssh_dir}/authorized_keys"
  local ssh_config="${ssh_dir}/config"

  echo "[INFO] Configuring SSH for user: $user"

  # Create .ssh directory if needed
  if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown "${user}:$(id -gn "$user")" "$ssh_dir"
    echo "[INFO]   Created ${ssh_dir}"
  fi

  # Copy private key
  cp "$private_key_src" "$private_key_dest"
  chmod 600 "$private_key_dest"
  chown "${user}:$(id -gn "$user")" "$private_key_dest"
  echo "[INFO]   Installed private key: $private_key_dest"

  # Copy public key
  cp "$public_key_src" "$public_key_dest"
  chmod 644 "$public_key_dest"
  chown "${user}:$(id -gn "$user")" "$public_key_dest"
  echo "[INFO]   Installed public key: $public_key_dest"

  # Add public key to authorized_keys (only this user's public key)
  local public_key_content
  public_key_content=$(cat "$public_key_src")

  if [[ ! -f "$auth_keys" ]]; then
    touch "$auth_keys"
    chmod 600 "$auth_keys"
    chown "${user}:$(id -gn "$user")" "$auth_keys"
  fi

  if grep -qF "$public_key_content" "$auth_keys" 2>/dev/null; then
    echo "[OK]    Public key already in authorized_keys"
  else
    echo "$public_key_content" >> "$auth_keys"
    echo "[INFO]   Added public key to authorized_keys"
  fi

  # Configure SSH config for cluster hosts
  local config_marker="# radp:ssh/cluster-trust - ${host_pattern}"

  if [[ ! -f "$ssh_config" ]]; then
    touch "$ssh_config"
    chmod 600 "$ssh_config"
    chown "${user}:$(id -gn "$user")" "$ssh_config"
  fi

  # Check if config already exists for this pattern
  if grep -qF "$config_marker" "$ssh_config" 2>/dev/null; then
    echo "[OK]    SSH config already configured for pattern: $host_pattern"
  else
    cat >> "$ssh_config" << EOF

${config_marker}
Host ${host_pattern}
    IdentityFile ${private_key_dest}
    StrictHostKeyChecking no
    UserKnownHostsFile /dev/null
    LogLevel ERROR
EOF
    echo "[INFO]   Added SSH config for pattern: $host_pattern"
  fi
}

# Process each user
IFS=',' read -ra users <<< "$SSH_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    configure_user_ssh "$user" "$CLUSTER_SSH_KEY_DIR" "$ENV_NAME" "$CLUSTER_NAME" "$TRUSTED_HOST_PATTERN"
  fi
done

echo ""
echo "[INFO] Cluster SSH trust configuration completed"
echo "[INFO] Same-user SSH trust enabled for: $SSH_USERS"
echo "[INFO] Host pattern: $TRUSTED_HOST_PATTERN"
