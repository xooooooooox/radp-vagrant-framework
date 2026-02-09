#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:ssh/target-trust
# Establish SSH trust between guest and a specified external target
#
# Configures the guest side of SSH trust:
#   - Outbound (guest -> target): deploy private key + SSH config + known_hosts
#                                 + add pubkey to authorized_keys (peer trust)
#   - Inbound  (target -> guest): add target's public key to authorized_keys
#
# Each direction is independently optional.
#
# Required environment variables:
#   TARGET_HOST - Target hostname or IP address
#
# Optional environment variables (outbound):
#   TARGET_SSH_PRIVATE_KEY_FILE - Path to private key file for authenticating to the target
#   TARGET_KEY_NAME             - Custom key name in ~/.ssh/ (default: id_target_{sanitized_host})
#   TARGET_SSH_USER             - Username on the target (default: current guest user being configured)
#   TARGET_SSH_PORT             - SSH port on the target
#   TARGET_HOST_ALIAS           - Host alias for SSH config entry (default: TARGET_HOST)
#   TARGET_SSH_CONFIG           - Write SSH config entry for the target (default: true)
#
# Optional environment variables (known hosts - choose one):
#   TARGET_HOST_KEY      - Target host key content for known_hosts
#   TARGET_HOST_KEY_FILE - Path to file containing target host key(s) for known_hosts
#   TARGET_KEYSCAN       - Attempt ssh-keyscan to fetch target host keys (default: false)
#
# Optional environment variables (inbound):
#   TARGET_PUBLIC_KEY      - Target's SSH public key content (for authorized_keys)
#   TARGET_PUBLIC_KEY_FILE - Path to file containing target's SSH public key (for authorized_keys)
#
# Optional environment variables (SSH key exchange via SSH):
#   COPY_IDENTITY_TO_TARGET   - Push guest's pubkey to target's authorized_keys via SSH (default: false)
#   COPY_IDENTITY_FROM_TARGET - Fetch target's pubkeys to guest's authorized_keys via SSH (default: false)
#   TARGET_SSH_BOOTSTRAP_KEY   - Path to a different private key for SSH to target (default: TARGET_SSH_PRIVATE_KEY_FILE)
#   TARGET_SSH_PASSWORD        - Password for SSH to target (used with sshpass, for first-time setup)
#   TARGET_SSH_PASSWORD_FILE   - Path to file containing SSH password
#
# Optional environment variables (general):
#   SSH_USERS - Comma-separated list of users to configure (default: vagrant)
#
# Usage in vagrant.yaml:
#   provisions:
#     # Outbound only: guest can SSH to GitLab
#     - name: radp:ssh/target-trust
#       enabled: true
#       env:
#         TARGET_HOST: "gitlab.example.com"
#         TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_gitlab"
#         TARGET_KEYSCAN: "true"
#
#     # Bidirectional: guest <-> deploy server
#     - name: radp:ssh/target-trust
#       enabled: true
#       env:
#         TARGET_HOST: "deploy.example.com"
#         TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_deploy"
#         TARGET_HOST_KEY_FILE: "/vagrant/.secrets/deploy_host_key"
#         TARGET_PUBLIC_KEY_FILE: "/vagrant/.secrets/deploy_user_key.pub"
#         TARGET_SSH_USER: "deployer"
#
#     # Bidirectional via SSH key exchange (bootstrap key already trusted)
#     - name: radp:ssh/target-trust
#       enabled: true
#       env:
#         TARGET_HOST: "deploy.example.com"
#         TARGET_SSH_PRIVATE_KEY_FILE: "/vagrant/.secrets/id_rsa_deploy"
#         TARGET_SSH_USER: "deployer"
#         TARGET_KEYSCAN: "true"
#         COPY_IDENTITY_TO_TARGET: "true"
#         COPY_IDENTITY_FROM_TARGET: "true"
#
#     # Inbound only: allow CI server to SSH into guest
#     - name: radp:ssh/target-trust
#       enabled: true
#       env:
#         TARGET_HOST: "ci.example.com"
#         TARGET_PUBLIC_KEY_FILE: "/vagrant/.secrets/ci_user_key.pub"

