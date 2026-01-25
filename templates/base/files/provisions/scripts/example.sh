#!/usr/bin/env bash
set -euo pipefail

# Example user provision script
# This script is executed when the provision runs
#
# Environment variables from provision config are available:
#   ${MESSAGE} - example variable

echo "[INFO] Running example user provision"
echo "[INFO] MESSAGE=${MESSAGE:-not set}"
echo "[INFO] User provision completed"
