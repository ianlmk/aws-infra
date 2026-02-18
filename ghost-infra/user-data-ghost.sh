#!/bin/bash
set -e

# Ghost provisioning script (runs on EC2 instance startup)

export DEBIAN_FRONTEND=noninteractive

echo "=== Ghost Provisioning Started ==="
echo "DB Host: ${ghost_db_host}"
echo "DB Name: ${ghost_db_name}"
echo "Ghost URL: ${ghost_url}"

# Update system packages
apt-get update
apt-get upgrade -y

# Install system dependencies
apt-get install -y \
  curl \
  wget \
  git \
  build-essential \
  python3 \
  python3-pip \
  nginx \
  mysql-client \
  certbot \
  python3-certbot-nginx

# Install Node.js
curl -fsSL https://deb.nodesource.com/setup_${node_version}.x | sudo -E bash -
apt-get install -y nodejs

echo "Node.js version: $(node --version)"
echo "NPM version: $(npm --version)"

# Create ghost user and directory
useradd -m -s /bin/bash ghost || true  # Ignore if already exists
mkdir -p /var/www/ghost
chown -R ghost:ghost /var/www/ghost

# Install Ghost CLI
npm install -g ghost-cli@latest
npm install -g knex-migrator

# Ghost configuration
cd /var/www/ghost

# Create config file
cat > config.production.json <<'EOF'
{
  "url": "${ghost_url}",
  "server": {
    "port": 2368,
    "host": "127.0.0.1"
  },
  "database": {
    "client": "mysql",
    "connection": {
      "host": "${ghost_db_host}",
      "port": ${ghost_db_port},
      "user": "${ghost_db_user}",
      "password": "${ghost_db_password}",
      "database": "${ghost_db_name}"
    }
  },
  "mail": {
    "transport": "Direct"
  },
  "logging": {
    "transports": ["stdout"]
  },
  "process": "systemd",
  "paths": {
    "contentPath": "/var/www/ghost/content"
  }
}
EOF

chown ghost:ghost config.production.json
chmod 640 config.production.json

# Create systemd service for Ghost
cat > /etc/systemd/system/ghost.service <<'EOF'
[Unit]
Description=Ghost Blog
Documentation=https://ghost.org/docs/
After=network.target

[Service]
Type=simple
User=ghost
WorkingDirectory=/var/www/ghost
ExecStart=/usr/bin/node /var/www/ghost/current/index.js
Restart=always
RestartSec=5
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload
systemctl enable ghost

# Configure Nginx as reverse proxy
cat > /etc/nginx/sites-available/ghost <<'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:2368;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection "upgrade";
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header Host $http_host;
    }
}
EOF

ln -sf /etc/nginx/sites-available/ghost /etc/nginx/sites-enabled/ghost
rm -f /etc/nginx/sites-enabled/default

nginx -t
systemctl restart nginx
systemctl enable nginx

echo "=== Ghost Provisioning Complete ==="
echo "Ghost should be available at ${ghost_url}"
echo "Check status: systemctl status ghost"
echo "View logs: journalctl -u ghost -f"
