#!/bin/bash
# Disable swap partition (required for Kubernetes)
# This script is idempotent - safe to run multiple times

set -e

echo "[INFO] Disabling swap..."

# Check if swap is enabled
if swapon --show | grep -q .; then
    # Disable swap immediately
    sudo swapoff -a
    echo "[OK] Swap disabled"
else
    echo "[OK] Swap already disabled"
fi

# Remove swap entries from /etc/fstab to persist across reboots
if grep -q '\sswap\s' /etc/fstab 2>/dev/null; then
    sudo sed -i '/\sswap\s/d' /etc/fstab
    echo "[OK] Removed swap entries from /etc/fstab"
else
    echo "[OK] No swap entries in /etc/fstab"
fi

echo "[INFO] Swap disabled successfully"
