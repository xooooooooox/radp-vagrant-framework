#!/usr/bin/env bash
set -euo pipefail

# Builtin provision: radp:time/chrony-sync
# Configure chrony for time synchronization with NTP servers
#
# Optional environment variables:
#   NTP_SERVERS    - Comma-separated list of NTP servers (default: system default or pool.ntp.org)
#   NTP_POOL       - Use NTP pool instead of individual servers (default: pool.ntp.org)
#   TIMEZONE       - Timezone to set (e.g., "Asia/Shanghai", default: keep current)
#   SYNC_NOW       - Force immediate time sync (default: true)
#
# Usage in vagrant.yaml:
#   provisions:
#     - name: radp:time/chrony-sync
#       enabled: true
#       env:
#         NTP_SERVERS: "ntp.aliyun.com,ntp1.aliyun.com"
#         TIMEZONE: "Asia/Shanghai"

echo "[INFO] Configuring chrony time synchronization..."

# Default values
NTP_SERVERS="${NTP_SERVERS:-}"
NTP_POOL="${NTP_POOL:-pool.ntp.org}"
TIMEZONE="${TIMEZONE:-}"
SYNC_NOW="${SYNC_NOW:-true}"

# Detect package manager and install chrony
install_chrony() {
  if command -v chronyc >/dev/null 2>&1; then
    echo "[OK] chrony is already installed"
    return 0
  fi

  echo "[INFO] Installing chrony..."
  if command -v yum >/dev/null 2>&1; then
    yum install -y chrony
  elif command -v dnf >/dev/null 2>&1; then
    dnf install -y chrony
  elif command -v apt-get >/dev/null 2>&1; then
    apt-get update && apt-get install -y chrony
  elif command -v apk >/dev/null 2>&1; then
    apk add --no-cache chrony
  else
    echo "[ERROR] Cannot install chrony: unsupported package manager"
    exit 1
  fi
  echo "[INFO] chrony installed successfully"
}

# Find chrony config file
find_chrony_config() {
  local configs=(
    "/etc/chrony.conf"
    "/etc/chrony/chrony.conf"
  )
  for conf in "${configs[@]}"; do
    if [[ -f "$conf" ]]; then
      echo "$conf"
      return 0
    fi
  done
  # Default to /etc/chrony.conf if none found
  echo "/etc/chrony.conf"
}

# Configure NTP servers
configure_ntp_servers() {
  local chrony_conf
  chrony_conf=$(find_chrony_config)

  # Backup original config
  if [[ -f "$chrony_conf" && ! -f "${chrony_conf}.orig" ]]; then
    cp "$chrony_conf" "${chrony_conf}.orig"
    echo "[INFO] Backed up original config to ${chrony_conf}.orig"
  fi

  # If custom servers specified, configure them
  if [[ -n "$NTP_SERVERS" ]]; then
    echo "[INFO] Configuring custom NTP servers: $NTP_SERVERS"

    # Check if already configured by this script
    if grep -q "# Added by radp:time/chrony-sync" "$chrony_conf" 2>/dev/null; then
      echo "[OK] NTP servers already configured by this script"
      return 0
    fi

    # Comment out existing server/pool lines (only uncommented ones)
    sed -i.bak -E 's/^([^#]*)(server|pool)\s+/#\1\2 /' "$chrony_conf"

    # Build new server lines
    local new_servers=""
    IFS=',' read -ra servers <<< "$NTP_SERVERS"
    for server in "${servers[@]}"; do
      server=$(echo "$server" | xargs)  # Trim whitespace
      if [[ -n "$server" ]]; then
        new_servers="${new_servers}server ${server} iburst\n"
      fi
    done

    # Append new servers at the end of the file
    echo -e "\n# Added by radp:time/chrony-sync\n${new_servers}" >> "$chrony_conf"

    # Clean up sed backup
    rm -f "${chrony_conf}.bak"

    # Ensure correct permissions (chronyd runs as chrony user and needs read access)
    chmod 644 "$chrony_conf"
    chown root:root "$chrony_conf"

    echo "[INFO] Configured NTP servers in $chrony_conf"
  elif [[ -n "$NTP_POOL" ]]; then
    # Use pool if no custom servers
    echo "[INFO] Using NTP pool: $NTP_POOL"
  fi
}

# Set timezone if specified
configure_timezone() {
  if [[ -z "$TIMEZONE" ]]; then
    echo "[INFO] Keeping current timezone: $(timedatectl show --property=Timezone --value 2>/dev/null || cat /etc/timezone 2>/dev/null || echo 'unknown')"
    return 0
  fi

  echo "[INFO] Setting timezone to: $TIMEZONE"
  if command -v timedatectl >/dev/null 2>&1; then
    timedatectl set-timezone "$TIMEZONE"
  elif [[ -f "/usr/share/zoneinfo/$TIMEZONE" ]]; then
    ln -sf "/usr/share/zoneinfo/$TIMEZONE" /etc/localtime
    echo "$TIMEZONE" > /etc/timezone
  else
    echo "[WARN] Cannot set timezone: $TIMEZONE not found"
    return 0
  fi
  echo "[OK] Timezone set to $TIMEZONE"
}

# Start and enable chrony service
start_chrony() {
  local service_name=""

  # Detect the correct service name
  # CentOS/RHEL/Fedora: chronyd
  # Debian/Ubuntu: chrony
  if systemctl list-unit-files chronyd.service &>/dev/null; then
    service_name="chronyd"
  elif systemctl list-unit-files chrony.service &>/dev/null; then
    service_name="chrony"
  elif [[ -f /usr/lib/systemd/system/chronyd.service ]]; then
    service_name="chronyd"
  elif [[ -f /lib/systemd/system/chrony.service ]]; then
    service_name="chrony"
  else
    # Default based on OS
    if [[ -f /etc/redhat-release ]]; then
      service_name="chronyd"
    else
      service_name="chrony"
    fi
  fi

  echo "[INFO] Enabling and starting $service_name service..."

  if command -v systemctl >/dev/null 2>&1; then
    systemctl enable "$service_name" 2>/dev/null || true
    systemctl restart "$service_name"
  elif command -v service >/dev/null 2>&1; then
    service "$service_name" restart
  else
    echo "[WARN] Cannot manage chrony service: no systemctl or service command"
    return 0
  fi

  echo "[OK] $service_name service is running"
}

# Force immediate synchronization
sync_time_now() {
  if [[ "$SYNC_NOW" != "true" ]]; then
    return 0
  fi

  echo "[INFO] Forcing immediate time synchronization..."

  # Wait a moment for chrony to start
  sleep 2

  # Force sync
  if chronyc makestep >/dev/null 2>&1; then
    echo "[OK] Time synchronized"
  else
    echo "[WARN] Could not force time sync (chronyc makestep failed)"
  fi

  # Show current status
  echo "[INFO] Time synchronization status:"
  chronyc tracking 2>/dev/null | head -5 || true
}

# Main execution
install_chrony
configure_ntp_servers
configure_timezone
start_chrony
sync_time_now

echo ""
echo "[INFO] chrony time synchronization configuration completed"
echo "[INFO] Use 'chronyc sources' to view NTP sources"
echo "[INFO] Use 'chronyc tracking' to view sync status"
