#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:yadm/clone
# Clone dotfiles repository using yadm (Yet Another Dotfiles Manager)
#
# ============================================================================
# WHAT IS YADM?
# ============================================================================
#
# yadm is a dotfiles manager that wraps around git. It stores your dotfiles
# in a bare git repository while they appear in your home directory.
#
# Key features:
#   - Tracks files in $HOME without moving them
#   - Supports encrypted files (via GPG)
#   - Supports alternate files per host/class/OS
#   - Has bootstrap script for automated setup
#
# Repository location: ~/.local/share/yadm/repo.git
#
# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
#
# Required:
#   YADM_REPO_URL        - Dotfiles repository URL (HTTPS or SSH)
#
# yadm options:
#   YADM_BOOTSTRAP       - Run bootstrap after clone (default false)
#   YADM_DECRYPT         - Run decrypt after clone (default false, needs GPG)
#   YADM_CLASS           - Set yadm class before clone
#
# HTTPS authentication:
#   YADM_HTTPS_USER      - Username for HTTPS auth
#   YADM_HTTPS_TOKEN     - Personal access token
#   YADM_HTTPS_TOKEN_FILE - Path to file containing token
#
# SSH options:
#   YADM_SSH_KEY_FILE    - Path to SSH private key
#   YADM_SSH_HOST        - Override SSH hostname/IP
#   YADM_SSH_PORT        - Override SSH port (default 22)
#   YADM_SSH_STRICT_HOST_KEY - Strict host key checking (default false)
#
# General:
#   YADM_USERS           - Target users (auto-detected when unprivileged)
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Example 1: Basic yadm clone (HTTPS)
#   provisions:
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "https://github.com/user/dotfiles.git"
#
# Example 2: SSH clone with bootstrap
#   provisions:
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "git@github.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#         YADM_BOOTSTRAP: "true"
#
# Example 3: Private GitLab with decryption (requires radp:crypto/gpg-import first)
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
#         YADM_REPO_URL: "git@gitlab.example.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/mnt/ssh/id_rsa_gitlab"
#         YADM_SSH_HOST: "192.168.20.35"
#         YADM_DECRYPT: "true"
#
# ============================================================================

echo "[INFO] Configuring yadm clone..."

# Validate required variables
if [[ -z "${YADM_REPO_URL:-}" ]]; then
  echo "[ERROR] YADM_REPO_URL is required"
  exit 1
fi

# Validate file existence
for var_name in YADM_SSH_KEY_FILE YADM_HTTPS_TOKEN_FILE; do
  eval "file_path=\${${var_name}:-}"
  if [[ -n "$file_path" && ! -f "$file_path" ]]; then
    echo "[ERROR] File not found for ${var_name}: $file_path"
    exit 1
  fi
done

# Default values
YADM_BOOTSTRAP="${YADM_BOOTSTRAP:-false}"
YADM_DECRYPT="${YADM_DECRYPT:-false}"
YADM_SSH_STRICT_HOST_KEY="${YADM_SSH_STRICT_HOST_KEY:-false}"
YADM_SSH_PORT="${YADM_SSH_PORT:-22}"

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

# Install yadm if not present
install_yadm() {
  if command -v yadm &>/dev/null; then
    return 0
  fi

  echo "[INFO] Installing yadm..."
  local yadm_url="https://github.com/yadm-dev/yadm/raw/master/yadm"

  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq yadm 2>/dev/null || {
      sudo curl -fLo /usr/local/bin/yadm "$yadm_url"
      sudo chmod +x /usr/local/bin/yadm
    }
  elif command -v yum &>/dev/null; then
    # yadm may not be in default repos, install from GitHub
    sudo curl -fLo /usr/local/bin/yadm "$yadm_url"
    sudo chmod +x /usr/local/bin/yadm
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q yadm 2>/dev/null || {
      sudo curl -fLo /usr/local/bin/yadm "$yadm_url"
      sudo chmod +x /usr/local/bin/yadm
    }
  elif command -v apk &>/dev/null; then
    sudo apk add --quiet yadm 2>/dev/null || {
      sudo curl -fLo /usr/local/bin/yadm "$yadm_url"
      sudo chmod +x /usr/local/bin/yadm
    }
  elif command -v pacman &>/dev/null; then
    sudo pacman -S --noconfirm yadm
  else
    # Fallback: install from GitHub
    echo "[INFO] Installing yadm from GitHub..."
    sudo curl -fLo /usr/local/bin/yadm "$yadm_url"
    sudo chmod +x /usr/local/bin/yadm
  fi

  if ! command -v yadm &>/dev/null; then
    echo "[ERROR] Failed to install yadm"
    exit 1
  fi
}

install_yadm

