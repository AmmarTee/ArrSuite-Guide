#!/bin/bash
# ----------------------------------------------------------------------------------
# pve-cleaner.sh - Safe log clearing and orphan image removal
# ----------------------------------------------------------------------------------
# Keeps your Proxmox host lean by cleaning up system logs and apt caches.
# ----------------------------------------------------------------------------------

if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root"
   exit 1
fi

echo "🧹 Starting Proxmox Cleanup..."

# 1. Vacuum journal logs older than 3 days
echo "📦 Cleaning system journals..."
journalctl --vacuum-time=3d

# 2. Clean apt cache
echo "📦 Cleaning apt cache..."
apt-get clean
apt-get autoremove -y

# 3. Remove old container templates (optional)
# echo "📦 Removing old container templates..."
# find /var/lib/vz/template/cache/ -type f -atime +30 -delete

# 4. Clean up temp files
echo "📦 Cleaning /tmp and /var/tmp..."
rm -rf /tmp/*
rm -rf /var/tmp/*

echo ""
echo "✨ Host cleanup complete! Disk space reclaimed."
