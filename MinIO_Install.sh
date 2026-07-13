#!/bin/bash

set -e

error_exit() {
  echo "Error occurred at: $1"
  exit 1
}

echo "Downloading MinIO..."
wget https://dl.min.io/server/minio/release/linux-amd64/minio.RELEASE.2025-09-07T16-13-09Z -O minio || error_exit "Downloading MinIO"

echo "Moving MinIO binary to /usr/local/bin/ ..."
sudo mv minio /usr/local/bin/ || error_exit "Moving MinIO binary"

echo "Setting executable permission on MinIO binary..."
sudo chmod +x /usr/local/bin/minio || error_exit "Setting executable permission"

# Default group name
default_group="minio-user"
# Prompt user
read -p "Enter group name [default: $default_group]: " GROUP_NAME

# Use default if empty
GROUP_NAME=${GROUP_NAME:-$default_group}
echo "Using group: $GROUP_NAME"
# Create group
sudo groupadd -r "$GROUP_NAME" || error_exit "Failed to create group"
echo "Creating minio-user group..."
#sudo groupadd -r minio-user || error_exit "Creating minio-user group"

# Default group name
default_user="minio-user"

# Prompt user
read -p "Enter User name [default: $default_user]: " USER_NAME
# Use default if empty
USER_NAME=${USER_NAME:-$default_user}
echo "Using username: $USER_NAME"
read -rp "Enter MINIO_ROOT_PASSWORD (default: minio123): " input_root_password
MINIO_ROOT_PASSWORD=${input_root_password:-minio123}
# Create group
#sudo groupadd -r "$USER_NAME" || error_exit "Failed to create group"
echo "Creating minio-user user..."
sudo useradd -M -r -g ${GROUP_NAME} ${USER_NAME} || error_exit "Creating minio-user user"
# Prompt for MINIO_ROOT_PASSWORD


echo "Creating data directory /mnt/data..."
sudo mkdir -p /mnt/data || error_exit "Creating data directory"

echo "Setting ownership and permissions on /mnt and /mnt/data..."
sudo chown ${USER_NAME}:${GROUP_NAME} /mnt/data || error_exit "Setting ownership on /mnt/data"
sudo chmod 777 /mnt || error_exit "Setting permissions on /mnt"
sudo chmod 777 /mnt/data || error_exit "Setting permissions on /mnt/data"

# Prompt for MINIO_ROOT_USER
#read -rp "Enter MINIO_ROOT_USER (default: $USER_NAME): " input_root_user
#MINIO_ROOT_USER=${input_root_user:-$USER_NAME}

# Prompt for MINIO_ROOT_PASSWORD
#read -rp "Enter MINIO_ROOT_PASSWORD (default: minio123): " input_root_password
#MINIO_ROOT_PASSWORD=${input_root_password:-minio123}

MACHINE_USERNAME=$(whoami)

echo "Creating MinIO environment file /etc/default/minio..."
sudo bash -c "cat > /etc/default/minio" <<EOF || error_exit "Creating environment file"
/mnt/data
MINIO_VOLUMES="/mnt/data"
MINIO_OPTS="--certs-dir /home/${MACHINE_USERNAME}/.minio/certs --console-address :9001"
MINIO_ROOT_USER=${USER_NAME}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
EOF

echo "Creating systemd service file /etc/systemd/system/minio.service..."
sudo bash -c "cat > /etc/systemd/system/minio.service" <<EOF || error_exit "Creating systemd service file"
[Unit]
Description=MinIO
Documentation=https://docs.min.io
Wants=network-online.target
After=network-online.target

[Service]
User=${USER_NAME}
Group=${GROUP_NAME}
EnvironmentFile=/etc/default/minio
ExecStart=/usr/local/bin/minio server \$MINIO_OPTS \$MINIO_VOLUMES
Restart=always
LimitNOFILE=65536
TimeoutStopSec=5

[Install]
WantedBy=multi-user.target
EOF

echo "Reloading systemd daemon..."
sudo systemctl daemon-reload || error_exit "Reloading systemd daemon"

echo "Starting MinIO service..."
sudo systemctl start minio.service || error_exit "Starting MinIO service"

echo "Checking MinIO service status..."
sudo systemctl status minio.service || error_exit "Checking MinIO service status"