echo "[INFO] Configuring SSH target trust..."

# --- Validate required ---

if [[ -z "${TARGET_HOST:-}" ]]; then
  echo "[ERROR] TARGET_HOST environment variable is required"
  exit 1
fi

# --- Validate file existence ---

if [[ -n "${TARGET_SSH_PRIVATE_KEY_FILE:-}" && ! -f "$TARGET_SSH_PRIVATE_KEY_FILE" ]]; then
  echo "[ERROR] Private key file not found: $TARGET_SSH_PRIVATE_KEY_FILE"
  exit 1
fi

if [[ -n "${TARGET_HOST_KEY_FILE:-}" && ! -f "$TARGET_HOST_KEY_FILE" ]]; then
  echo "[ERROR] Host key file not found: $TARGET_HOST_KEY_FILE"
  exit 1
fi

if [[ -n "${TARGET_PUBLIC_KEY_FILE:-}" && ! -f "$TARGET_PUBLIC_KEY_FILE" ]]; then
  echo "[ERROR] Public key file not found: $TARGET_PUBLIC_KEY_FILE"
  exit 1
fi

if [[ -n "${TARGET_SSH_PASSWORD_FILE:-}" && ! -f "$TARGET_SSH_PASSWORD_FILE" ]]; then
  echo "[ERROR] SSH password file not found: $TARGET_SSH_PASSWORD_FILE"
  exit 1
fi

if [[ -n "${TARGET_SSH_BOOTSTRAP_KEY:-}" && ! -f "$TARGET_SSH_BOOTSTRAP_KEY" ]]; then
  echo "[ERROR] Bootstrap key file not found: $TARGET_SSH_BOOTSTRAP_KEY"
  exit 1
fi

# --- Helpers ---

sanitize_hostname() {
  echo "$1" | sed 's/[.\-]/_/g'
}

# --- Derive defaults ---

HOST_ALIAS="${TARGET_HOST_ALIAS:-$TARGET_HOST}"
KEY_NAME="${TARGET_KEY_NAME:-id_target_$(sanitize_hostname "$TARGET_HOST")}"

# --- Detect trust direction ---

HAS_OUTBOUND="false"
HAS_INBOUND="false"

if [[ -n "${TARGET_SSH_PRIVATE_KEY_FILE:-}" ]]; then
  HAS_OUTBOUND="true"
fi

if [[ -n "${TARGET_PUBLIC_KEY:-}" || -n "${TARGET_PUBLIC_KEY_FILE:-}" ]]; then
  HAS_INBOUND="true"
fi

# --- Detect SSH key exchange directions ---

DO_COPY_TO_TARGET="false"
DO_COPY_FROM_TARGET="false"
COPY_IDENTITY_TO_TARGET="${COPY_IDENTITY_TO_TARGET:-false}"
COPY_IDENTITY_FROM_TARGET="${COPY_IDENTITY_FROM_TARGET:-false}"

if [[ "$COPY_IDENTITY_TO_TARGET" == "true" ]]; then
  if [[ -z "${TARGET_SSH_PRIVATE_KEY_FILE:-}" ]]; then
    echo "[ERROR] COPY_IDENTITY_TO_TARGET requires TARGET_SSH_PRIVATE_KEY_FILE"
    exit 1
  fi
  DO_COPY_TO_TARGET="true"
fi

if [[ "$COPY_IDENTITY_FROM_TARGET" == "true" ]]; then
  if [[ -z "${TARGET_SSH_PRIVATE_KEY_FILE:-}" ]]; then
    echo "[ERROR] COPY_IDENTITY_FROM_TARGET requires TARGET_SSH_PRIVATE_KEY_FILE"
    exit 1
  fi
  DO_COPY_FROM_TARGET="true"
