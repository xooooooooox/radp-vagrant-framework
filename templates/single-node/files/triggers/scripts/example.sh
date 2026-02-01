#!/usr/bin/env bash
set -euo pipefail

# Example user trigger script
# This script is executed on the host when the trigger fires
#
# Trigger scripts run on the host machine (not inside the VM)
# Use run-remote in the trigger definition for guest execution

echo "[INFO] Running example user trigger on host"
echo "[INFO] Trigger completed"
