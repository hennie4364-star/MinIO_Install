#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

echo "=== MinIO Setup Script ==="

# Prompt for Ubuntu machine username (needed for certs directory path)
current_user=$(whoami)
read -p "Enter your Ubuntu machine username [default: $current_user]: " MACHINE_USER
MACHINE_USER=${MACHINE_USER:-$current_user}

# Prompt for MinIO Root User and Password
read -p "Enter MinIO Root Username [default: minio-user]: " MINIO_ROOT_USER
MINIO_ROOT_USER=${MINIO_ROOT_USER:-minio-user}

read -sp "Enter MinIO Root Password [default: minio123]: " MINIO_ROOT_PASSWORD
echo "" # Move to a new line after hidden password input
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD:-minio123}

# 1. Download and Install MinIO
echo "Downloading MinIO..."
wget https://dl.min.io/server/minio/release/linux-amd64/minio.RELEASE.2025-09-07T16-13-09Z -O minio

echo "Moving MinIO binary to /usr/local/bin/..."
sudo mv minio /usr/local/bin/

echo "Making MinIO binary executable..."
sudo chmod +x /usr/local/bin/minio

# 2. Create MinIO User, Group, and Directories
echo "Creating minio-user group..."
sudo groupadd -r minio-user || true # Ignores error if group already exists

echo "Creating minio-user system user..."
sudo useradd -M -r -g minio-user minio-user || true # Ignores error if user already exists

echo "Creating data directory..."
sudo mkdir -p /mnt/data

echo "Setting directory ownership and permissions..."
sudo chown minio-user:minio-user /mnt/data
sudo chmod 777 /mnt
sudo chmod 777 /mnt/data

# 3. Create MinIO Environment File
echo "Writing environment file to /etc/default/minio..."
sudo bash -c "cat << 'EOF' > /etc/default/minio
MINIO_VOLUMES=\"/mnt/data\"
MINIO_OPTS=\"--certs-dir /home/$MACHINE_USER/.minio/certs --console-address :9001\"
MINIO_ROOT_USER=$MINIO_ROOT_USER
MINIO_ROOT_PASSWORD=$MINIO_ROOT_PASSWORD
EOF"

# 4. Create Systemd Service File
echo "Writing systemd service file to /etc/systemd/system/minio.service..."
sudo bash -c "cat << 'EOF' > /etc/systemd/system/minio.service
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=$MINIO_ROOT_USER
Group=$MINIO_ROOT_USER
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES
Restart=always
LimitNOFILE=65536
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF"

# 5. Reload, Start and Verify Service
echo "Reloading systemd daemon..."
sudo systemctl daemon-reload

echo "Starting MinIO service..."
sudo systemctl start minio.service

echo "Checking MinIO service status..."
sudo systemctl status minio.service
