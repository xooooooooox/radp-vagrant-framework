#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:yadm/bootstrap
# Run yadm bootstrap on an already-cloned yadm repository
#
# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
#
# General:
#   YADM_USERS           - Target users (auto-detected when unprivileged)
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Example 1: Bootstrap after clone
#   provisions:
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "git@github.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#
#     - name: radp:yadm/bootstrap
#       enabled: true
#
# Example 2: Bootstrap after decrypt and submodules
#   provisions:
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
#     - name: radp:yadm/bootstrap
#       enabled: true
#
# ============================================================================

echo "[INFO] Configuring yadm bootstrap..."

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

# Run a command as a specific user
run_as_user() {
  local user="$1"
  local cmd="$2"

  if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
    su - "$user" -c "$cmd"
  else
    eval "$cmd"
  fi
}

# Run bootstrap for a user
bootstrap_for_user() {
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

  echo "[INFO] Running yadm bootstrap for user '$user'..."

  run_as_user "$user" "yadm bootstrap" || {
    echo "[WARN] yadm bootstrap failed or not available"
    return 1
  }

  echo "[OK] yadm bootstrap completed for user '$user'"
}

# Process each user
IFS=',' read -ra users <<< "$YADM_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    bootstrap_for_user "$user"
  fi
done

echo "[INFO] yadm bootstrap configuration completed"
