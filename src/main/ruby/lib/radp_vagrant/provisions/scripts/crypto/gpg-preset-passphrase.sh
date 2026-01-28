#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:crypto/gpg-preset-passphrase
# Preset GPG passphrase in gpg-agent cache for non-interactive operations
#
# ============================================================================
# WHY PRESET PASSPHRASE?
# ============================================================================
#
# By default, GPG prompts for your passphrase every time you use your secret
# key (signing, decrypting). This is problematic for automation scenarios:
#   - yadm decrypt
#   - git commit signing
#   - Automated encryption/decryption scripts
#
# gpg-preset-passphrase caches the passphrase in gpg-agent, allowing
# non-interactive GPG operations until the cache expires or agent restarts.
#
# Prerequisites:
#   1. Secret key must already be imported (use radp:crypto/gpg-import)
#   2. gpg-agent.conf must have "allow-preset-passphrase" (auto-configured)
#
# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
#
# Required:
#   GPG_KEY_UID          - Key UID (email) to identify the key
#
# Passphrase (one required):
#   GPG_PASSPHRASE       - Passphrase content
#   GPG_PASSPHRASE_FILE  - Path to file containing passphrase
#
# Options:
#   GPG_AGENT_ALLOW_PRESET - Auto-configure gpg-agent.conf (default: true)
#
# General:
#   GPG_USERS            - Target users (auto-detected when unprivileged)
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Example 1: Preset passphrase after importing key
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_SECRET_KEY_FILE: "/vagrant/.secrets/secret-key.asc"
#         GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"
#
#     - name: radp:crypto/gpg-preset-passphrase
#       enabled: true
#       env:
#         GPG_KEY_UID: "user@example.com"
#         GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"
#
# Example 2: With yadm clone
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_SECRET_KEY_FILE: "/vagrant/.secrets/gpg-key.asc"
#         GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"
#
#     - name: radp:crypto/gpg-preset-passphrase
#       enabled: true
#       env:
#         GPG_KEY_UID: "user@example.com"
#         GPG_PASSPHRASE_FILE: "/vagrant/.secrets/passphrase.txt"
#
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "git@github.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#         YADM_DECRYPT: "true"
#
# ============================================================================

echo "[INFO] Configuring GPG preset passphrase..."

# Validate required variables
if [[ -z "${GPG_KEY_UID:-}" ]]; then
  echo "[ERROR] GPG_KEY_UID is required (e.g., user@example.com)"
  exit 1
fi

# Validate passphrase source
if [[ -z "${GPG_PASSPHRASE:-}" && -z "${GPG_PASSPHRASE_FILE:-}" ]]; then
  echo "[ERROR] Either GPG_PASSPHRASE or GPG_PASSPHRASE_FILE must be provided"
  exit 1
fi

# Validate file existence
if [[ -n "${GPG_PASSPHRASE_FILE:-}" && ! -f "$GPG_PASSPHRASE_FILE" ]]; then
  echo "[ERROR] Passphrase file not found: $GPG_PASSPHRASE_FILE"
  exit 1
fi

# Default values
GPG_AGENT_ALLOW_PRESET="${GPG_AGENT_ALLOW_PRESET:-true}"

# Determine target users based on execution context
CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" == "root" ]]; then
  if [[ -z "${GPG_USERS:-}" ]]; then
    echo "[ERROR] GPG_USERS must be specified when running as root (privileged: true)"
    exit 1
  fi
else
  if [[ -z "${GPG_USERS:-}" ]]; then
    GPG_USERS="$CURRENT_USER"
    echo "[INFO] GPG_USERS not specified, using current user: $CURRENT_USER"
  elif [[ "$GPG_USERS" != "$CURRENT_USER" && "$GPG_USERS" == *","* ]]; then
    echo "[WARN] Running as '$CURRENT_USER' but GPG_USERS contains multiple users"
    echo "[WARN] Cannot configure other users without privileged: true, using '$CURRENT_USER'"
    GPG_USERS="$CURRENT_USER"
  elif [[ "$GPG_USERS" != "$CURRENT_USER" ]]; then
    echo "[WARN] Running as '$CURRENT_USER' but GPG_USERS='$GPG_USERS'"
    echo "[WARN] Cannot configure other users without privileged: true, using '$CURRENT_USER'"
    GPG_USERS="$CURRENT_USER"
  fi
fi

# Resolve passphrase
get_passphrase() {
  if [[ -n "${GPG_PASSPHRASE:-}" ]]; then
    echo "$GPG_PASSPHRASE"
  elif [[ -n "${GPG_PASSPHRASE_FILE:-}" ]]; then
    cat "$GPG_PASSPHRASE_FILE"
  fi
}