# Detect URL type
is_ssh_url() {
  local url="$1"
  [[ "$url" =~ ^git@ ]] || [[ "$url" =~ ^ssh:// ]]
}

# Resolve HTTPS token
get_https_token() {
  if [[ -n "${YADM_HTTPS_TOKEN:-}" ]]; then
    echo "$YADM_HTTPS_TOKEN"
  elif [[ -n "${YADM_HTTPS_TOKEN_FILE:-}" ]]; then
    cat "$YADM_HTTPS_TOKEN_FILE"
  fi
}

# Build authenticated HTTPS URL
build_https_url() {
  local url="$1"
  local user="${YADM_HTTPS_USER:-}"
  local token
  token=$(get_https_token)

  if [[ -n "$token" ]]; then
    if [[ -n "$user" ]]; then
      echo "$url" | sed "s|https://|https://${user}:${token}@|"
    else
      echo "$url" | sed "s|https://|https://${token}@|"
    fi
  else
    echo "$url"
  fi
}

# Build GIT_SSH_COMMAND with options
build_ssh_command() {
  local ssh_opts="-o BatchMode=yes"

  if [[ "$YADM_SSH_STRICT_HOST_KEY" == "false" ]]; then
    ssh_opts="$ssh_opts -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  fi

  if [[ -n "${YADM_SSH_KEY_FILE:-}" ]]; then
    ssh_opts="$ssh_opts -i $YADM_SSH_KEY_FILE"
  fi

  if [[ -n "${YADM_SSH_HOST:-}" ]]; then
    ssh_opts="$ssh_opts -o HostName=$YADM_SSH_HOST"
  fi

  if [[ -n "${YADM_SSH_PORT:-}" && "$YADM_SSH_PORT" != "22" ]]; then
    ssh_opts="$ssh_opts -o Port=$YADM_SSH_PORT"
  fi

  echo "ssh $ssh_opts"
}

# Test SSH connectivity
test_ssh_connectivity() {
  local url="$1"
  local ssh_cmd="$2"

  # Extract host from URL
  local host
  if [[ "$url" =~ ^git@([^:]+): ]]; then
    host="${BASH_REMATCH[1]}"
  elif [[ "$url" =~ ^ssh://[^@]+@([^/]+) ]]; then
    host="${BASH_REMATCH[1]}"
  else
    echo "[WARN] Could not extract host from URL, skipping connectivity test"
    return 0
  fi

  echo "[INFO] Testing SSH connectivity to $host..."
  if $ssh_cmd -T "git@$host" 2>/dev/null || [[ $? -eq 1 ]]; then
    echo "[INFO] SSH connectivity OK"
    return 0
  else
    echo "[ERROR] SSH connectivity failed to $host"
    return 1
  fi
}

# Clone yadm repository for a user
clone_for_user() {
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

  # Check if yadm repo already exists
  local yadm_repo_dir="${home_dir}/.local/share/yadm/repo.git"
  if [[ -d "$yadm_repo_dir" ]]; then
    echo "[WARN] yadm repository already exists for user '$user', skipping: $yadm_repo_dir"
    return 0
  fi

  echo "[INFO] Cloning yadm repository for user '$user'..."

  # Prepare environment
  local repo_url="$YADM_REPO_URL"
  local env_prefix=""
  local clone_opts="--no-bootstrap"  # Always use --no-bootstrap initially

  if is_ssh_url "$YADM_REPO_URL"; then
    # SSH clone
    local ssh_cmd
    ssh_cmd=$(build_ssh_command)

    if ! test_ssh_connectivity "$YADM_REPO_URL" "$ssh_cmd"; then
      echo "[ERROR] Cannot reach repository: $YADM_REPO_URL"
      return 1
    fi

    env_prefix="GIT_SSH_COMMAND=\"$ssh_cmd\""
  else
    # HTTPS clone
    repo_url=$(build_https_url "$YADM_REPO_URL")
  fi

  # Set yadm class if specified
  if [[ -n "${YADM_CLASS:-}" ]]; then
    echo "[INFO] Setting yadm class to: $YADM_CLASS"
    if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
      su - "$user" -c "yadm config local.class \"$YADM_CLASS\""
    else
      yadm config local.class "$YADM_CLASS"
    fi
  fi

  # Execute yadm clone
  if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
    su - "$user" -c "$env_prefix yadm clone $clone_opts \"$repo_url\""
  else
    eval "$env_prefix yadm clone $clone_opts \"$repo_url\""
  fi

  echo "[INFO] yadm clone completed for user '$user'"

  # Run yadm decrypt if requested
  if [[ "$YADM_DECRYPT" == "true" ]]; then
    echo "[INFO] Running yadm decrypt for user '$user'..."
    if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
      su - "$user" -c "yadm decrypt" || {
        echo "[WARN] yadm decrypt failed - ensure GPG key is imported"
      }
    else
      yadm decrypt || {
        echo "[WARN] yadm decrypt failed - ensure GPG key is imported"
      }
    fi
  fi

  # Run yadm bootstrap if requested
  if [[ "$YADM_BOOTSTRAP" == "true" ]]; then
    echo "[INFO] Running yadm bootstrap for user '$user'..."
    if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
      su - "$user" -c "yadm bootstrap" || {
        echo "[WARN] yadm bootstrap failed or not available"
      }
    else
      yadm bootstrap || {
        echo "[WARN] yadm bootstrap failed or not available"
      }
    fi
  fi

  echo "[OK] yadm setup completed for user '$user'"
}

# Process each user
IFS=',' read -ra users <<< "$YADM_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    clone_for_user "$user"
  fi
done

echo "[INFO] yadm clone configuration completed"
