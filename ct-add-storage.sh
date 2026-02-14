#!/bin/bash
#
# ArrSuite Container Storage Mount Script
# Bind mount host storage to LXC containers
#
# This script mounts the host's storage into LXC containers so all
# services can access the same media files.
#
# Supports multiple storage types:
#   - Local disk mounts
#   - NFS shares
#   - SMB/CIFS shares
#   - Block device volumes (cloud storage)
#
# Usage: ct-add-storage <container_id> [OPTIONS]
#   ct-add-storage 106                  # Uses config/environment.conf
#   ct-add-storage 106 --auto           # Auto-mode from config
#   ct-add-storage 106 --show-config    # Show storage configuration
#   ct-add-storage --help               # Show help
#
# Installation:
#   1. cp ct-add-storage.sh /usr/local/bin/ct-add-storage
#   2. chmod +x /usr/local/bin/ct-add-storage
#   3. ct-add-storage 106
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/environment.conf"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Default storage mount point (can be overridden by config)
STORAGE_MOUNT_POINT="/mnt/cold-storage"
STORAGE_TYPE="local"
CONTAINER_ID=""
SHOW_CONFIG=false

# ==============================================================================
# HELP & ARGUMENT PARSING
# ==============================================================================

show_help() {
    cat << EOF
ArrSuite Container Storage Mount

Usage: ct-add-storage <container_id> [OPTIONS]

Options:
  <container_id>      Container/VM ID to add storage to (required)
  --auto              Use configuration from config/environment.conf
  --mount-point PATH  Override storage mount point
  --storage-type TYPE Override storage type (local|nfs|smb)
  --show-config       Display detected storage configuration
  --help              Show this help message

Examples:
  # Basic usage (interactive)
  ct-add-storage 106

  # Using saved configuration
  ct-add-storage 106 --auto

  # Override mount point
  ct-add-storage 106 --mount-point /srv/media

  # View configuration
  ct-add-storage 106 --show-config

EOF
}

parse_arguments() {
    CONTAINER_ID="$1"
    shift || true
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --auto)
                if [ -f "$CONFIG_FILE" ]; then
                    source "$CONFIG_FILE"
                fi
                shift
                ;;
            --mount-point)
                STORAGE_MOUNT_POINT="$2"
                shift 2
                ;;
            --storage-type)
                STORAGE_TYPE="$2"
                shift 2
                ;;
            --show-config)
                SHOW_CONFIG=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Load configuration if it exists
load_configuration() {
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" || true
    fi
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

# ==============================================================================
# VALIDATION
# ==============================================================================

validate_container_id() {
    if [ -z "$CONTAINER_ID" ]; then
        print_error "Container ID is required"
        show_help
        exit 1
    fi
    
    if ! [[ "$CONTAINER_ID" =~ ^[0-9]+$ ]]; then
        print_error "Container ID must be numeric"
        exit 1
    fi
    
    if ! pct status "$CONTAINER_ID" >/dev/null 2>&1; then
        print_error "Container $CONTAINER_ID does not exist"
        echo ""
        echo "List containers with: pct list"
        exit 1
    fi
    
    print_success "Container $CONTAINER_ID exists"
}

validate_storage_path() {
    if [ ! -d "$STORAGE_MOUNT_POINT" ]; then
        print_error "Storage path does not exist: $STORAGE_MOUNT_POINT"
        exit 1
    fi
    
    # Check if readable
    if [ ! -r "$STORAGE_MOUNT_POINT" ]; then
        print_error "Storage path is not readable: $STORAGE_MOUNT_POINT"
        exit 1
    fi
    
    print_success "Storage path accessible: $STORAGE_MOUNT_POINT"
}

show_configuration() {
    echo ""
    echo -e "${BLUE}Storage Configuration:${NC}"
    echo "  Mount Point:    $STORAGE_MOUNT_POINT"
    echo "  Storage Type:   $STORAGE_TYPE"
    echo "  Container ID:   $CONTAINER_ID"
    echo ""
}

# ==============================================================================
# STORAGE MOUNT
# ==============================================================================

add_storage_mount() {
    local ct_id=$1
    local mount_point=$2
    local mount_name=${mount_point//\//_}  # Convert /mnt/media to _mnt_media
    mount_name=${mount_name#_}  # Remove leading underscore
    
    print_info "Adding storage mount to container $ct_id"
    print_info "Host path: $mount_point"
    print_info "Container path: $mount_point"
    
    # Find next available mp slot
    local mp_index=0
    while pct config "$ct_id" 2>/dev/null | grep -q "^mp$mp_index:"; do
        mp_index=$((mp_index + 1))
    done
    
    print_info "Using mount slot: mp$mp_index"
    
    # Add mount using Proxmox API
    if pct set "$ct_id" -"mp${mp_index}" "${mount_point},mp=${mount_point}" 2>/dev/null; then
        print_success "Added storage mount"
        echo "  Slot: mp${mp_index}"
        echo "  Host: $mount_point"
        echo "  Container: $mount_point"
    else
        print_error "Failed to add storage mount"
        echo ""
        echo "Manual configuration:"
        echo "  pct set $ct_id -mp${mp_index} ${mount_point},mp=${mount_point}"
        exit 1
    fi
}

verify_mount() {
    local ct_id=$1
    
    print_info "Verifying mount configuration..."
    
    if pct exec "$ct_id" -- test -d "$STORAGE_MOUNT_POINT" 2>/dev/null; then
        print_success "Mount point exists in container"
        
        # Show contents
        echo ""
        echo -e "${BLUE}Container storage contents:${NC}"
        pct exec "$ct_id" -- ls -lah "$STORAGE_MOUNT_POINT" 2>/dev/null || true
    else
        echo -e "${YELLOW}⚠ Mount point not yet visible in container${NC}"
        echo "This is normal - the container may need a restart:"
        echo "  pct reboot $ct_id"
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    # Verify running as root
    if [[ $EUID -ne 0 ]]; then
        print_error "This script must be run as root"
        exit 1
    fi
    
    # Verify running on Proxmox
    if ! command -v pct &> /dev/null; then
        print_error "Proxmox tools (pct) not found. This script requires Proxmox."
        exit 1
    fi
    
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║      ArrSuite Container Storage Manager                    ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    # Parse arguments
    parse_arguments "$@"
    
    # Load configuration
    load_configuration
    
    # Show config if requested
    if [ "$SHOW_CONFIG" = "true" ]; then
        show_configuration
        exit 0
    fi
    
    # Validate inputs
    if [ -z "$CONTAINER_ID" ]; then
        print_error "Container ID is required"
        show_help
        exit 1
    fi
    
    validate_container_id
    validate_storage_path
    
    echo ""
    show_configuration
    
    # Add storage mount
    add_storage_mount "$CONTAINER_ID" "$STORAGE_MOUNT_POINT"
    
    # Verify
    echo ""
    verify_mount "$CONTAINER_ID"
    
    echo ""
    print_success "Storage mount configuration complete!"
    echo ""
    echo "Next steps:"
    echo "  1. Reboot the container: pct reboot $CONTAINER_ID"
    echo "  2. Verify mount: pct enter $CONTAINER_ID"
    echo "     Inside container: ls -lah $STORAGE_MOUNT_POINT"
    echo ""
}

main "$@"
