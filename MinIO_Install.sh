#!/bin/bash

# Exit immediately if any command exits with a non-zero status
set -e

echo "Starting MinIO setup..."

# 1. Download and Install MinIO
echo "Downloading MinIO..."
wget https://dl.min.io/server/minio/release/linux-amd64/minio.RELEASE.2025-09-07T16-13-09Z -O minio

echo "Moving MinIO binary to /usr/local/bin/..."
sudo mv minio /usr/local/bin/

echo "Making MinIO binary executable..."
sudo chmod +x /usr/local/bin/minio

# 2. Create MinIO User, Group, and Directories
echo "Creating minio-user group..."
sudo groupadd -r minio-user

echo "Creating minio-user system user..."
sudo useradd -M -r -g minio-user minio-user

echo "Creating data directory..."
sudo mkdir -p /mnt/data

echo "Setting directory ownership and permissions..."
sudo chown minio-user:minio-user /mnt/data
sudo chmod 777 /mnt
sudo chmod 777 /mnt/data

echo "MinIO setup completed successfully!"
