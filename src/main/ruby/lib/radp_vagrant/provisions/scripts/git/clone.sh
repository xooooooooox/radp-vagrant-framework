#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:git/clone
# Clone git repository with HTTPS or SSH authentication
#
# ============================================================================
# ENVIRONMENT VARIABLES
# ============================================================================
#
# Required:
#   GIT_REPO_URL         - Repository URL (HTTPS or SSH format)
#
# Target options:
#   GIT_CLONE_DIR        - Target directory (default: ~/repo-name)
#   GIT_CLONE_OPTIONS    - Additional git clone options
#
# HTTPS authentication:
#   GIT_HTTPS_USER       - Username for HTTPS auth
#   GIT_HTTPS_TOKEN      - Personal access token
#   GIT_HTTPS_TOKEN_FILE - Path to file containing token
#
# SSH options:
#   GIT_SSH_KEY_FILE     - Path to SSH private key
#   GIT_SSH_HOST         - Override SSH hostname/IP (for DNS issues)
#   GIT_SSH_PORT         - Override SSH port (default 22)
#   GIT_SSH_STRICT_HOST_KEY - Strict host key checking (default false)
#
# General:
#   GIT_SKIP_IF_EXISTS   - Skip if directory exists (default true)
#   GIT_USERS            - Target users (auto-detected when unprivileged)
#
# ============================================================================
# USAGE EXAMPLES
# ============================================================================
#
# Example 1: HTTPS clone (public repo)
#   provisions:
#     - name: radp:git/clone
#       enabled: true
#       env:
#         GIT_REPO_URL: "https://github.com/user/repo.git"
#
# Example 2: HTTPS clone (private repo with token)
#   provisions:
#     - name: radp:git/clone
#       enabled: true
#       env:
#         GIT_REPO_URL: "https://github.com/user/private-repo.git"
#         GIT_HTTPS_USER: "username"
#         GIT_HTTPS_TOKEN_FILE: "/vagrant/.secrets/github-token"
#
# Example 3: SSH clone (with key)
#   provisions:
#     - name: radp:git/clone
#       enabled: true
#       env:
#         GIT_REPO_URL: "git@github.com:user/repo.git"
#         GIT_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
#
# Example 4: SSH clone (private GitLab with DNS override)
#   provisions:
#     - name: radp:git/clone
#       enabled: true
#       env:
#         GIT_REPO_URL: "git@gitlab.example.com:group/repo.git"
#         GIT_SSH_KEY_FILE: "/mnt/ssh/id_rsa_gitlab"
#         GIT_SSH_HOST: "192.168.20.35"
#
# ============================================================================

echo "[INFO] Configuring git clone..."

# Validate required variables
if [[ -z "${GIT_REPO_URL:-}" ]]; then
  echo "[ERROR] GIT_REPO_URL is required"
  exit 1
fi

# Validate file existence
for var_name in GIT_SSH_KEY_FILE GIT_HTTPS_TOKEN_FILE; do
  eval "file_path=\${${var_name}:-}"
  if [[ -n "$file_path" && ! -f "$file_path" ]]; then
    echo "[ERROR] File not found for ${var_name}: $file_path"
    exit 1
  fi
done

# Default values
GIT_SKIP_IF_EXISTS="${GIT_SKIP_IF_EXISTS:-true}"
GIT_SSH_STRICT_HOST_KEY="${GIT_SSH_STRICT_HOST_KEY:-false}"
GIT_SSH_PORT="${GIT_SSH_PORT:-22}"

# Determine target users based on execution context
CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" == "root" ]]; then
  if [[ -z "${GIT_USERS:-}" ]]; then
    echo "[ERROR] GIT_USERS must be specified when running as root (privileged: true)"
    exit 1
  fi
else
  if [[ -z "${GIT_USERS:-}" ]]; then
    GIT_USERS="$CURRENT_USER"
    echo "[INFO] GIT_USERS not specified, using current user: $CURRENT_USER"
  elif [[ "$GIT_USERS" != "$CURRENT_USER" && "$GIT_USERS" == *","* ]]; then
    echo "[WARN] Running as '$CURRENT_USER' but GIT_USERS contains multiple users"
    echo "[WARN] Cannot configure other users without privileged: true, using '$CURRENT_USER'"
    GIT_USERS="$CURRENT_USER"
  elif [[ "$GIT_USERS" != "$CURRENT_USER" ]]; then
    echo "[WARN] Running as '$CURRENT_USER' but GIT_USERS='$GIT_USERS'"
    echo "[WARN] Cannot configure other users without privileged: true, using '$CURRENT_USER'"
    GIT_USERS="$CURRENT_USER"
  fi
fi

# Install git if not present
install_git() {
  if command -v git &>/dev/null; then
    return 0
  fi

  echo "[INFO] Installing git..."
  if command -v apt-get &>/dev/null; then
    sudo apt-get update -qq && sudo apt-get install -y -qq git
  elif command -v yum &>/dev/null; then
    sudo yum install -y -q git
  elif command -v dnf &>/dev/null; then
    sudo dnf install -y -q git
  elif command -v apk &>/dev/null; then
    sudo apk add --quiet git
  else
    echo "[ERROR] Unsupported package manager — cannot install git"
    exit 1
  fi
}

