#!/bin/bash
#
# userdata.sh - EC2 user data for the Day 3 VPC lab.
# Runs ONCE, as root, on the instance's first boot (cloud-init).
# Log on the instance: /var/log/cloud-init-output.log

set -euxo pipefail

# 1 GB swap first: a t3.micro (1 GB RAM) can freeze while dnf runs (lesson from Day 1)
fallocate -l 1G /swapfile
chmod 600 /swapfile
mkswap /swapfile
swapon /swapfile
echo '/swapfile none swap defaults 0 0' >> /etc/fstab

# Install and start nginx
dnf install -y nginx
cat > /usr/share/nginx/html/index.html <<EOF
<h1>Day 3 VPC lab</h1>
<p>Served by nginx on $(hostname) in subnet public-a (10.0.1.0/24).</p>
EOF
systemctl enable --now nginx
