#!/bin/bash
# Disable SELinux (set to permissive mode)
# This script is idempotent - safe to run multiple times

set -e

echo "[INFO] Disabling SELinux..."

# Check if SELinux is available
if ! command -v getenforce &>/dev/null; then
    echo "[OK] SELinux not installed, skipping"
    exit 0
fi

# Get current SELinux status
current_status=$(getenforce 2>/dev/null || echo "Unknown")

if [[ "$current_status" == "Disabled" ]]; then
    echo "[OK] SELinux already disabled"
    exit 0
fi

if [[ "$current_status" == "Permissive" ]]; then
    echo "[OK] SELinux already in permissive mode"
else
    # Set SELinux to permissive mode immediately
    sudo setenforce 0 2>/dev/null || true
    echo "[OK] SELinux set to permissive mode"
fi

# Update /etc/selinux/config for persistence
selinux_config="/etc/selinux/config"
if [[ -f "$selinux_config" ]]; then
    if grep -q "^SELINUX=enforcing" "$selinux_config"; then
        sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' "$selinux_config"
        echo "[OK] Updated $selinux_config to permissive"
    elif grep -q "^SELINUX=permissive" "$selinux_config"; then
        echo "[OK] $selinux_config already set to permissive"
    else
        echo "[WARN] Could not determine SELinux config state"
    fi
else
    echo "[OK] SELinux config file not found, skipping persistence"
fi

echo "[INFO] SELinux disabled successfully"
