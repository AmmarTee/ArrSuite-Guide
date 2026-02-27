#!/bin/bash
#
# ArrSuite Environment Setup Script
#
# This script auto-detects your deployment environment and creates a
# configuration file (environment.conf) with appropriate settings.
#
# Usage: bash environment-setup.sh
#

set -e

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source detection library
if [ ! -f "$SCRIPT_DIR/lib/detect-env.sh" ]; then
    echo "❌ Error: lib/detect-env.sh not found!"
    echo "Make sure you're running this from the ArrSuite-Guide root directory."
    exit 1
fi

source "$SCRIPT_DIR/lib/detect-env.sh"

# Configuration file location
CONFIG_DIR="$SCRIPT_DIR/config"
CONFIG_FILE="$SCRIPT_DIR/config/environment.conf"

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

print_header() {
    clear
    echo -e "${BLUE}"
    echo "╔════════════════════════════════════════════════════════════════╗"
    echo "║           ArrSuite Environment Setup & Configuration           ║"
    echo "║                    Version 1.0 - OVH Edition                   ║"
    echo "╚════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
}

print_section() {
    echo ""
    echo -e "${CYAN}▶ $1${NC}"
    echo -e "${CYAN}$(printf '─%.0s' {1..60})${NC}"
}

ask_yes_no() {
    local prompt=$1
    local default=${2:-y}
    local response
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt (Y/n): " -r response
            response=${response:-y}
        else
            read -p "$prompt (y/N): " -r response
            response=${response:-n}
        fi
        
        if [[ $response =~ ^[Yy]$ ]]; then
            return 0
        elif [[ $response =~ ^[Nn]$ ]]; then
            return 1
        fi
        echo "Please answer y or n."
    done
}

ask_choice() {
    local prompt=$1
    shift
    local options=("$@")
    local choice
    
    echo ""
    echo -e "${YELLOW}$prompt${NC}"
    for i in {0..$(( ${#options[@]} - 1 ))}; do
        echo "  $((i + 1))) ${options[$i]}"
    done
    
    while true; do
        read -p "Select (1-${#options[@]}): " choice
        if [[ $choice =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le ${#options[@]} ]; then
            echo "${options[$((choice - 1))]}"
            return 0
        fi
        echo "Invalid choice. Please select between 1 and ${#options[@]}."
    done
}

ask_input() {
    local prompt=$1
    local default=${2:-}
    local input
    
    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " input
        echo "${input:-$default}"
    else
        read -p "$prompt: " input
        echo "$input"
    fi
}

validate_ip() {
    local ip=$1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    return 1
}

# ==============================================================================
# DETECTION & WELCOME
# ==============================================================================

print_header

echo -e "${GREEN}🔍 Detecting your environment...${NC}"
echo ""

# Run detection
print_detection_summary

read -p "Press Enter to continue..."

# ==============================================================================
# ENVIRONMENT PROVIDER SELECTION
# ==============================================================================

print_section "1. DEPLOYMENT ENVIRONMENT"

echo ""
echo -e "${YELLOW}We detected: ${GREEN}${DETECTED_PROVIDER}${NC}"
echo ""

if ask_yes_no "Is this correct?" "y"; then
    SELECTED_PROVIDER="$DETECTED_PROVIDER"
else
    echo ""
    SELECTED_PROVIDER=$(ask_choice "Select your deployment environment:" \
        "OVH Dedicated Server (Static IP)" \
        "Homelab with DHCP & NAS" \
        "Hetzner Dedicated (Routed)" \
        "Generic VPS (Local Storage)" \
        "DigitalOcean (Cloud VPC)")
    
    case "$SELECTED_PROVIDER" in
        *OVH*) SELECTED_PROVIDER="ovh" ;;
        *Homelab*) SELECTED_PROVIDER="homelab" ;;
        *Hetzner*) SELECTED_PROVIDER="hetzner" ;;
        *Generic*) SELECTED_PROVIDER="generic" ;;
        *DigitalOcean*) SELECTED_PROVIDER="digitalocean" ;;
    esac
fi

echo -e "${GREEN}✓ Selected: $SELECTED_PROVIDER${NC}"

# ==============================================================================
# LOAD BASE PROFILE
# ==============================================================================

print_section "2. CONFIGURATION PROFILE"

case "$SELECTED_PROVIDER" in
    ovh)
        echo "Using OVH Static IP configuration..."
        if [ -f "$CONFIG_DIR/ovh-static.conf" ]; then
            source "$CONFIG_DIR/ovh-static.conf"
            echo -e "${GREEN}✓ Loaded ovh-static.conf${NC}"
        fi
        ;;
    homelab)
        echo "Using Homelab DHCP configuration..."
        if [ -f "$CONFIG_DIR/homelab-dhcp.conf" ]; then
            source "$CONFIG_DIR/homelab-dhcp.conf"
            echo -e "${GREEN}✓ Loaded homelab-dhcp.conf${NC}"
        fi
        ;;
    *)
        echo "Using default configuration..."
        if [ -f "$CONFIG_DIR/environment.conf.example" ]; then
            source "$CONFIG_DIR/environment.conf.example"
            echo -e "${GREEN}✓ Loaded environment.conf.example${NC}"
        fi
        ;;
