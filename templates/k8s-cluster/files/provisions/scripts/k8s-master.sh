#!/usr/bin/env bash
set -euo pipefail

# Kubernetes master node initialization script

POD_NETWORK_CIDR="${POD_NETWORK_CIDR:-10.244.0.0/16}"
CNI_PLUGIN="${CNI_PLUGIN:-flannel}"

echo "[INFO] Initializing Kubernetes master node..."

# Get the private IP address
MASTER_IP=$(hostname -I | awk '{print $2}')
if [[ -z "${MASTER_IP}" ]]; then
  MASTER_IP=$(hostname -I | awk '{print $1}')
fi

echo "[INFO] Master IP: ${MASTER_IP}"

# Initialize the cluster
kubeadm init \
  --apiserver-advertise-address="${MASTER_IP}" \
  --pod-network-cidr="${POD_NETWORK_CIDR}" \
  --ignore-preflight-errors=NumCPU

# Configure kubectl for root
mkdir -p /root/.kube
cp /etc/kubernetes/admin.conf /root/.kube/config

# Configure kubectl for vagrant user
mkdir -p /home/vagrant/.kube
cp /etc/kubernetes/admin.conf /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube

# Install CNI plugin
case "${CNI_PLUGIN}" in
  flannel)
    echo "[INFO] Installing Flannel CNI..."
    kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
    ;;
  calico)
    echo "[INFO] Installing Calico CNI..."
    kubectl apply -f https://raw.githubusercontent.com/projectcalico/calico/v3.26.1/manifests/calico.yaml
    ;;
  *)
    echo "[WARN] Unknown CNI plugin: ${CNI_PLUGIN}, skipping installation"
    ;;
esac

# Generate join command and save it
kubeadm token create --print-join-command > /vagrant/join-command.sh
chmod +x /vagrant/join-command.sh

echo "[INFO] Kubernetes master initialized successfully"
echo "[INFO] Join command saved to /vagrant/join-command.sh"
