#!/usr/bin/env bash
set -euo pipefail

# Kubernetes worker node join script

echo "[INFO] Joining Kubernetes cluster as worker..."

# Wait for join command to be available
JOIN_CMD_FILE="/vagrant/join-command.sh"
MAX_WAIT=300
WAITED=0

while [[ ! -f "${JOIN_CMD_FILE}" ]]; do
  if [[ ${WAITED} -ge ${MAX_WAIT} ]]; then
    echo "[ERROR] Timeout waiting for join command from master"
    exit 1
  fi
  echo "[INFO] Waiting for master to generate join command..."
  sleep 10
  WAITED=$((WAITED + 10))
done

# Execute join command
echo "[INFO] Executing join command..."
bash "${JOIN_CMD_FILE}"

echo "[INFO] Successfully joined the Kubernetes cluster"
