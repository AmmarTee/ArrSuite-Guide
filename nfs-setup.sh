#!/bin/bash
# NFS Storage Setup Script
# This script sets up NFS storage on a Proxmox host
#
# Usage: ./nfs-setup.sh
# Run this on your Proxmox HOST (not inside containers)

set -e

echo "=================================="
echo "NFS Storage Setup for Arr Stack"
echo "=================================="
echo ""

# Get NFS details from user
read -p "Enter your NFS server IP (e.g., 192.168.1.200): " NFS_IP
read -p "Enter NFS share path (e.g., /nfs/Proxmox): " NFS_PATH
read -p "Enter local mount point [/mnt/cold-storage]: " MOUNT_POINT
MOUNT_POINT=${MOUNT_POINT:-/mnt/cold-storage}

echo ""
echo "Configuration:"
echo "  NFS Server: $NFS_IP:$NFS_PATH"
echo "  Mount Point: $MOUNT_POINT"
echo ""
read -p "Continue? (y/n): " CONFIRM

if [ "$CONFIRM" != "y" ]; then
    echo "Aborted."
    exit 1
fi

echo ""
echo "Step 1: Installing NFS client tools..."
apt update && apt install nfs-common -y

echo ""
echo "Step 2: Creating mount point..."
mkdir -p "$MOUNT_POINT"

echo ""
echo "Step 3: Testing NFS mount..."
if mount -t nfs "$NFS_IP:$NFS_PATH" "$MOUNT_POINT"; then
    echo "✓ NFS mount successful!"
else
    echo "✗ NFS mount failed. Check your NFS server and network."
    exit 1
fi

echo ""
echo "Step 4: Adding to /etc/fstab for automatic mounting..."
# Optimized NFS mount options for qBittorrent and media workloads:
# - soft: Don't hang indefinitely on NFS issues
# - async: Better write performance
# - nolock: Disable file locking (prevents stuck file operations)
# - rsize/wsize: 128KB read/write buffer sizes
# - timeo=180: 18 second timeout
# - retrans=2: Retry twice before giving up
FSTAB_ENTRY="$NFS_IP:$NFS_PATH $MOUNT_POINT nfs soft,async,nolock,rsize=131072,wsize=131072,timeo=180,retrans=2,_netdev 0 0"

if grep -q "$NFS_IP:$NFS_PATH" /etc/fstab; then
    echo "⚠ Entry already exists in /etc/fstab"
else
    echo "$FSTAB_ENTRY" >> /etc/fstab
    echo "✓ Added to /etc/fstab"
fi

echo ""
echo "Step 5: Creating folder structure..."
mkdir -p "$MOUNT_POINT/downloads/"{complete,incomplete}
mkdir -p "$MOUNT_POINT/ready/"{movies,tv,adult}
mkdir -p "$MOUNT_POINT/torrents"

echo ""
echo "Step 6: Setting permissions..."
# SECURITY FIX: Use 755 instead of 777 (no world-writable)
# This prevents unauthorized modification of media files
chmod -R 755 "$MOUNT_POINT"
find "$MOUNT_POINT" -type d -exec chmod 755 {} \;
find "$MOUNT_POINT" -type f -exec chmod 644 {} \;

echo ""
echo "Step 7: Verifying..."
df -h | grep "$MOUNT_POINT"

echo ""
echo "=================================="
echo "✓ NFS Setup Complete!"
echo "=================================="
echo ""
echo "Folder structure created:"
echo "  $MOUNT_POINT/downloads/complete"
echo "  $MOUNT_POINT/downloads/incomplete"
echo "  $MOUNT_POINT/ready/movies"
echo "  $MOUNT_POINT/ready/tv"
echo "  $MOUNT_POINT/ready/adult"
echo "  $MOUNT_POINT/torrents"
echo ""
echo "Next steps:"
echo "  1. Install containers (Prowlarr, qBittorrent, Sonarr, etc.)"
echo "  2. Run: ct-add-storage <CTID> for each container"
echo "  3. Configure services via web UI"
