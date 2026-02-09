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
#   YADM_DECRYPT         - Run decrypt after clone (default false, needs GPG)
#   YADM_CLASS           - Set yadm class before clone
#
# GPG decryption (when YADM_DECRYPT=true):
#   YADM_GPG_PASSPHRASE      - GPG passphrase for decrypt
#   YADM_GPG_PASSPHRASE_FILE - Path to file containing GPG passphrase
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
# Example 2: SSH clone
#   provisions:
#     - name: radp:yadm/clone
#       enabled: true
#       env:
#         YADM_REPO_URL: "git@github.com:user/dotfiles.git"
#         YADM_SSH_KEY_FILE: "/vagrant/.secrets/id_rsa"
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

# Ensure /usr/local/bin is in PATH (sudoers secure_path may exclude it)
[[ ":$PATH:" != *":/usr/local/bin:"* ]] && export PATH="/usr/local/bin:$PATH"

# Validate required variables
if [[ -z "${YADM_REPO_URL:-}" ]]; then
  echo "[ERROR] YADM_REPO_URL is required"
  exit 1
fi

# Validate file existence
for var_name in YADM_SSH_KEY_FILE YADM_HTTPS_TOKEN_FILE YADM_GPG_PASSPHRASE_FILE; do
  eval "file_path=\${${var_name}:-}"
  if [[ -n "$file_path" && ! -f "$file_path" ]]; then
    echo "[ERROR] File not found for ${var_name}: $file_path"
    exit 1
  fi
done

# Default values
YADM_DECRYPT="${YADM_DECRYPT:-false}"
YADM_SSH_STRICT_HOST_KEY="${YADM_SSH_STRICT_HOST_KEY:-false}"

# Determine target users based on execution context
CURRENT_USER=$(whoami)
if [[ "$CURRENT_USER" == "root" ]]; then
  SUDO=""
  if [[ -z "${YADM_USERS:-}" ]]; then
    echo "[ERROR] YADM_USERS must be specified when running as root (privileged: true)"
    exit 1
  fi
else
  SUDO="sudo"
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

# Install git if not present (yadm requires git)
install_git() {
  if command -v git &>/dev/null; then
    return 0
  fi

  echo "[INFO] Installing git (required by yadm)..."
  if command -v apt-get &>/dev/null; then
    ${SUDO} apt-get update -qq && ${SUDO} apt-get install -y -qq git
  elif command -v yum &>/dev/null; then
    ${SUDO} yum install -y -q git
  elif command -v dnf &>/dev/null; then
    ${SUDO} dnf install -y -q git
  elif command -v apk &>/dev/null; then
    ${SUDO} apk add --quiet git
  elif command -v pacman &>/dev/null; then
    ${SUDO} pacman -S --noconfirm git
  else
    echo "[ERROR] Unsupported package manager — cannot install git"
    exit 1
  fi
}

# Install yadm if not present
install_yadm() {
  if command -v yadm &>/dev/null; then
    return 0
  fi

  echo "[INFO] Installing yadm..."
  local yadm_url="https://github.com/yadm-dev/yadm/raw/master/yadm"

  if command -v apt-get &>/dev/null; then
    ${SUDO} apt-get update -qq && ${SUDO} apt-get install -y -qq yadm 2>/dev/null || {
      ${SUDO} curl -fLo /usr/local/bin/yadm "$yadm_url"
      ${SUDO} chmod +x /usr/local/bin/yadm
    }
  elif command -v yum &>/dev/null; then
    # yadm may not be in default repos, install from GitHub
    ${SUDO} curl -fLo /usr/local/bin/yadm "$yadm_url"
    ${SUDO} chmod +x /usr/local/bin/yadm
  elif command -v dnf &>/dev/null; then
    ${SUDO} dnf install -y -q yadm 2>/dev/null || {
      ${SUDO} curl -fLo /usr/local/bin/yadm "$yadm_url"
      ${SUDO} chmod +x /usr/local/bin/yadm
    }
  elif command -v apk &>/dev/null; then
    ${SUDO} apk add --quiet yadm 2>/dev/null || {
      ${SUDO} curl -fLo /usr/local/bin/yadm "$yadm_url"
      ${SUDO} chmod +x /usr/local/bin/yadm
    }
  elif command -v pacman &>/dev/null; then
    ${SUDO} pacman -S --noconfirm yadm
  else
    # Fallback: install from GitHub
    echo "[INFO] Installing yadm from GitHub..."
    ${SUDO} curl -fLo /usr/local/bin/yadm "$yadm_url"
    ${SUDO} chmod +x /usr/local/bin/yadm
  fi

  if ! command -v yadm &>/dev/null; then
    echo "[ERROR] Failed to install yadm"
    exit 1
  fi
}

install_git
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

