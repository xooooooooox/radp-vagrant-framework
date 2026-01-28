#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:crypto/gpg-import
# Import GPG keys (public and/or secret) into user keyrings
#
# ============================================================================
# GPG BASICS FOR DEVELOPERS
# ============================================================================
#
# GPG (GNU Privacy Guard) uses asymmetric cryptography with key pairs:
#
#   - PUBLIC KEY: Can be shared freely. Used to encrypt data TO you, or verify
#     signatures you made. File extensions: .asc (ASCII-armored) or .gpg (binary)
#
#   - SECRET KEY (Private Key): Must be kept secure. Used to decrypt data
#     encrypted to you, or sign data. Often protected by a passphrase.
#
#   - KEY ID: A short identifier for a key (e.g., 0xABCD1234 or the last 8/16
#     hex digits of the fingerprint)
#
#   - FINGERPRINT: Full 40-character hex identifier of a key
#
#   - TRUST LEVEL: How much you trust a key's owner to verify other keys:
#       2 = unknown    (you don't know the owner)
#       3 = marginal   (you somewhat trust the owner)
#       4 = full       (you fully trust the owner)
#       5 = ultimate   (this is YOUR OWN key)
#
#   - KEYRING: Database of keys stored in ~/.gnupg/
#
# Common use cases:
#   - Git commit signing: needs your secret key
#   - yadm encrypted files: needs your secret key to decrypt
#   - Verifying software signatures: needs the signer's public key
#   - Encrypting files for others: needs their public key
#
# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
#
# Public key import (choose one or more):
#   GPG_PUBLIC_KEY       - GPG public key content (ASCII-armored block)
#   GPG_PUBLIC_KEY_FILE  - Path to GPG public key file (.asc or .gpg)
#   GPG_KEY_ID           - GPG key ID to fetch from keyserver
#   GPG_KEYSERVER        - Keyserver URL (default: keys.openpgp.org)
#
# Secret key import:
#   GPG_SECRET_KEY_FILE  - Path to GPG secret key file (.asc or .gpg)
#   GPG_PASSPHRASE       - Passphrase for secret key (if protected)
#   GPG_PASSPHRASE_FILE  - Path to file containing passphrase
#
# Trust configuration (choose one):
#   GPG_TRUST_LEVEL      - Trust level (2-5) to set for imported key
#   GPG_OWNERTRUST_FILE  - Path to ownertrust file for batch import
#
# General:
#   GPG_USERS            - Comma-separated list of users (default: vagrant)
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Example 1: Import public key from file
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_PUBLIC_KEY_FILE: "/vagrant/keys/colleague.asc"
#         GPG_TRUST_LEVEL: "4"
#
# Example 2: Fetch public key from keyserver
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_KEY_ID: "0x1234567890ABCDEF"
#         GPG_KEYSERVER: "keys.openpgp.org"
#
# Example 3: Full key pair for yadm/git signing (your own key)
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_SECRET_KEY_FILE: "/vagrant/.secrets/my-secret-key.asc"
#         GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"
#         GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"
#         GPG_USERS: "vagrant"
#
# Example 4: Multiple users
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_SECRET_KEY_FILE: "/vagrant/.secrets/shared-key.asc"
#         GPG_TRUST_LEVEL: "5"
#         GPG_USERS: "vagrant,developer"
#
# ============================================================================
# HOW TO EXPORT YOUR KEYS (run on your host machine)
# ============================================================================
#
# 1. Find your key ID:
#      gpg --list-secret-keys --keyid-format LONG
#
# 2. Export secret key (includes public key):
#      gpg --export-secret-keys --armor YOUR_KEY_ID > secret-key.asc
#
# 3. Export ownertrust:
#      gpg --export-ownertrust > ownertrust.txt
#
# 4. Store passphrase in a file (if your key is passphrase-protected):
#      echo "your-passphrase" > passphrase.txt
#
# SECURITY NOTE: Store these files securely! Consider:
#   - Using Vagrant's synced folder with restricted permissions
#   - Encrypting the files at rest
#   - Using environment variables for the passphrase
#
# ============================================================================

echo "[INFO] Configuring GPG key import..."

# Validate that at least one input method is provided
if [[ -z "${GPG_PUBLIC_KEY:-}" && -z "${GPG_PUBLIC_KEY_FILE:-}" && \
      -z "${GPG_KEY_ID:-}" && -z "${GPG_SECRET_KEY_FILE:-}" ]]; then
  echo "[ERROR] At least one key source must be provided:"
  echo "        GPG_PUBLIC_KEY, GPG_PUBLIC_KEY_FILE, GPG_KEY_ID, or GPG_SECRET_KEY_FILE"
  exit 1
fi

