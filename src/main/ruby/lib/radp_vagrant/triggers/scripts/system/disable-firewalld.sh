#!/bin/bash
# Disable firewalld service
# This script is idempotent - safe to run multiple times

set -e

echo "[INFO] Disabling firewalld..."

# Check if firewalld is available
if ! command -v firewall-cmd &>/dev/null; then
    echo "[OK] firewalld not installed, skipping"
    exit 0
fi

# Check if firewalld service exists
if ! systemctl list-unit-files firewalld.service &>/dev/null; then
    echo "[OK] firewalld service not found, skipping"
    exit 0
fi

# Check current status
if systemctl is-active --quiet firewalld 2>/dev/null; then
    sudo systemctl stop firewalld
    echo "[OK] firewalld stopped"
else
    echo "[OK] firewalld already stopped"
fi

# Disable firewalld to prevent it from starting on boot
if systemctl is-enabled --quiet firewalld 2>/dev/null; then
    sudo systemctl disable firewalld
    echo "[OK] firewalld disabled"
else
    echo "[OK] firewalld already disabled"
fi

echo "[INFO] firewalld disabled successfully"
