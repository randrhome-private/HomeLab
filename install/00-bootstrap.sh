#!/bin/bash
set -e

echo "[*] Updating system..."
apt update && apt upgrade -y

echo "[*] Installing core tools..."
apt install -y curl git sudo lsb-release ca-certificates gnupg parted -y

echo "[*] Mounting and formatting /dev/sdb as ext4..."

# Check if /dev/sdb is already formatted
if ! blkid /dev/sdb; then
  echo "[*] Formatting /dev/sdb as ext4..."
  mkfs.ext4 /dev/sdb
fi

mkdir -p /mnt/data

# Add to fstab if not already present
grep -q "/mnt/data" /etc/fstab || echo "/dev/sdb /mnt/data ext4 defaults 0 2" >> /etc/fstab

# Mount now
mount /mnt/data

echo "[*] Creating base application directories under /mnt/data..."
mkdir -p /mnt/data/{nextcloud/files,immich/uploads,immich/thumbs,media,backup}

echo "[✓] Disk ready and directories initialized."
