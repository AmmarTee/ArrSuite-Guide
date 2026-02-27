#!/bin/bash
#
# ArrSuite Universal Storage Setup Script
# Supports: Local Disk, NFS, SMB/CIFS
#
# This script replaces the old NFS-only setup with a universal storage solution
# that works for OVH (local), homelab (NFS), and other environments (SMB).
#
# Usage: bash storage-setup.sh [OPTIONS]
#   --auto              Use values from config/environment.conf
#   --type local|nfs|smb  Force storage type
#   --mount-point PATH  Override mount point
#   --nfs-server IP     NFS server IP
#   --help              Show this help
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source detection library
source "$SCRIPT_DIR/lib/detect-env.sh"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default values
AUTO_MODE=false
SKIP_CONFIRMATION=false
CONFIG_FILE="$SCRIPT_DIR/config/environment.conf"

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║          ArrSuite Universal Storage Setup                   ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-y}
    
    local response
    if [ "$SKIP_CONFIRMATION" = "true" ]; then
        return 0
    fi
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt (Y/n): " response
            response=${response:-y}
        else
            read -p "$prompt (y/N): " response
            response=${response:-n}
        fi
        
        if [[ $response =~ ^[Yy]$ ]]; then
            return 0
        elif [[ $response =~ ^[Nn]$ ]]; then
            return 1
        fi
    done
}

show_help() {
    cat << EOF
ArrSuite Universal Storage Setup

Usage: bash storage-setup.sh [OPTIONS]

Options:
  --auto              Use configuration from config/environment.conf
  --type <type>       Storage type: local, nfs, smb
  --mount-point <path> Override default mount point
  --nfs-server <ip>   NFS server IP address
  --nfs-path <path>   NFS export path
  --smb-server <addr> SMB server address
  --smb-share <name>  SMB share name
  --skip-confirm      Skip confirmation prompts
  --help              Show this help message

Examples:
  # Interactive mode
  bash storage-setup.sh

  # Auto mode from config
  bash storage-setup.sh --auto

  # Local storage at custom path
  bash storage-setup.sh --type local --mount-point /srv/media

  # NFS from homelab NAS
  bash storage-setup.sh --type nfs --nfs-server 192.168.1.200 \\
    --nfs-path /exports/media

EOF
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                AUTO_MODE=true
                SKIP_CONFIRMATION=true
                shift
                ;;
            --type)
                STORAGE_TYPE="$2"
                shift 2
                ;;
            --mount-point)
                STORAGE_MOUNT_POINT="$2"
                shift 2
                ;;
            --nfs-server)
                NFS_SERVER_IP="$2"
                shift 2
                ;;
            --nfs-path)
                NFS_EXPORT_PATH="$2"
                shift 2
                ;;
            --smb-server)
                SMB_SERVER="$2"
                shift 2
                ;;
            --smb-share)
                SMB_SHARE="$2"
                shift 2
                ;;
            --skip-confirm)
                SKIP_CONFIRMATION=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                print_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

check_requirements() {
    print_info "Checking requirements..."
    
    # Check if running on Proxmox host or Linux system
    if ! command -v mount &> /dev/null; then
        print_error "mount command not found. This script requires Linux."
        exit 1
    fi
    
    # Check sudo privileges if needed
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    print_success "Requirements met"
}

# ==============================================================================
# STORAGE TYPE DETECTION & SELECTION
# ==============================================================================

select_storage_type() {
    if [ -n "${STORAGE_TYPE:-}" ]; then
        print_info "Using storage type: $STORAGE_TYPE"
        return
    fi
    
    # Try to detect from config
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" || true
    fi
    
    if [ -z "${STORAGE_TYPE:-}" ]; then
        STORAGE_TYPE=$(detect_storage_type)
    fi
    
    if [ "$STORAGE_TYPE" = "unknown" ] || [ -z "$STORAGE_TYPE" ]; then
        echo ""
        echo "Select storage type:"
        echo "  1) Local Disk (OVH, VPS)"
        echo "  2) NFS Share (Homelab with NAS)"
        echo "  3) SMB/CIFS Share (Windows network)"
        
        read -p "Select (1-3): " selection
        case $selection in
            1) STORAGE_TYPE="local" ;;
            2) STORAGE_TYPE="nfs" ;;
            3) STORAGE_TYPE="smb" ;;
            *) 
                print_error "Invalid selection"
                exit 1
                ;;
        esac
    fi
    
    print_success "Storage type: $STORAGE_TYPE"
}

