#!/bin/bash
# First-boot script: swap + k3s. Runs once, as root. Log: /var/log/linkpulse-userdata.log
set -euo pipefail
exec > >(tee /var/log/linkpulse-userdata.log) 2>&1
echo "== $(date -Is) user data start"

# 1 GB swap, kept across reboots
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
  chmod 600 /swapfile
  mkswap /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
swapon -a

# k3s: one-node Kubernetes, no Traefik (port 80 is for our Service), kubectl without sudo
curl -sfL https://get.k3s.io \
  | INSTALL_K3S_EXEC="server --disable traefik --write-kubeconfig-mode 644" sh -

# wait until the node is Ready
for _ in $(seq 1 60); do
  if /usr/local/bin/kubectl get nodes 2>/dev/null | grep -q ' Ready'; then break; fi
  sleep 5
done
/usr/local/bin/kubectl get nodes -o wide

echo "== $(date -Is) user data done: $(/usr/local/bin/k3s --version | head -1)"
