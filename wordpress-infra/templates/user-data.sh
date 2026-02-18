#!/bin/bash
# User data script for WordPress EC2 instance
# Runs once at instance startup

set -e

# Update system packages
apt-get update
apt-get upgrade -y

# Install basic tools
apt-get install -y \
  curl \
  wget \
  git \
  htop \
  net-tools \
  unzip \
  jq

# Create ansible user (if bootstrap hasn't already)
if ! id -u ansible >/dev/null 2>&1; then
  useradd -m -s /bin/bash ansible
  usermod -aG sudo ansible
  echo "ansible ALL=(ALL) NOPASSWD:ALL" >> /etc/sudoers.d/ansible
  chmod 0440 /etc/sudoers.d/ansible
fi

# Create .ssh directory for ansible user
mkdir -p /home/ansible/.ssh
chmod 700 /home/ansible/.ssh

# EC2 is ready for Ansible deployment
echo "✓ EC2 initialization complete" > /var/log/user-data.log