# Prepare GPG for non-interactive decrypt
# Presets passphrase in gpg-agent if YADM_GPG_PASSPHRASE(_FILE) is provided.
# gpg-agent is per-user, so the presetting must run as the target user (not root).
prepare_gpg_decrypt() {
  local user="$1"
  local home_dir="$2"
  local gnupg_dir="${home_dir}/.gnupg"

  # --- Resolve passphrase ---
  local passphrase=""
  if [[ -n "${YADM_GPG_PASSPHRASE:-}" ]]; then
    passphrase="$YADM_GPG_PASSPHRASE"
  elif [[ -n "${YADM_GPG_PASSPHRASE_FILE:-}" && -f "$YADM_GPG_PASSPHRASE_FILE" ]]; then
    passphrase=$(cat "$YADM_GPG_PASSPHRASE_FILE")
  fi

  if [[ -z "$passphrase" ]]; then
    return 0
  fi

  if [[ ! -d "$gnupg_dir" ]]; then
    echo "[WARN] GPG directory not found: $gnupg_dir"
    return 0
  fi

  # --- Find gpg-preset-passphrase binary ---
  local gpg_preset_cmd=""
  local libexecdir
  libexecdir=$(gpgconf --list-dirs 2>/dev/null | awk -F: '/^libexecdir:/ {print $2}')
  if [[ -n "$libexecdir" && -x "${libexecdir}/gpg-preset-passphrase" ]]; then
    gpg_preset_cmd="${libexecdir}/gpg-preset-passphrase"
  elif command -v gpg-preset-passphrase &>/dev/null; then
    gpg_preset_cmd="gpg-preset-passphrase"
  else
    echo "[WARN] gpg-preset-passphrase not found, cannot preset passphrase"
    return 0
  fi

  # --- Configure gpg-agent.conf (as root for file access) ---
  local agent_conf="${gnupg_dir}/gpg-agent.conf"
  if [[ ! -f "$agent_conf" ]]; then
    echo "allow-preset-passphrase" > "$agent_conf"
    chmod 600 "$agent_conf"
    chown "${user}:$(id -gn "$user" 2>/dev/null)" "$agent_conf" 2>/dev/null || true
  elif ! grep -q "^allow-preset-passphrase" "$agent_conf"; then
    echo "allow-preset-passphrase" >> "$agent_conf"
  fi

  # --- Write passphrase to secure temp file ---
  local pass_file
  pass_file=$(mktemp /tmp/.yadm-gpg-XXXXXX)
  echo "$passphrase" > "$pass_file"
  chmod 600 "$pass_file"
  chown "$user" "$pass_file" 2>/dev/null || chmod 644 "$pass_file"

  # --- Generate temp script to run as target user ---
  # gpg-agent is per-user; presetting MUST happen in the user's agent context
  local preset_script
  preset_script=$(mktemp /tmp/.yadm-preset-XXXXXX.sh)
  cat > "$preset_script" <<EOFSCRIPT
#!/usr/bin/env bash
export GNUPGHOME="$gnupg_dir"
gpgconf --homedir "$gnupg_dir" --reload gpg-agent 2>/dev/null || \
  gpgconf --homedir "$gnupg_dir" --launch gpg-agent 2>/dev/null || true
keygrips=\$(gpg --homedir "$gnupg_dir" --with-keygrip --with-colons --list-secret-keys 2>/dev/null | \
  awk -F: '/^grp/ {print \$10}')
count=0
for kg in \$keygrips; do
  if "$gpg_preset_cmd" --homedir "$gnupg_dir" --preset "\$kg" < "$pass_file" 2>/dev/null; then
    count=\$((count + 1))
  fi
done
if [ \$count -gt 0 ]; then
  echo "[INFO] GPG passphrase preset for \$count keygrip(s)"
else
  echo "[WARN] Failed to preset GPG passphrase for any keygrip"
fi
EOFSCRIPT
  chmod 755 "$preset_script"

  # --- Run as target user (critical for correct gpg-agent) ---
  run_as_user "$user" "" "$preset_script"
  local rc=$?

  # --- Cleanup ---
  rm -f "$pass_file" "$preset_script"
  return $rc
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
  local env_prefix="HOME=\"$home_dir\""
  local clone_opts="--no-bootstrap"  # Bootstrap handled by radp:yadm/bootstrap

  if is_ssh_url "$YADM_REPO_URL"; then
    # SSH clone
    local ssh_cmd
    ssh_cmd=$(build_ssh_command)

    if ! test_ssh_connectivity "$YADM_REPO_URL" "$ssh_cmd"; then
      echo "[ERROR] Cannot reach repository: $YADM_REPO_URL"
      return 1
    fi

    env_prefix="HOME=\"$home_dir\" GIT_SSH_COMMAND=\"$ssh_cmd\""
  else
    # HTTPS clone
    repo_url=$(build_https_url "$YADM_REPO_URL")
  fi

  # Step 1: Set yadm class if specified (no SSH needed)
  if [[ -n "${YADM_CLASS:-}" ]]; then
    echo "[INFO] Setting yadm class to: $YADM_CLASS"
    run_as_user "$user" "HOME=\"$home_dir\"" "yadm config local.class \"$YADM_CLASS\""
  fi

  # Step 2: Clone repository (always --no-bootstrap first)
  run_as_user "$user" "$env_prefix" "yadm clone $clone_opts \"$repo_url\""
  echo "[INFO] yadm clone completed for user '$user'"

  # Step 3: Decrypt if requested
  if [[ "$YADM_DECRYPT" == "true" ]]; then
    prepare_gpg_decrypt "$user" "$home_dir"
    echo "[INFO] Running yadm decrypt for user '$user'..."
    if ! run_as_user "$user" "HOME=\"$home_dir\"" "yadm decrypt"; then
      echo "[ERROR] yadm decrypt failed for user '$user' - ensure GPG key is imported and passphrase is available"
      exit 1
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