esac

# ==============================================================================
# NETWORK CONFIGURATION
# ==============================================================================

print_section "3. NETWORK CONFIGURATION"

echo ""
echo "Current Network Setup:"
echo "  Primary IP:    $DETECTED_PRIMARY_IP"
echo "  Gateway:       $DETECTED_GATEWAY"
echo "  Subnet:        $DETECTED_SUBNET"
echo "  Network Mode:  $DETECTED_NETWORK_MODE"
echo ""

if ask_yes_no "Are these network settings correct?" "y"; then
    FINAL_PRIMARY_IP="$DETECTED_PRIMARY_IP"
    FINAL_GATEWAY="$DETECTED_GATEWAY"
    FINAL_SUBNET="$DETECTED_SUBNET"
    FINAL_NETWORK_MODE="$DETECTED_NETWORK_MODE"
else
    echo ""
    echo "Enter your network configuration:"
    FINAL_PRIMARY_IP=$(ask_input "Primary IP address" "$DETECTED_PRIMARY_IP")
    FINAL_GATEWAY=$(ask_input "Gateway IP" "$DETECTED_GATEWAY")
    FINAL_SUBNET=$(ask_input "Subnet (CIDR notation)" "$DETECTED_SUBNET")
fi

# Provider-specific network setup
case "$SELECTED_PROVIDER" in
    ovh)
        echo ""
        echo -e "${YELLOW}OVH Static IP Configuration:${NC}"
        OVH_MAC=$(ask_input "MAC address for static IP (optional)" "")
        OVH_VLAN=$(ask_input "VLAN ID (if using vRack, optional)" "")
        
        # Container IP range for OVH
        CONTAINER_FIRST_IP=$(ask_input "First container IP (within your subnet)" "")
        if ! validate_ip "$CONTAINER_FIRST_IP"; then
            echo -e "${RED}✗ Invalid IP address${NC}"
            exit 1
        fi
        ;;
esac

# ==============================================================================
# STORAGE CONFIGURATION
# ==============================================================================

print_section "4. STORAGE CONFIGURATION"

echo ""
echo "Available storage types:"
echo "  1) Local Disk (OVH, most VPS)"
echo "  2) NFS Share (Homelab with NAS)"
echo "  3) SMB/CIFS (Windows network share)"
echo ""

STORAGE_SELECTION=$(ask_choice "Select storage type:" \
    "Local Disk (/dev/sdb or /srv/media)" \
    "NFS Network Share" \
    "SMB/CIFS Network Share")

case "$STORAGE_SELECTION" in
    *Local*)
        FINAL_STORAGE_TYPE="local"
        FINAL_STORAGE_PATH=$(ask_input "Local storage mount point" "/srv/media")
        echo -e "${GREEN}✓ Local storage: $FINAL_STORAGE_PATH${NC}"
        ;;
    *NFS*)
        FINAL_STORAGE_TYPE="nfs"
        NFS_IP=$(ask_input "NAS/NFS server IP address" "")
        NFS_PATH=$(ask_input "NFS export path" "/exports/media")
        FINAL_STORAGE_PATH="/mnt/cold-storage"
        echo -e "${GREEN}✓ NFS storage: $NFS_IP:$NFS_PATH${NC}"
        ;;
    *SMB*)
        FINAL_STORAGE_TYPE="smb"
        SMB_SERVER=$(ask_input "SMB server address" "")
        SMB_SHARE=$(ask_input "SMB share name" "media")
        SMB_USER=$(ask_input "SMB username" "")
        SMB_PASS=$(ask_input "SMB password" "")
        FINAL_STORAGE_PATH="/mnt/smb-storage"
        echo -e "${GREEN}✓ SMB storage: //$SMB_SERVER/$SMB_SHARE${NC}"
        ;;
esac

# ==============================================================================
# PROXMOX CONFIGURATION
# ==============================================================================

print_section "5. PROXMOX CONFIGURATION"

echo ""
echo "Container allocation settings:"

CONTAINER_BASE=$(ask_input "Base container ID (first container will use this)" "100")
CONTAINER_CPU=$(ask_input "CPU cores per container" "2")
CONTAINER_RAM=$(ask_input "RAM per container (MB)" "2048")
CONTAINER_DISK=$(ask_input "Disk size per container (GB)" "30")

echo -e "${GREEN}✓ Containers 100-120 will be available${NC}"

# ==============================================================================
# VALIDATION
# ==============================================================================

