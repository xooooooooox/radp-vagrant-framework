#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:yadm/submodules
# Initialize and update yadm submodules
#
# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
#
# SSH options:
#   YADM_SSH_KEY_FILE    - Path to SSH private key
#   YADM_SSH_STRICT_HOST_KEY - Strict host key checking (default false)
#
# General:
#   YADM_USERS           - Target users (auto-detected when unprivileged)
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Example 1: Basic submodule init (after yadm clone)
#   provisions:
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "git@github.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#
#     - name: radp:yadm/submodules
#       enabled: true
#       env:
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#
# Example 2: Submodules after decrypt (when .gitmodules depends on decrypted files)
#   provisions:
#     - name: radp:crypto/gpg-import
#       enabled: true
#       env:
#         GPG_SECRET_KEY_FILE: "/vagrant/.secrets/gpg-key.asc"
#         GPG_OWNERTRUST_FILE: "/vagrant/.secrets/ownertrust.txt"
#
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "git@github.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#         YADM_DECRYPT: "true"
#
#     - name: radp:yadm/submodules
#       enabled: true
#       env:
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#
# ============================================================================

echo "[INFO] Configuring yadm submodules..."

# Ensure /usr/local/bin is in PATH (sudoers secure_path may exclude it)
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"

# Validate file existence
if [[ -n "${YADM_SSH_KEY_FILE:-}" && ! -f "$YADM_SSH_KEY_FILE" ]]; then
  echo "[ERROR] File not found for YADM_SSH_KEY_FILE: $YADM_SSH_KEY_FILE"
  exit 1
fi

# Default values
YADM_SSH_STRICT_HOST_KEY="${YADM_SSH_STRICT_HOST_KEY:-false}"

# Determine target users based on execution context
CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" == "root" ]]; then
  if [[ -z "${YADM_USERS:-}" ]]; then
    echo "[ERROR] YADM_USERS must be specified when running as root (privileged: true)"
    exit 1
  fi
else
  if [[ -z "${YADM_USERS:-}" ]]; then
    YADM_USERS="$CURRENT_USER"
    echo "[INFO] YADM_USERS not specified, using current user: $CURRENT_USER"
  elif [[ "$YADM_USERS" != "$CURRENT_USER" && "$YADM_USERS" == *","* ]]; then
    echo "[WARN] Running as '$CURRENT_USER' but YADM_USERS contains multiple users"
    echo "[WARN] Cannot configure other users without privileged: true, using '$CURRENT_USER'"
    YADM_USERS="$CURRENT_USER"
  elif [[ "$YADM_USERS" != "$CURRENT_USER" ]]; then
    echo "[WARN] Running as '$CURRENT_USER' but YADM_USERS='$YADM_USERS'"
    echo "[WARN] Cannot configure other users without privileged: true, using '$CURRENT_USER'"
    YADM_USERS="$CURRENT_USER"
  fi
fi

# Build GIT_SSH_COMMAND with options (no host overrides — submodules may be on different hosts)
build_ssh_command() {
  local ssh_opts="-o BatchMode=yes"

  if [[ "$YADM_SSH_STRICT_HOST_KEY" == "false" ]]; then
    ssh_opts="$ssh_opts -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  fi

  if [[ -n "${YADM_SSH_KEY_FILE:-}" ]]; then
    ssh_opts="$ssh_opts -i $YADM_SSH_KEY_FILE"
  fi

  echo "ssh $ssh_opts"
}

# Run a command as a specific user, optionally with an environment prefix
run_as_user() {
  local user="$1"
  local env_prefix="$2"
  local cmd="$3"

  local full_cmd
  if [[ -n "$env_prefix" ]]; then
    full_cmd="$env_prefix $cmd"
  else
    full_cmd="$cmd"
  fi

  if [[ "$CURRENT_USER" == "root" ]]; then
    su - "$user" -c "$full_cmd"
  else
    eval "$full_cmd"
  fi
}

# Update submodules for a user
submodules_for_user() {
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

  # Check if yadm repo exists
  local yadm_repo_dir="${home_dir}/.local/share/yadm/repo.git"
  if [[ ! -d "$yadm_repo_dir" ]]; then
    echo "[ERROR] yadm repository not found for user '$user': $yadm_repo_dir"
    echo "[ERROR] Run radp:yadm/clone first"
    return 1
  fi

  echo "[INFO] Initializing yadm submodules for user '$user'..."

  # Build SSH environment prefix (always set — handles StrictHostKeyChecking and optional key)
  local ssh_cmd
  ssh_cmd=$(build_ssh_command)
  local env_prefix="HOME=\"$home_dir\" GIT_SSH_COMMAND=\"$ssh_cmd\""

  run_as_user "$user" "$env_prefix" "yadm submodule update --init --recursive" || {
    echo "[WARN] yadm submodule update failed for user '$user'"
    return 1
  }

  echo "[OK] yadm submodules updated for user '$user'"
}

# Process each user
IFS=',' read -ra users <<< "$YADM_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    submodules_for_user "$user"
  fi
done

echo "[INFO] yadm submodules configuration completed"