# Preset passphrase for a user
preset_for_user() {
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

  # Check if gnupg directory exists
  if [[ ! -d "$gnupg_dir" ]]; then
    echo "[ERROR] GPG directory not found for user '$user': $gnupg_dir"
    echo "[ERROR] Please import GPG keys first using radp:crypto/gpg-import"
    return 1
  fi

  # Find gpg-preset-passphrase command
  local gpg_preset_cmd
  local libexecdir
  libexecdir=$(gpgconf --list-dirs 2>/dev/null | awk -F: '/^libexecdir:/ {print $2}')

  if [[ -n "$libexecdir" && -x "${libexecdir}/gpg-preset-passphrase" ]]; then
    gpg_preset_cmd="${libexecdir}/gpg-preset-passphrase"
  elif command -v gpg-preset-passphrase &>/dev/null; then
    gpg_preset_cmd="gpg-preset-passphrase"
  else
    echo "[ERROR] gpg-preset-passphrase command not found"
    echo "[ERROR] Install gnupg2 or gnupg-agent package"
    return 1
  fi

  echo "[INFO] Using gpg-preset-passphrase: $gpg_preset_cmd"

  # Configure gpg-agent.conf if needed
  local agent_conf="${gnupg_dir}/gpg-agent.conf"
  if [[ "$GPG_AGENT_ALLOW_PRESET" == "true" ]]; then
    if [[ ! -f "$agent_conf" ]]; then
      echo "allow-preset-passphrase" > "$agent_conf"
      chmod 600 "$agent_conf"
      chown "${user}:$(id -gn "$user")" "$agent_conf" 2>/dev/null || true
      echo "[INFO] Created $agent_conf with allow-preset-passphrase"
    elif ! grep -q "^allow-preset-passphrase" "$agent_conf"; then
      echo "allow-preset-passphrase" >> "$agent_conf"
      echo "[INFO] Added allow-preset-passphrase to $agent_conf"
    else
      echo "[INFO] allow-preset-passphrase already configured"
    fi
  fi

  # Reload gpg-agent
  echo "[INFO] Reloading gpg-agent..."
  gpgconf --homedir "$gnupg_dir" --reload gpg-agent 2>/dev/null || {
    # Start gpg-agent if not running
    gpg-agent --homedir "$gnupg_dir" --daemon 2>/dev/null || true
  }

  # Get keygrip for the specified UID
  # The keygrip is needed for gpg-preset-passphrase (not the key ID)
  echo "[INFO] Finding keygrip for UID: $GPG_KEY_UID"

  local keygrip
  # Get keygrip from the encryption subkey (ssb) associated with the UID
  keygrip=$(gpg --homedir "$gnupg_dir" --list-secret-keys --with-keygrip --with-colons 2>/dev/null | \
    awk -F: -v target_uid="$GPG_KEY_UID" '
      /^uid/ && $10 ~ target_uid { uid_found=1 }
      uid_found && /^ssb/ { ssb_found=1 }
      ssb_found && /^grp/ { print $10; ssb_found=0; uid_found=0 }
    ' | head -1)

  # If no subkey found, try the primary key
  if [[ -z "$keygrip" ]]; then
    keygrip=$(gpg --homedir "$gnupg_dir" --list-secret-keys --with-keygrip --with-colons 2>/dev/null | \
      awk -F: -v target_uid="$GPG_KEY_UID" '
        /^uid/ && $10 ~ target_uid { uid_found=1 }
        uid_found && /^grp/ { print $10; uid_found=0 }
      ' | head -1)
  fi

  if [[ -z "$keygrip" ]]; then
    echo "[ERROR] Could not find keygrip for UID: $GPG_KEY_UID"
    echo "[ERROR] Make sure the secret key is imported and the UID is correct"
    gpg --homedir "$gnupg_dir" --list-secret-keys --with-keygrip 2>/dev/null || true
    return 1
  fi

  echo "[INFO] Found keygrip: $keygrip"

  # Verify keygrip exists in keyring
  if ! gpg --homedir "$gnupg_dir" --list-secret-keys --with-keygrip 2>/dev/null | grep -q "$keygrip"; then
    echo "[ERROR] Keygrip not found in secret keyring: $keygrip"
    return 1
  fi

  # Preset the passphrase
  local passphrase
  passphrase=$(get_passphrase)

  echo "[INFO] Presetting passphrase for keygrip: $keygrip"
  if echo "$passphrase" | "$gpg_preset_cmd" --homedir "$gnupg_dir" --preset "$keygrip"; then
    echo "[OK] Passphrase preset successfully for user '$user'"
  else
    echo "[ERROR] Failed to preset passphrase"
    return 1
  fi
}

# Process each user
IFS=',' read -ra users <<< "$GPG_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    preset_for_user "$user"
  fi
done

echo "[INFO] GPG preset passphrase configuration completed"