print_section "6. VALIDATION & TESTING"

echo ""
echo "Running connectivity tests..."

# Test gateway
echo -n "  Testing gateway reachability... "
if test_gateway_reachability; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (Warning: gateway unreachable)${NC}"
fi

# Test internet
echo -n "  Testing internet connectivity... "
if has_internet_connectivity; then
    echo -e "${GREEN}✓${NC}"
else
    echo -e "${RED}✗ (Warning: internet unreachable)${NC}"
fi

# Test storage path (if local)
if [ "$FINAL_STORAGE_TYPE" = "local" ]; then
    echo -n "  Testing storage path... "
    if [ -d "${FINAL_STORAGE_PATH%/*}" ]; then
        echo -e "${GREEN}✓${NC}"
    else
        echo -e "${YELLOW}⚠ Storage path parent directory doesn't exist (will be created)${NC}"
    fi
fi

# ==============================================================================
# SUMMARY & CONFIRMATION
# ==============================================================================

print_section "7. CONFIGURATION SUMMARY"

echo ""
echo -e "${CYAN}Deployment Configuration:${NC}"
echo "  Provider:        $SELECTED_PROVIDER"
echo "  Network Mode:    $FINAL_NETWORK_MODE"
echo "  Primary IP:      $FINAL_PRIMARY_IP"
echo "  Gateway:         $FINAL_GATEWAY"
echo "  Subnet:          $FINAL_SUBNET"
echo ""
echo -e "${CYAN}Storage Configuration:${NC}"
echo "  Storage Type:    $FINAL_STORAGE_TYPE"
echo "  Mount Point:     $FINAL_STORAGE_PATH"
if [ "$FINAL_STORAGE_TYPE" = "nfs" ]; then
    echo "  NFS Server:      $NFS_IP"
    echo "  NFS Path:        $NFS_PATH"
fi
echo ""
echo -e "${CYAN}Proxmox Configuration:${NC}"
echo "  Base Container ID: $CONTAINER_BASE"
echo "  CPU per Container: $CONTAINER_CPU cores"
echo "  RAM per Container: $CONTAINER_RAM MB"
echo "  Disk per Container: $CONTAINER_DISK GB"
echo ""

if ! ask_yes_no "Save this configuration?" "y"; then
    echo -e "${YELLOW}Configuration not saved. Exiting.${NC}"
    exit 0
fi

# ==============================================================================
# GENERATE CONFIGURATION FILE
# ==============================================================================

print_section "8. SAVING CONFIGURATION"

# Create configuration file
cat > "$CONFIG_FILE" << 'EOF'
# =============================================================================
# ArrSuite Generated Environment Configuration
# =============================================================================
# Auto-generated by environment-setup.sh
# DO NOT MANUALLY EDIT - run environment-setup.sh to reconfigure
#

EOF

# Add provider
echo "" >> "$CONFIG_FILE"
echo "# Auto-Detected Provider" >> "$CONFIG_FILE"
echo "DETECTED_PROVIDER=\"$SELECTED_PROVIDER\"" >> "$CONFIG_FILE"
echo "NETWORK_MODE=\"$FINAL_NETWORK_MODE\"" >> "$CONFIG_FILE"

# Add network config
echo "" >> "$CONFIG_FILE"
echo "# Network Configuration" >> "$CONFIG_FILE"
echo "NETWORK_INTERFACE=\"eth0\"" >> "$CONFIG_FILE"
echo "NETWORK_TYPE=\"$FINAL_NETWORK_MODE\"" >> "$CONFIG_FILE"
echo "PRIMARY_IP=\"$FINAL_PRIMARY_IP\"" >> "$CONFIG_FILE"
echo "GATEWAY_IP=\"$FINAL_GATEWAY\"" >> "$CONFIG_FILE"
echo "SUBNET_RANGE=\"$FINAL_SUBNET\"" >> "$CONFIG_FILE"
echo "BRIDGE_NAME=\"vmbr0\"" >> "$CONFIG_FILE"

if [ "$SELECTED_PROVIDER" = "ovh" ] && [ -n "$CONTAINER_FIRST_IP" ]; then
    echo "CONTAINER_IP_START=\"$CONTAINER_FIRST_IP\"" >> "$CONFIG_FILE"
fi

# Add storage config
echo "" >> "$CONFIG_FILE"
echo "# Storage Configuration" >> "$CONFIG_FILE"
echo "STORAGE_TYPE=\"$FINAL_STORAGE_TYPE\"" >> "$CONFIG_FILE"
echo "STORAGE_MOUNT_POINT=\"$FINAL_STORAGE_PATH\"" >> "$CONFIG_FILE"

