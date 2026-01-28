#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:crypto/gpg-import
# Import GPG public keys into user keyrings
#
# Environment variables (at least one of the following is required):
#   GPG_PUBLIC_KEY      - GPG public key content (ASCII-armored block)
#   GPG_PUBLIC_KEY_FILE - Path to GPG public key file (.asc or .gpg)
#   GPG_KEY_ID          - GPG key ID to fetch from keyserver
#
# Optional environment variables:
#   GPG_KEYSERVER  - Keyserver to fetch keys from (default: keys.openpgp.org)
#   GPG_TRUST_LEVEL - Trust level to set: 2=marginal, 3=full, 4=full, 5=ultimate (empty=skip)
#   GPG_USERS      - Comma-separated list of users to configure (default: vagrant)
#
# Usage in vagrant.yaml:
#   provisions:
#     # Option 1: Specify key content directly
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_PUBLIC_KEY: "-----BEGIN PGP PUBLIC KEY BLOCK-----\n..."
#         GPG_TRUST_LEVEL: "5"
#         GPG_USERS: "vagrant"
#
#     # Option 2: Specify key file path
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_PUBLIC_KEY_FILE: "/vagrant/keys/mykey.asc"
#         GPG_TRUST_LEVEL: "5"
#         GPG_USERS: "vagrant"
#
#     # Option 3: Fetch from keyserver
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_KEY_ID: "0xABCD1234EFGH5678"
#         GPG_KEYSERVER: "keys.openpgp.org"
#         GPG_USERS: "vagrant,root"

echo "[INFO] Configuring GPG key import..."

# Validate that at least one input method is provided
if [[ -z "${GPG_PUBLIC_KEY:-}" && -z "${GPG_PUBLIC_KEY_FILE:-}" && -z "${GPG_KEY_ID:-}" ]]; then
  echo "[ERROR] At least one of GPG_PUBLIC_KEY, GPG_PUBLIC_KEY_FILE, or GPG_KEY_ID must be provided"
  exit 1
fi

# Validate key file exists if specified
if [[ -n "${GPG_PUBLIC_KEY_FILE:-}" && ! -f "$GPG_PUBLIC_KEY_FILE" ]]; then
  echo "[ERROR] GPG public key file not found: $GPG_PUBLIC_KEY_FILE"
  exit 1
fi

# Default values
GPG_KEYSERVER="${GPG_KEYSERVER:-keys.openpgp.org}"
GPG_USERS="${GPG_USERS:-vagrant}"

# Install gnupg if not present
install_gnupg() {
  if command -v gpg &>/dev/null; then
    return 0
  fi

  echo "[INFO] Installing gnupg..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq gnupg
  elif command -v yum &>/dev/null; then
    sudo yum install -y -q gnupg2
  elif command -v apk &>/dev/null; then
    sudo apk add --quiet gnupg
  else
    echo "[ERROR] Unsupported package manager — cannot install gnupg"
    exit 1
  fi
}

install_gnupg

# Function to import GPG key for a user
import_key_for_user() {
  local user="$1"
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

  local gnupg_dir="${home_dir}/.gnupg"
  export GNUPGHOME="$gnupg_dir"

  # Create .gnupg directory if needed
  if [[ ! -d "$gnupg_dir" ]]; then
    mkdir -p "$gnupg_dir"
    chmod 700 "$gnupg_dir"
    echo "[INFO] Created ${gnupg_dir}"
  fi

  local imported_key_id=""

  # Import from key content
  if [[ -n "${GPG_PUBLIC_KEY:-}" ]]; then
    echo "[INFO] Importing GPG key from content for user '$user'..."
    local import_output
    import_output=$(echo "$GPG_PUBLIC_KEY" | gpg --homedir "$gnupg_dir" --batch --import 2>&1) || true
    echo "$import_output"
    imported_key_id=$(echo "$import_output" | grep -oP 'key \K[A-F0-9]+' | head -1) || true
    echo "[INFO] Imported GPG key from GPG_PUBLIC_KEY for user '$user'"
  fi

  # Import from key file
  if [[ -n "${GPG_PUBLIC_KEY_FILE:-}" ]]; then
    echo "[INFO] Importing GPG key from file for user '$user': $GPG_PUBLIC_KEY_FILE"
    local import_output
    import_output=$(gpg --homedir "$gnupg_dir" --batch --import "$GPG_PUBLIC_KEY_FILE" 2>&1) || true
    echo "$import_output"
    imported_key_id=$(echo "$import_output" | grep -oP 'key \K[A-F0-9]+' | head -1) || true
    echo "[INFO] Imported GPG key from file for user '$user'"
  fi

  # Fetch from keyserver
  if [[ -n "${GPG_KEY_ID:-}" ]]; then
    echo "[INFO] Fetching GPG key '$GPG_KEY_ID' from keyserver '$GPG_KEYSERVER' for user '$user'..."
    gpg --homedir "$gnupg_dir" --batch --keyserver "$GPG_KEYSERVER" --recv-keys "$GPG_KEY_ID"
    imported_key_id="$GPG_KEY_ID"
    echo "[INFO] Fetched GPG key from keyserver for user '$user'"
  fi

  # Set trust level if specified
  if [[ -n "${GPG_TRUST_LEVEL:-}" && -n "$imported_key_id" ]]; then
    echo "[INFO] Setting trust level to '$GPG_TRUST_LEVEL' for key '$imported_key_id' (user '$user')..."
    # Get the full fingerprint for the key
    local fingerprint
    fingerprint=$(gpg --homedir "$gnupg_dir" --batch --with-colons --fingerprint "$imported_key_id" \
      | awk -F: '/^fpr:/ { print $10; exit }')
    if [[ -n "$fingerprint" ]]; then
      echo "${fingerprint}:${GPG_TRUST_LEVEL}:" | gpg --homedir "$gnupg_dir" --batch --import-ownertrust
      echo "[INFO] Trust level set for key '$imported_key_id' (user '$user')"
    else
      echo "[WARN] Could not determine fingerprint for key '$imported_key_id', skipping trust"
    fi
  fi

  # Fix ownership
  chown -R "${user}:$(id -gn "$user")" "$gnupg_dir"
  echo "[OK] GPG key import completed for user '$user'"
}

# Process each user
IFS=',' read -ra users <<< "$GPG_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    import_key_for_user "$user"
  fi
done

echo "[INFO] GPG key import configuration completed"