# Validate file existence
for var_name in GPG_PUBLIC_KEY_FILE GPG_SECRET_KEY_FILE GPG_PASSPHRASE_FILE GPG_OWNERTRUST_FILE; do
  eval "file_path=\${${var_name}:-}"
  if [[ -n "$file_path" && ! -f "$file_path" ]]; then
    echo "[ERROR] File not found for ${var_name}: $file_path"
    exit 1
  fi
done

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
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q gnupg2
  elif command -v apk &>/dev/null; then
    sudo apk add --quiet gnupg
  else
    echo "[ERROR] Unsupported package manager — cannot install gnupg"
    exit 1
  fi
}

install_gnupg

# Resolve passphrase from content or file
get_passphrase() {
  if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
    echo "$GPG_PASSPHRASE"
  elif [[ -n "${GPG_PASSPHRASE_FILE:-}" ]]; then
    cat "$GPG_PASSPHRASE_FILE"
  fi
}

# Function to import GPG keys for a user
import_keys_for_user() {
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
  local import_output

  # --- Import public key from content ---
  if [[ -n "${GPG_PUBLIC_KEY:-}" ]]; then
    echo "[INFO] Importing public key from content for user '$user'..."
    import_output=$(echo "$GPG_PUBLIC_KEY" | gpg --homedir "$gnupg_dir" --batch --import 2>&1) || true
    echo "$import_output"
    imported_key_id=$(echo "$import_output" | grep -oP 'key \K[A-F0-9]+' | head -1) || true
    echo "[INFO] Imported public key from GPG_PUBLIC_KEY"
  fi

  # --- Import public key from file ---
  if [[ -n "${GPG_PUBLIC_KEY_FILE:-}" ]]; then
    echo "[INFO] Importing public key from file for user '$user': $GPG_PUBLIC_KEY_FILE"
    import_output=$(gpg --homedir "$gnupg_dir" --batch --import "$GPG_PUBLIC_KEY_FILE" 2>&1) || true
    echo "$import_output"
    imported_key_id=$(echo "$import_output" | grep -oP 'key \K[A-F0-9]+' | head -1) || true
    echo "[INFO] Imported public key from file"
  fi

  # --- Fetch public key from keyserver ---
  if [[ -n "${GPG_KEY_ID:-}" ]]; then
    echo "[INFO] Fetching key '$GPG_KEY_ID' from keyserver '$GPG_KEYSERVER' for user '$user'..."
    gpg --homedir "$gnupg_dir" --batch --keyserver "$GPG_KEYSERVER" --recv-keys "$GPG_KEY_ID"
    imported_key_id="$GPG_KEY_ID"
    echo "[INFO] Fetched key from keyserver"
  fi

  # --- Import secret key from file ---
  if [[ -n "${GPG_SECRET_KEY_FILE:-}" ]]; then
    echo "[INFO] Importing secret key from file for user '$user': $GPG_SECRET_KEY_FILE"
    local passphrase
    passphrase=$(get_passphrase)

    if [[ -n "$passphrase" ]]; then
      # Import with passphrase
      import_output=$(gpg --homedir "$gnupg_dir" --batch --yes \
        --pinentry-mode loopback \
        --passphrase "$passphrase" \
        --import "$GPG_SECRET_KEY_FILE" 2>&1) || true
    else
      # Import without passphrase (key may not be protected)
      import_output=$(gpg --homedir "$gnupg_dir" --batch --yes \
        --import "$GPG_SECRET_KEY_FILE" 2>&1) || true
    fi
    echo "$import_output"
    imported_key_id=$(echo "$import_output" | grep -oP 'key \K[A-F0-9]+' | head -1) || true
    echo "[INFO] Imported secret key from file"
  fi

  # --- Configure trust ---

  # Option 1: Import from ownertrust file
  if [[ -n "${GPG_OWNERTRUST_FILE:-}" ]]; then
    echo "[INFO] Importing ownertrust from file for user '$user': $GPG_OWNERTRUST_FILE"
    gpg --homedir "$gnupg_dir" --batch --import-ownertrust "$GPG_OWNERTRUST_FILE"
    echo "[INFO] Imported ownertrust from file"
  fi

  # Option 2: Set trust level for imported key
  if [[ -n "${GPG_TRUST_LEVEL:-}" && -n "$imported_key_id" && -z "${GPG_OWNERTRUST_FILE:-}" ]]; then
    echo "[INFO] Setting trust level to '$GPG_TRUST_LEVEL' for key '$imported_key_id' (user '$user')..."
    local fingerprint
    fingerprint=$(gpg --homedir "$gnupg_dir" --batch --with-colons --fingerprint "$imported_key_id" \
      | awk -F: '/^fpr:/ { print $10; exit }')
    if [[ -n "$fingerprint" ]]; then
      echo "${fingerprint}:${GPG_TRUST_LEVEL}:" | gpg --homedir "$gnupg_dir" --batch --import-ownertrust
      echo "[INFO] Trust level set for key '$imported_key_id'"
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
    import_keys_for_user "$user"
  fi
done

echo "[INFO] GPG key import configuration completed"
