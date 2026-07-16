#!/bin/bash

set -e

error_exit() {
  echo "Error: $1"
  exit 1
}

echo "=== MinIO Idempotent Setup Script ==="

# -------------------------
# PROMPTS
# -------------------------
read -p "Enter group name [default: minio-user]: " GROUP_NAME
GROUP_NAME=${GROUP_NAME:-minio-user}

read -p "Enter user name [default: minio-user]: " USER_NAME
USER_NAME=${USER_NAME:-minio-user}

read -rp "Enter MINIO_ROOT_PASSWORD (default: minio123): " input_root_password
MINIO_ROOT_PASSWORD=${input_root_password:-minio123}

MACHINE_USERNAME=$(whoami)

echo "Using:"
echo "  User  : $USER_NAME"
echo "  Group : $GROUP_NAME"

# -------------------------
# CHECK MINIO INSTALLATION
# -------------------------
if command -v minio >/dev/null 2>&1; then
  echo "MinIO binary already installed."
else
  echo "Installing MinIO..."
  wget https://dl.min.io/server/minio/release/linux-amd64/minio.RELEASE.2025-09-07T16-13-09Z -O minio || error_exit "Downloading MinIO"
  sudo mv minio /usr/local/bin/ || error_exit "Moving MinIO binary"
  sudo chmod +x /usr/local/bin/minio || error_exit "Setting executable permission"
fi

# -------------------------
# GROUP CHECK
# -------------------------
if getent group "$GROUP_NAME" >/dev/null 2>&1; then
  echo "Group '$GROUP_NAME' already exists."
else
  echo "Creating group '$GROUP_NAME'..."
  sudo groupadd -r "$GROUP_NAME" || error_exit "Creating group"
fi

# -------------------------
# USER CHECK
# -------------------------
if id "$USER_NAME" >/dev/null 2>&1; then
  echo "User '$USER_NAME' already exists."
else
  echo "Creating user '$USER_NAME'..."
  sudo useradd -M -r -g "$GROUP_NAME" "$USER_NAME" || error_exit "Creating user"
fi

# -------------------------
# DATA DIRECTORY
# -------------------------
if [ -d "/mnt/data" ]; then
  echo "/mnt/data already exists."
else
  echo "Creating /mnt/data..."
  sudo mkdir -p /mnt/data || error_exit "Creating data directory"
fi

echo "Setting ownership and permissions..."
sudo chown "$USER_NAME:$GROUP_NAME" /mnt/data || error_exit "Setting ownership"
sudo chmod 755 /mnt/data || error_exit "Setting permissions"

# -------------------------
# ENV FILE
# -------------------------
echo "Configuring /etc/default/minio..."
sudo bash -c "cat > /etc/default/minio" <<EOF
MINIO_VOLUMES="/mnt/data"
MINIO_OPTS="--certs-dir /home/${MACHINE_USERNAME}/.minio/certs --console-address :9001"
MINIO_ROOT_USER=${USER_NAME}
MINIO_ROOT_PASSWORD=${MINIO_ROOT_PASSWORD}
EOF

# -------------------------
# SYSTEMD SERVICE
# -------------------------
if [ -f "/etc/systemd/system/minio.service" ]; then
  echo "MinIO service file already exists."
else
  echo "Creating MinIO systemd service..."
  sudo bash -c "cat > /etc/systemd/system/minio.service" <<EOF
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

  sudo systemctl daemon-reload || error_exit "Reloading systemd"
fi

# -------------------------
# ENABLE + START SERVICE
# -------------------------
if systemctl is-enabled minio.service >/dev/null 2>&1; then
  echo "MinIO service already enabled."
else
  echo "Enabling MinIO service..."
  sudo systemctl enable minio.service || error_exit "Enabling service"
fi

if systemctl is-active minio.service >/dev/null 2>&1; then
  echo "MinIO service already running."
else
  echo "Starting MinIO service..."
  sudo systemctl start minio.service || error_exit "Starting service"
fi

# -------------------------
# FINAL STATUS
# -------------------------
echo "===================================="
echo "MinIO setup complete."
echo "User  : $USER_NAME"
echo "Group : $GROUP_NAME"
echo "===================================="

sudo systemctl status minio.service
