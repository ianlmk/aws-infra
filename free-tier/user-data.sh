#!/bin/bash
#---------#
# SSH Key Injection Script #
#---------#
# Injects SSH public key into instance for remote access
# Template variables: ${public_key}

set -e

echo "Setting up SSH key access..."

# Detect OS user (ubuntu for Ubuntu AMIs, ec2-user for Amazon Linux)
if id ubuntu &>/dev/null; then
  SSH_USER="ubuntu"
  SSH_HOME="/home/ubuntu"
elif id ec2-user &>/dev/null; then
  SSH_USER="ec2-user"
  SSH_HOME="/home/ec2-user"
else
  SSH_USER="root"
  SSH_HOME="/root"
fi

echo "Configuring SSH for user: $SSH_USER"

# Create .ssh directory
mkdir -p "$SSH_HOME/.ssh"

# Add public key to authorized_keys
echo "${public_key}" >> "$SSH_HOME/.ssh/authorized_keys"

# Set correct permissions
chmod 600 "$SSH_HOME/.ssh/authorized_keys"
chmod 700 "$SSH_HOME/.ssh"
chown "$SSH_USER:$SSH_USER" "$SSH_HOME/.ssh" "$SSH_HOME/.ssh/authorized_keys"

echo "✅ SSH key successfully injected for user: $SSH_USER"