# ==============================================================================
# LOCAL STORAGE SETUP
# ==============================================================================

setup_local_storage() {
    local mount_point="${STORAGE_MOUNT_POINT:-/srv/media}"
    
    print_info "Setting up local storage"
    echo ""
    echo "Local storage options:"
    echo "  1) Use existing directory ($mount_point)"
    echo "  2) Format and mount a block device"
    echo "  3) Use different mount point"
    
    read -p "Select (1-3): " selection
    
    case $selection in
        1)
            setup_local_directory "$mount_point"
            ;;
        2)
            setup_local_block_device
            ;;
        3)
            mount_point=$(ask_input "Mount point" "/srv/media")
            setup_local_directory "$mount_point"
            ;;
        *)
            print_error "Invalid selection"
            exit 1
            ;;
    esac
}

ask_input() {
    local prompt=$1
    local default=${2:-}
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

setup_local_directory() {
    local mount_point=$1
    
    print_info "Setting up directory: $mount_point"
    
    # Create directory
    if [ ! -d "$mount_point" ]; then
        print_warning "Creating directory: $mount_point"
        mkdir -p "$mount_point" || {
            print_error "Failed to create directory"
            exit 1
        }
    fi
    
    # Create media folders
    print_info "Creating media folders..."
    mkdir -p "$mount_point"/{downloads,incomplete,tv,movies,music,books,other,config}
    
    # Set permissions (secure: not 777!)
    print_info "Setting permissions (755)..."
    chmod 755 "$mount_point"
    find "$mount_point" -type d -exec chmod 755 {} \;
    find "$mount_point" -type f -exec chmod 644 {} \;
    
    # Verify
    if [ -d "$mount_point" ]; then
        print_success "Local storage ready at: $mount_point"
        echo ""
        ls -lah "$mount_point"
        STORAGE_MOUNT_POINT="$mount_point"
    else
        print_error "Local storage setup failed"
        exit 1
    fi
}

setup_local_block_device() {
    echo ""
    echo "Available block devices:"
    lsblk -d -n -o NAME,SIZE,TYPE | grep -v "^loop" || true
    
    local device=$(ask_input "Block device to format (e.g., sdb, vdb)" "")
    
    if [ -z "$device" ]; then
        print_error "No device specified"
        return 1
    fi
    
    # Normalize device path
    if [[ ! "$device" =~ ^/ ]]; then
        device="/dev/$device"
    fi
    
    # Verify device exists
    if [ ! -e "$device" ]; then
        print_error "Device not found: $device"
        return 1
    fi
    
    print_warning "⚠️  WARNING: This will format $device and all data will be lost!"
    if ! ask_yes_no "Continue with formatting?" "n"; then
        print_warning "Cancelled"
        return 1
    fi
    
    # Format device
    print_info "Formatting $device as ext4..."
    mkfs.ext4 -F "$device" || {
        print_error "Format failed"
        return 1
    }
    
    # Mount
    local mount_point="/mnt/media"
    mkdir -p "$mount_point"
    
    print_info "Mounting to $mount_point..."
    mount "$device" "$mount_point" || {
        print_error "Mount failed"
        return 1
    }
    
    # Add to fstab for persistence
    print_info "Adding to /etc/fstab..."
    echo "$device $mount_point ext4 defaults,nofail 0 2" >> /etc/fstab
    
    # Create folders
    mkdir -p "$mount_point"/{downloads,incomplete,tv,movies,music,books,other}
    chmod 755 "$mount_point"
    
    print_success "Block device formatted and mounted: $mount_point"
    STORAGE_MOUNT_POINT="$mount_point"
}

# ==============================================================================
# NFS STORAGE SETUP
# ==============================================================================

setup_nfs_storage() {
    local nfs_server="${NFS_SERVER_IP:-}"
    local nfs_path="${NFS_EXPORT_PATH:-/exports/media}"
    local mount_point="${STORAGE_MOUNT_POINT:-/mnt/cold-storage}"
    
    print_info "Setting up NFS storage"
    echo ""
    
    # If not provided, ask
    if [ -z "$nfs_server" ]; then
        nfs_server=$(ask_input "NFS server IP address")
    fi
    
    if [ -z "$nfs_path" ]; then
        nfs_path=$(ask_input "NFS export path" "/exports/media")
    fi
    
    # Validate IP
    if ! [[ $nfs_server =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_error "Invalid IP address: $nfs_server"
        exit 1
    fi
    
    # Check if nfs-common is installed
    print_info "Checking NFS client tools..."
    if ! command -v mount.nfs &> /dev/null; then
        print_warning "nfs-common not installed. Installing..."
        apt-get update && apt-get install -y nfs-common || {
            print_error "Failed to install nfs-common"
            exit 1
        }
    fi
    
    print_success "NFS tools available"
    
    # Test NFS connectivity
    print_info "Testing NFS server connectivity..."
    if timeout 5 ping -c 1 "$nfs_server" &> /dev/null; then
        print_success "NFS server reachable: $nfs_server"
    else
        print_warning "Cannot reach NFS server: $nfs_server"
        if ! ask_yes_no "Continue anyway?" "n"; then
            exit 1
        fi
    fi
    
    # Show available exports
    print_info "NFS exports on $nfs_server:"
    if command -v showmount &> /dev/null; then
        timeout 5 showmount -e "$nfs_server" 2>/dev/null || true
    fi
    
    # Create and mount
    mkdir -p "$mount_point"
    
    print_info "Mounting NFS: $nfs_server:$nfs_path to $mount_point"
    
    # Try to mount
    if ! mount -t nfs4 -o vers=4,soft,timeo=180 "$nfs_server:$nfs_path" "$mount_point" 2>/dev/null; then
        # Try NFS version 3
        print_warning "NFS v4 failed, trying NFS v3..."
        mount -t nfs -o vers=3,soft,timeo=180 "$nfs_server:$nfs_path" "$mount_point" || {
            print_error "NFS mount failed"
            exit 1
        }
    fi
    
    print_success "NFS mounted successfully"
    
    # Verify mount
    mount | grep "$mount_point"
    
    # Create media folders
    mkdir -p "$mount_point"/{downloads,incomplete,tv,movies,music,books,other}
    chmod 755 "$mount_point"
    
    # Add to fstab with optimized options for qBittorrent
    print_info "Adding to /etc/fstab for persistence..."
    if ! grep -q "$nfs_server:$nfs_path" /etc/fstab; then
        echo "$nfs_server:$nfs_path $mount_point nfs soft,async,nolock,rsize=131072,wsize=131072,timeo=180,retrans=2,_netdev 0 0" >> /etc/fstab
        print_success "Added to /etc/fstab"
    fi
    
    STORAGE_MOUNT_POINT="$mount_point"
}

# ==============================================================================
# SMB/CIFS STORAGE SETUP
# ==============================================================================

setup_smb_storage() {
    local smb_server="${SMB_SERVER:-}"
    local smb_share="${SMB_SHARE:-media}"
    local mount_point="${STORAGE_MOUNT_POINT:-/mnt/smb-storage}"
    
    print_info "Setting up SMB/CIFS storage"
    echo ""
    
    if [ -z "$smb_server" ]; then
        smb_server=$(ask_input "SMB server address (IP or hostname)")
    fi
    
    if [ -z "$smb_share" ]; then
        smb_share=$(ask_input "SMB share name" "media")
    fi
    
    # Create mount point
    mkdir -p "$mount_point"
    
    # Check if cifs-utils is installed
    print_info "Checking CIFS tools..."
    if ! command -v mount.cifs &> /dev/null; then
        print_warning "cifs-utils not installed. Installing..."
        apt-get update && apt-get install -y cifs-utils || {
            print_error "Failed to install cifs-utils"
            exit 1
        }
    fi
    
    print_success "CIFS tools available"
    
    # Get credentials
    local username=$(ask_input "SMB username (optional)" "guest")
    local password
    
    if [ "$username" != "guest" ]; then
        read -sp "SMB password: " password
        echo ""
    fi
    
    # Create credentials file
    local creds_file="/etc/samba/cifs-credentials"
    mkdir -p /etc/samba
    
    cat > "$creds_file" << EOF
username=$username
password=${password:-}
EOF
    chmod 600 "$creds_file"
    
    # Mount
    print_info "Mounting SMB share: //$smb_server/$smb_share to $mount_point"
    
    if [ "$username" = "guest" ]; then
        mount -t cifs -o guest,uid=1000,gid=1000,file_mode=0755,dir_mode=0755 \
            "//$smb_server/$smb_share" "$mount_point" || {
            print_error "SMB mount failed"
            exit 1
        }
    else
        mount -t cifs -o credentials="$creds_file",uid=1000,gid=1000,file_mode=0755,dir_mode=0755 \
            "//$smb_server/$smb_share" "$mount_point" || {
            print_error "SMB mount failed"
            rm -f "$creds_file"
            exit 1
        }
    fi
    
    print_success "SMB mounted successfully"
    
    # Verify
    mount | grep "$mount_point"
    
    # Create folders
    mkdir -p "$mount_point"/{downloads,incomplete,tv,movies,music,books,other}
    
    # Add to fstab
    print_info "Adding to /etc/fstab..."
    if [ "$username" = "guest" ]; then
        echo "//$smb_server/$smb_share $mount_point cifs guest,uid=1000,gid=1000,file_mode=0755,dir_mode=0755,_netdev 0 0" >> /etc/fstab
    else
        echo "//$smb_server/$smb_share $mount_point cifs credentials=$creds_file,uid=1000,gid=1000,file_mode=0755,dir_mode=0755,_netdev 0 0" >> /etc/fstab
    fi
    
    STORAGE_MOUNT_POINT="$mount_point"
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    print_header
    
    # Parse arguments
    parse_arguments "$@"
    
    # Check requirements
    check_requirements
    
    # Load config if auto mode
    if [ "$AUTO_MODE" = "true" ]; then
        print_info "Loading configuration from: $CONFIG_FILE"
        if [ -f "$CONFIG_FILE" ]; then
            source "$CONFIG_FILE" || true
        else
            print_error "Configuration file not found: $CONFIG_FILE"
            print_info "Run: bash environment-setup.sh"
            exit 1
        fi
    fi
    
    # Select storage type
    select_storage_type
    
    echo ""
    echo -e "${BLUE}═════════════════════════════════════════════════════════════${NC}"
    
    # Setup storage based on type
    case "$STORAGE_TYPE" in
        local)
            setup_local_storage
            ;;
        nfs)
            setup_nfs_storage
            ;;
        smb)
            setup_smb_storage
            ;;
        *)
            print_error "Unsupported storage type: $STORAGE_TYPE"
            exit 1
            ;;
    esac
    
    # Summary
    echo ""
    echo ""
    print_success "Storage setup completed!"
    echo ""
    echo -e "${BLUE}Summary:${NC}"
    echo "  Type:        $STORAGE_TYPE"
    echo "  Mount point: $STORAGE_MOUNT_POINT"
    echo ""
    echo "Storage is ready for container mounting:"
    echo "  bash ct-add-storage.sh <CONTAINER_ID>"
    echo ""
}

main "$@"