fi

if [[ "$HAS_OUTBOUND" == "false" && "$HAS_INBOUND" == "false" && "$DO_COPY_TO_TARGET" == "false" && "$DO_COPY_FROM_TARGET" == "false" ]]; then
  echo "[WARN] No trust directions configured"
  echo "[WARN] Nothing to do"
  exit 0
fi

echo "[INFO] Target: $TARGET_HOST (alias: $HOST_ALIAS)"
echo "[INFO] Outbound (guest -> target): $HAS_OUTBOUND"
echo "[INFO] Inbound (target -> guest): $HAS_INBOUND"
echo "[INFO] Copy identity to target: $DO_COPY_TO_TARGET"
echo "[INFO] Copy identity from target: $DO_COPY_FROM_TARGET"

# --- Resolve inbound public key content ---

INBOUND_KEY=""
if [[ "$HAS_INBOUND" == "true" ]]; then
  if [[ -n "${TARGET_PUBLIC_KEY:-}" ]]; then
    INBOUND_KEY="$TARGET_PUBLIC_KEY"
    echo "[INFO] Using inbound public key from TARGET_PUBLIC_KEY"
  elif [[ -n "${TARGET_PUBLIC_KEY_FILE:-}" ]]; then
    INBOUND_KEY=$(cat "$TARGET_PUBLIC_KEY_FILE")
    echo "[INFO] Using inbound public key from file: $TARGET_PUBLIC_KEY_FILE"
  fi
fi

# --- Resolve SSH password (for key exchange via SSH) ---

TARGET_SSH_AUTH_PASSWORD=""
if [[ "$DO_COPY_TO_TARGET" == "true" || "$DO_COPY_FROM_TARGET" == "true" ]]; then
  if [[ -n "${TARGET_SSH_PASSWORD:-}" ]]; then
    TARGET_SSH_AUTH_PASSWORD="$TARGET_SSH_PASSWORD"
    echo "[INFO] Using SSH password from TARGET_SSH_PASSWORD"
  elif [[ -n "${TARGET_SSH_PASSWORD_FILE:-}" ]]; then
    TARGET_SSH_AUTH_PASSWORD=$(cat "$TARGET_SSH_PASSWORD_FILE")
    echo "[INFO] Using SSH password from file: $TARGET_SSH_PASSWORD_FILE"
  fi
fi

# --- Helper: build SSH command for key exchange ---

build_target_ssh_cmd() {
  local key_path="$1"
  local ssh_cmd=""

  if [[ -n "$TARGET_SSH_AUTH_PASSWORD" ]]; then
    if ! command -v sshpass &>/dev/null; then
      echo "[ERROR] sshpass is required for password-based SSH but not installed"
      return 1
    fi
    ssh_cmd="sshpass -p ${TARGET_SSH_AUTH_PASSWORD} ssh -o BatchMode=no"
  else
    ssh_cmd="ssh -o BatchMode=yes"
  fi

  ssh_cmd+=" -o StrictHostKeyChecking=no -o LogLevel=ERROR"
  ssh_cmd+=" -i ${key_path}"

  if [[ -n "$TARGET_SSH_PORT" && "$TARGET_SSH_PORT" != "22" ]]; then
    ssh_cmd+=" -p ${TARGET_SSH_PORT}"
  fi

  echo "$ssh_cmd"
}

# --- Default values ---

SSH_USERS="${SSH_USERS:-vagrant}"
TARGET_SSH_PORT="${TARGET_SSH_PORT:-}"
TARGET_SSH_USER="${TARGET_SSH_USER:-}"
TARGET_SSH_CONFIG="${TARGET_SSH_CONFIG:-true}"
TARGET_KEYSCAN="${TARGET_KEYSCAN:-false}"

# --- Per-user configuration ---

