#!/usr/bin/env bash
set -euo pipefail

# Development environment setup script
# Customize this for your specific needs

echo "[INFO] Running development environment setup..."

# Update package cache
apt-get update -qq

# Install common development tools
apt-get install -y -qq \
  curl \
  wget \
  git \
  vim \
  htop \
  jq \
  unzip

# Optional: Install Docker
if [[ "${INSTALL_DOCKER:-false}" == "true" ]]; then
  echo "[INFO] Installing Docker..."
  curl -fsSL https://get.docker.com | sh
  usermod -aG docker vagrant
fi

echo "[INFO] Development environment setup completed"