if [ "$FINAL_STORAGE_TYPE" = "nfs" ]; then
    echo "NFS_SERVER_IP=\"$NFS_IP\"" >> "$CONFIG_FILE"
    echo "NFS_EXPORT_PATH=\"$NFS_PATH\"" >> "$CONFIG_FILE"
    echo "NFS_MOUNT_OPTIONS=\"soft,async,nolock,rsize=131072,wsize=131072,timeo=180,retrans=2,_netdev\"" >> "$CONFIG_FILE"
fi

if [ "$FINAL_STORAGE_TYPE" = "smb" ]; then
    echo "SMB_SERVER=\"$SMB_SERVER\"" >> "$CONFIG_FILE"
    echo "SMB_SHARE=\"$SMB_SHARE\"" >> "$CONFIG_FILE"
    echo "SMB_USERNAME=\"$SMB_USER\"" >> "$CONFIG_FILE"
fi

# Add Proxmox config
echo "" >> "$CONFIG_FILE"
echo "# Proxmox Configuration" >> "$CONFIG_FILE"
echo "PROXMOX_STORAGE=\"local-lvm\"" >> "$CONFIG_FILE"
echo "CONTAINER_ID_BASE=\"$CONTAINER_BASE\"" >> "$CONFIG_FILE"
echo "CONTAINER_ID_COUNT=\"20\"" >> "$CONFIG_FILE"
echo "CONTAINER_CPU=\"$CONTAINER_CPU\"" >> "$CONFIG_FILE"
echo "CONTAINER_RAM=\"$CONTAINER_RAM\"" >> "$CONFIG_FILE"
echo "CONTAINER_DISK_SIZE=\"$CONTAINER_DISK\"" >> "$CONFIG_FILE"

# Add provider-specific
if [ "$SELECTED_PROVIDER" = "ovh" ]; then
    echo "" >> "$CONFIG_FILE"
    echo "# OVH-Specific Configuration" >> "$CONFIG_FILE"
    echo "OVH_MAC_ADDRESS=\"$OVH_MAC\"" >> "$CONFIG_FILE"
    echo "OVH_VLAN_ID=\"$OVH_VLAN\"" >> "$CONFIG_FILE"
    echo "OVH_ANTI_DDOS_ENABLED=\"true\"" >> "$CONFIG_FILE"
fi

# Add defaults
echo "" >> "$CONFIG_FILE"
echo "# Deployment Options" >> "$CONFIG_FILE"
echo "AUTO_CREATE_CONTAINERS=\"false\"" >> "$CONFIG_FILE"
echo "SERVICES_TO_DEPLOY=\"prowlarr sonarr radarr qbittorrent jellyfin\"" >> "$CONFIG_FILE"
echo "SKIP_CONFIRMATION=\"false\"" >> "$CONFIG_FILE"
echo "VALIDATE_IPS=\"true\"" >> "$CONFIG_FILE"
echo "TEST_CONNECTIVITY=\"true\"" >> "$CONFIG_FILE"
echo "CREATE_BACKUPS=\"true\"" >> "$CONFIG_FILE"
echo "VERBOSE_LOGGING=\"false\"" >> "$CONFIG_FILE"

# Make file readable
chmod 600 "$CONFIG_FILE"

echo -e "${GREEN}✓ Configuration saved to: $CONFIG_FILE${NC}"

# ==============================================================================
# SUCCESS & NEXT STEPS
# ==============================================================================

print_section "✓ SETUP COMPLETE!"

echo ""
echo -e "${GREEN}Your ArrSuite environment is configured!${NC}"
echo ""
echo -e "${CYAN}Next Steps:${NC}"
echo "  1. Verify the configuration:"
echo "     cat config/environment.conf"
echo ""
echo "  2. Set up storage (if using local disk):"
echo "     bash storage-setup.sh"
echo ""
echo "  3. Create Proxmox containers:"
echo "     bash arr-stack-deploy.sh"
echo ""
echo "  4. (Optional) Set up WireGuard VPN:"
echo "     bash vpn-setup.sh"
echo ""
echo "  5. Run validation tests:"
echo "     bash tests/test-environment.sh"
echo ""
echo -e "${CYAN}Configuration File:${NC}"
echo "  $CONFIG_FILE"
echo ""
echo -e "${YELLOW}Tips:${NC}"
echo "  - You can re-run this script to update your configuration"
echo "  - Store config/environment.conf safely (contains IPs/settings)"
echo "  - For OVH: Make sure to add MAC addresses to OVH control panel"
echo ""

if [ "$SELECTED_PROVIDER" = "ovh" ]; then
    echo -e "${MAGENTA}OVH-Specific Reminders:${NC}"
    echo "  □ Add MAC addresses to OVH control panel"
    echo "  □ Configure static IP in /etc/network/interfaces"
    echo "  □ Verify NMS (Network Management System) for IP allocation"
    echo "  □ Check Anti-DDoS settings if needed"
    echo ""
fi

echo "Configuration complete! 🎉"