configure_user_ssh() {
  local user="$1"
  local home_dir

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
  local ssh_config="${ssh_dir}/config"
  local known_hosts="${ssh_dir}/known_hosts"
  local auth_keys="${ssh_dir}/authorized_keys"
  local effective_ssh_user="${TARGET_SSH_USER:-$user}"

  echo "[INFO] Configuring SSH for user: $user"

  # Create .ssh directory if needed
  if [[ ! -d "$ssh_dir" ]]; then
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    chown "${user}:$(id -gn "$user")" "$ssh_dir"
    echo "[INFO]   Created ${ssh_dir}"
  fi

  # --- OUTBOUND: guest -> target ---
  if [[ "$HAS_OUTBOUND" == "true" ]]; then
    local private_key_dest="${ssh_dir}/${KEY_NAME}"

    # Deploy private key
    cp "$TARGET_SSH_PRIVATE_KEY_FILE" "$private_key_dest"
    chmod 600 "$private_key_dest"
    chown "${user}:$(id -gn "$user")" "$private_key_dest"
    echo "[INFO]   Installed private key: $private_key_dest"

    # Deploy public key if it exists alongside the private key
    if [[ -f "${TARGET_SSH_PRIVATE_KEY_FILE}.pub" ]]; then
      cp "${TARGET_SSH_PRIVATE_KEY_FILE}.pub" "${private_key_dest}.pub"
      chmod 644 "${private_key_dest}.pub"
      chown "${user}:$(id -gn "$user")" "${private_key_dest}.pub"
      echo "[INFO]   Installed public key: ${private_key_dest}.pub"

      # Deploy public key to guest's authorized_keys (enables inbound from peers with same key)
      if [[ ! -f "$auth_keys" ]]; then
        touch "$auth_keys"
        chmod 600 "$auth_keys"
        chown "${user}:$(id -gn "$user")" "$auth_keys"
      fi
      local pubkey_content
      pubkey_content=$(cat "${private_key_dest}.pub")
      if ! grep -qF "$pubkey_content" "$auth_keys" 2>/dev/null; then
        echo "$pubkey_content" >> "$auth_keys"
        echo "[INFO]   Added public key to authorized_keys (accepts inbound from peers)"
      fi
    fi

    # --- Known hosts handling ---
    local strict_host_key="no"
    local need_user_known_hosts_fallback="true"

    if [[ -n "${TARGET_HOST_KEY:-}" ]]; then
      # Mode 1: host key content provided directly
      if [[ ! -f "$known_hosts" ]]; then
        touch "$known_hosts"
        chmod 644 "$known_hosts"
        chown "${user}:$(id -gn "$user")" "$known_hosts"
      fi
      if ! grep -qF "$TARGET_HOST_KEY" "$known_hosts" 2>/dev/null; then
        echo "$TARGET_HOST_KEY" >> "$known_hosts"
        echo "[INFO]   Added target host key to known_hosts"
      else
        echo "[OK]    Target host key already in known_hosts"
      fi
      strict_host_key="yes"
      need_user_known_hosts_fallback="false"

    elif [[ -n "${TARGET_HOST_KEY_FILE:-}" ]]; then
      # Mode 2: host key file provided
      if [[ ! -f "$known_hosts" ]]; then
        touch "$known_hosts"
        chmod 644 "$known_hosts"
        chown "${user}:$(id -gn "$user")" "$known_hosts"
      fi
      # Append each line that isn't already present
      while IFS= read -r line || [[ -n "$line" ]]; do
        if [[ -n "$line" ]] && ! grep -qF "$line" "$known_hosts" 2>/dev/null; then
          echo "$line" >> "$known_hosts"
        fi
      done < "$TARGET_HOST_KEY_FILE"
      echo "[INFO]   Added target host keys from file to known_hosts"
      strict_host_key="yes"
      need_user_known_hosts_fallback="false"

    elif [[ "$TARGET_KEYSCAN" == "true" ]]; then
      # Mode 3: ssh-keyscan
      local keyscan_port_arg=""
      if [[ -n "$TARGET_SSH_PORT" && "$TARGET_SSH_PORT" != "22" ]]; then
        keyscan_port_arg="-p $TARGET_SSH_PORT"
      fi

      local keyscan_output
      # shellcheck disable=SC2086
      if keyscan_output=$(ssh-keyscan $keyscan_port_arg "$TARGET_HOST" 2>/dev/null) && [[ -n "$keyscan_output" ]]; then
        if [[ ! -f "$known_hosts" ]]; then
          touch "$known_hosts"
          chmod 644 "$known_hosts"
          chown "${user}:$(id -gn "$user")" "$known_hosts"
        fi
        echo "$keyscan_output" >> "$known_hosts"
        echo "[INFO]   Added target host keys via ssh-keyscan"
        strict_host_key="yes"
        need_user_known_hosts_fallback="false"
      else
        echo "[WARN]   ssh-keyscan failed for $TARGET_HOST, falling back to StrictHostKeyChecking=no"
      fi
    fi

    # --- SSH config entry ---
    if [[ "$TARGET_SSH_CONFIG" == "true" ]]; then
      local config_marker="# radp:ssh/target-trust - ${HOST_ALIAS}"

      if [[ ! -f "$ssh_config" ]]; then
        touch "$ssh_config"
        chmod 600 "$ssh_config"
        chown "${user}:$(id -gn "$user")" "$ssh_config"
      fi

      if grep -qF "$config_marker" "$ssh_config" 2>/dev/null; then
        echo "[OK]    SSH config already configured for: $HOST_ALIAS"
      else
        {
          echo ""
          echo "$config_marker"
          echo "Host ${HOST_ALIAS}"
          echo "    HostName ${TARGET_HOST}"
          echo "    IdentityFile ${private_key_dest}"
          if [[ -n "$TARGET_SSH_USER" ]]; then
            echo "    User ${TARGET_SSH_USER}"
          fi
          if [[ -n "$TARGET_SSH_PORT" && "$TARGET_SSH_PORT" != "22" ]]; then
            echo "    Port ${TARGET_SSH_PORT}"
          fi
          echo "    StrictHostKeyChecking ${strict_host_key}"
          if [[ "$need_user_known_hosts_fallback" == "true" ]]; then
            echo "    UserKnownHostsFile /dev/null"
          fi
          echo "    LogLevel ERROR"
        } >> "$ssh_config"
        echo "[INFO]   Added SSH config for: $HOST_ALIAS"
      fi
    fi
  fi

  # --- Resolve SSH key for key exchange ---
  local copy_ssh_key="${TARGET_SSH_BOOTSTRAP_KEY:-$private_key_dest}"

  # --- COPY IDENTITY TO TARGET: push guest pubkey to target ---
  if [[ "$DO_COPY_TO_TARGET" == "true" ]]; then
    local pubkey_file="${TARGET_SSH_PRIVATE_KEY_FILE}.pub"
    if [[ ! -f "$pubkey_file" ]]; then
      echo "[ERROR]   Public key not found: $pubkey_file (required for COPY_IDENTITY_TO_TARGET)"
      echo "[ERROR]   Cannot push identity to target"
    else
      local pubkey_content
      pubkey_content=$(cat "$pubkey_file")
      local target_ssh_cmd
      if ! target_ssh_cmd=$(build_target_ssh_cmd "$copy_ssh_key"); then
        echo "[WARN]   Skipping COPY_IDENTITY_TO_TARGET: failed to build SSH command"
      else
        echo "[INFO]   Pushing guest public key to ${effective_ssh_user}@${TARGET_HOST}..."
        # shellcheck disable=SC2029
        if echo "$pubkey_content" | $target_ssh_cmd "${effective_ssh_user}@${TARGET_HOST}" \
          'mkdir -p ~/.ssh && chmod 700 ~/.ssh && touch ~/.ssh/authorized_keys && chmod 600 ~/.ssh/authorized_keys && key=$(cat) && grep -qF "$key" ~/.ssh/authorized_keys 2>/dev/null || echo "$key" >> ~/.ssh/authorized_keys'; then
          echo "[INFO]   Guest public key added to ${effective_ssh_user}@${TARGET_HOST} authorized_keys"
        else
          echo "[WARN]   Failed to push public key to ${effective_ssh_user}@${TARGET_HOST} (SSH connection failed)"
        fi
      fi
    fi
  fi

  # --- COPY IDENTITY FROM TARGET: fetch target pubkeys to guest ---
  if [[ "$DO_COPY_FROM_TARGET" == "true" ]]; then
    local target_ssh_cmd
    if ! target_ssh_cmd=$(build_target_ssh_cmd "$copy_ssh_key"); then
      echo "[WARN]   Skipping COPY_IDENTITY_FROM_TARGET: failed to build SSH command"
    else
      echo "[INFO]   Fetching public keys from ${effective_ssh_user}@${TARGET_HOST}..."
      local fetched_keys
      # shellcheck disable=SC2029
      if fetched_keys=$($target_ssh_cmd "${effective_ssh_user}@${TARGET_HOST}" \
        'for f in ~/.ssh/*.pub; do [ -f "$f" ] && cat "$f"; done' 2>/dev/null) && [[ -n "$fetched_keys" ]]; then
        if [[ ! -f "$auth_keys" ]]; then
          touch "$auth_keys"
          chmod 600 "$auth_keys"
          chown "${user}:$(id -gn "$user")" "$auth_keys"
          echo "[INFO]   Created ${auth_keys}"
        fi
        local added_count=0
        while IFS= read -r key_line || [[ -n "$key_line" ]]; do
          if [[ -n "$key_line" ]]; then
            if ! grep -qF "$key_line" "$auth_keys" 2>/dev/null; then
              echo "$key_line" >> "$auth_keys"
              added_count=$((added_count + 1))
            fi
          fi
        done <<< "$fetched_keys"
        if [[ "$added_count" -gt 0 ]]; then
          echo "[INFO]   Added $added_count public key(s) from ${effective_ssh_user}@${TARGET_HOST} to authorized_keys"
        else
          echo "[OK]    Target public keys already in authorized_keys"
        fi
      else
        echo "[WARN]   Failed to fetch public keys from ${effective_ssh_user}@${TARGET_HOST} (SSH connection failed or no keys found)"
      fi
    fi
  fi

  # --- INBOUND: target -> guest ---
  if [[ "$HAS_INBOUND" == "true" ]]; then
    if [[ ! -f "$auth_keys" ]]; then
      touch "$auth_keys"
      chmod 600 "$auth_keys"
      chown "${user}:$(id -gn "$user")" "$auth_keys"
      echo "[INFO]   Created ${auth_keys}"
    fi

    if grep -qF "$INBOUND_KEY" "$auth_keys" 2>/dev/null; then
      echo "[OK]    Target public key already in authorized_keys"
    else
      echo "$INBOUND_KEY" >> "$auth_keys"
      echo "[INFO]   Added target public key to authorized_keys"
    fi
  fi
}

# --- Process each user ---

IFS=',' read -ra users <<< "$SSH_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    configure_user_ssh "$user"
  fi
done

echo ""
echo "[INFO] SSH target trust configuration completed"
echo "[INFO] Target: $TARGET_HOST (alias: $HOST_ALIAS)"
if [[ "$HAS_OUTBOUND" == "true" ]]; then
  echo "[INFO] Outbound trust configured (key: $KEY_NAME)"
fi
if [[ "$DO_COPY_TO_TARGET" == "true" ]]; then
  echo "[INFO] Guest identity pushed to target"
fi
if [[ "$DO_COPY_FROM_TARGET" == "true" ]]; then
  echo "[INFO] Target identity fetched to guest"
fi
if [[ "$HAS_INBOUND" == "true" ]]; then
  echo "[INFO] Inbound trust configured"
fi
