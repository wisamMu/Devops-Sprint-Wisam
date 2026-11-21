#!/bin/bash
set -euo pipefail
exec > >(tee /var/log/hello-userdata.log) 2>&1
echo "== $(date -Is) user data start"
if [ ! -f /swapfile ]; then
  dd if=/dev/zero of=/swapfile bs=1M count=1024 status=none
  chmod 600 /swapfile
  mkswap /swapfile
  echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi
swapon -a
dnf install -y -q docker
systemctl enable --now docker
echo "== $(date -Is) user data done: docker $(docker --version)"