install_git

# Detect URL type
is_ssh_url() {
  local url="$1"
  [[ "$url" =~ ^git@ ]] || [[ "$url" =~ ^ssh:// ]]
}

# Extract repo name from URL
get_repo_name() {
  local url="$1"
  basename "$url" .git
}

# Resolve HTTPS token
get_https_token() {
  if [[ -n "${GIT_HTTPS_TOKEN:-}" ]]; then
    echo "$GIT_HTTPS_TOKEN"
  elif [[ -n "${GIT_HTTPS_TOKEN_FILE:-}" ]]; then
    cat "$GIT_HTTPS_TOKEN_FILE"
  fi
}

# Build authenticated HTTPS URL
build_https_url() {
  local url="$1"
  local user="${GIT_HTTPS_USER:-}"
  local token
  token=$(get_https_token)

  if [[ -n "$token" ]]; then
    if [[ -n "$user" ]]; then
      # https://user:token@host/path
      echo "$url" | sed "s|https://|https://${user}:${token}@|"
    else
      # https://token@host/path (for GitHub PAT)
      echo "$url" | sed "s|https://|https://${token}@|"
    fi
  else
    echo "$url"
  fi
}

# Build GIT_SSH_COMMAND with options
build_ssh_command() {
  local ssh_opts="-o BatchMode=yes"

  if [[ "$GIT_SSH_STRICT_HOST_KEY" == "false" ]]; then
    ssh_opts="$ssh_opts -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null"
  fi

  if [[ -n "${GIT_SSH_KEY_FILE:-}" ]]; then
    ssh_opts="$ssh_opts -i $GIT_SSH_KEY_FILE"
  fi

  if [[ -n "${GIT_SSH_HOST:-}" ]]; then
    ssh_opts="$ssh_opts -o HostName=$GIT_SSH_HOST"
  fi

  if [[ -n "${GIT_SSH_PORT:-}" && "$GIT_SSH_PORT" != "22" ]]; then
    ssh_opts="$ssh_opts -o Port=$GIT_SSH_PORT"
  fi

  echo "ssh $ssh_opts"
}

# Test SSH connectivity
test_ssh_connectivity() {
  local url="$1"
  local ssh_cmd="$2"

  # Extract host from URL (git@host:path or ssh://user@host/path)
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
    # Exit code 1 is OK for GitHub/GitLab (they return 1 for successful auth)
    echo "[INFO] SSH connectivity OK"
    return 0
  else
    echo "[ERROR] SSH connectivity failed to $host"
    return 1
  fi
}

# Clone repository for a user
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

  # Determine target directory
  local clone_dir="${GIT_CLONE_DIR:-}"
  if [[ -z "$clone_dir" ]]; then
    local repo_name
    repo_name=$(get_repo_name "$GIT_REPO_URL")
    clone_dir="${home_dir}/${repo_name}"
  elif [[ "$clone_dir" != /* ]]; then
    # Relative path, prepend home dir
    clone_dir="${home_dir}/${clone_dir}"
  fi

  # Check if already exists
  if [[ -d "$clone_dir" && "$GIT_SKIP_IF_EXISTS" == "true" ]]; then
    echo "[WARN] Directory already exists, skipping: $clone_dir"
    return 0
  fi

  echo "[INFO] Cloning repository for user '$user' to: $clone_dir"

  # Prepare clone command
  local clone_cmd="git clone"
  if [[ -n "${GIT_CLONE_OPTIONS:-}" ]]; then
    clone_cmd="$clone_cmd $GIT_CLONE_OPTIONS"
  fi

  local repo_url="$GIT_REPO_URL"
  local env_prefix=""

  if is_ssh_url "$GIT_REPO_URL"; then
    # SSH clone
    local ssh_cmd
    ssh_cmd=$(build_ssh_command)

    # Test connectivity first
    if ! test_ssh_connectivity "$GIT_REPO_URL" "$ssh_cmd"; then
      echo "[ERROR] Cannot reach repository: $GIT_REPO_URL"
      return 1
    fi

    env_prefix="GIT_SSH_COMMAND=\"$ssh_cmd\""
  else
    # HTTPS clone
    repo_url=$(build_https_url "$GIT_REPO_URL")
  fi

  # Execute clone
  if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
    # Running as root, clone as target user
    su - "$user" -c "$env_prefix $clone_cmd \"$repo_url\" \"$clone_dir\""
  else
    # Running as the user directly
    eval "$env_prefix $clone_cmd \"$repo_url\" \"$clone_dir\""
  fi

  # Fix ownership if running as root
  if [[ "$CURRENT_USER" == "root" && "$user" != "root" ]]; then
    chown -R "${user}:$(id -gn "$user")" "$clone_dir"
  fi

  echo "[OK] Repository cloned for user '$user': $clone_dir"
}

# Process each user
IFS=',' read -ra users <<< "$GIT_USERS"
for user in "${users[@]}"; do
  user=$(echo "$user" | xargs)  # Trim whitespace
  if [[ -n "$user" ]]; then
    clone_for_user "$user"
  fi
done

echo "[INFO] Git clone configuration completed"
