#!/bin/bash
# ----------------------------------------------------------------------------------
# nfs-watchdog.sh - Checks mount health and force remounts on stale handles
# ----------------------------------------------------------------------------------
# Recommended Cron: * * * * * /path/to/nfs-watchdog.sh >> /var/log/nfs-watchdog.log 2>&1
# ----------------------------------------------------------------------------------

MOUNT_PATH="/mnt/cold-storage"
NFS_SERVER="192.168.1.200" # Replace with your NAS IP

# Check if the mount point is reachable
if ! timeout 5 ls "$MOUNT_PATH" >/dev/null 2>&1; then
    echo "$(date): 🚨 NFS mount stale or unreachable. Attempting force remount..."
    
    # Force unmount
    umount -l "$MOUNT_PATH"
    
    # Try to remount everything in fstab
    mount -a
    
    if [ $? -eq 0 ]; then
        echo "$(date): ✅ Remount successful."
    else
        echo "$(date): ❌ Remount failed! NAS might be down."
    fi
else
    # Optional: Log success
    # echo "$(date): ✅ NFS mount healthy."
    exit 0
fi
