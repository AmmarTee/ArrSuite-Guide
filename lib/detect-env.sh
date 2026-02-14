#!/bin/bash
#
# ArrSuite Environment Detection Library
# Detects cloud provider, network mode, storage type, and system configuration
#
# Usage: source lib/detect-env.sh
#        detect_provider  # Returns: ovh|homelab|digitalocean|generic|hetzner
#

set -u

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# ==============================================================================
# PROVIDER DETECTION
# ==============================================================================

detect_provider() {
    # Detect cloud provider or local environment
    # Returns: ovh|digitalocean|hetzner|generic|homelab|unknown
    
    local provider="unknown"
    
    # Check for OVH environment markers
    if _is_ovh_environment; then
        provider="ovh"
    # Check for Hetzner environment markers
    elif _is_hetzner_environment; then
        provider="hetzner"
    # Check for DigitalOcean environment markers
    elif _is_digitalocean_environment; then
        provider="digitalocean"
    # Check if it looks like a homelab (has DHCP-like behavior)
    elif _has_dhcp_capability; then
        provider="homelab"
    else
        provider="generic"
    fi
    
    echo "$provider"
}

_is_ovh_environment() {
    # OVH detection:
    # 1. Check for OVH metadata service
    # 2. Check for OVH Agent
    # 3. Check /proc/cmdline for OVH markers
    # 4. Check DMI data for OVH
    
    if [ -f /proc/cmdline ]; then
        if grep -q "ovh" /proc/cmdline 2>/dev/null; then
            return 0
        fi
    fi
    
    if [ -f /etc/issue ]; then
        if grep -q "OVH" /etc/issue 2>/dev/null; then
            return 0
        fi
    fi
    
    # Check for OVH agent
    if command -v ovh-agent &> /dev/null; then
        return 0
    fi
    
    # Check DMI product name for OVH
    if [ -f /sys/class/dmi/id/system_product_name ]; then
        local product=$(cat /sys/class/dmi/id/system_product_name 2>/dev/null)
        if [[ "$product" =~ (OVH|Scaleway) ]]; then
            return 0
        fi
    fi
    
    return 1
}

_is_hetzner_environment() {
    # Hetzner detection:
    # Check for Hetzner Cloud metadata
    # Check /proc/cmdline for Hetzner
    
    if [ -f /proc/cmdline ]; then
        if grep -q "hetzner" /proc/cmdline 2>/dev/null; then
            return 0
        fi
    fi
    
    # Hetzner Cloud has metadata server at 169.254.169.254
    if timeout 2 curl -s -m 2 http://169.254.169.254/hcloud/v1/metadata 2>/dev/null | grep -q "hcloud"; then
        return 0
    fi
    
    return 1
}

_is_digitalocean_environment() {
    # DigitalOcean detection:
    # Check for DigitalOcean metadata service
    
    if timeout 2 curl -s -m 2 http://169.254.169.254/metadata/v1/ 2>/dev/null | grep -q "DigitalOcean"; then
        return 0
    fi
    
    return 1
}

_has_dhcp_capability() {
    # Check if this looks like a DHCP environment (homelab indicator)
    # Look for DHCP server on network
    
    # Simple check: if we have a default gateway and can reach external network, likely homelab
    if ip route | grep -q "^default via"; then
        return 0
    fi
    
    return 1
}

# ==============================================================================
# NETWORK CONFIGURATION DETECTION
# ==============================================================================

detect_network_mode() {
    # Detect network mode: bridged|routed|nat
    # For OVH: will be routed (static IP assigned directly)
    # For homelab: will be bridged
    
    local mode="unknown"
    
    # Check for bridge interface (homelab indicator)
    if ip link show | grep -q "^.*: .*bridge"; then
        mode="bridged"
    # Check for routed mode (no bridge, static IP configured directly)
    else
        mode="routed"
    fi
    
    echo "$mode"
}

detect_gateway() {
    # Detect default gateway IP
    ip route | grep "^default" | awk '{print $3}' | head -1
}

detect_subnet() {
    # Detect current subnet in CIDR notation
    local gateway=$(detect_gateway)
    
    if [ -z "$gateway" ]; then
        echo "unknown"
        return
    fi
    
    # Get all IPs on interfaces
    local ips=$(hostname -I | awk '{print $1}')
    
    for ip in $ips; do
        # Get subnet from ip route
        ip route | grep "dev" | grep -v "default" | while read line; do
            local subnet=$(echo "$line" | awk '{print $1}')
            if [[ $subnet == *"/"* ]]; then
                echo "$subnet"
                return
            fi
        done
    done
    
    echo "unknown"
}

detect_primary_ip() {
    # Detect primary IP address for this system
    # Prefer public IPs, fall back to private
    
    local ip=""
    
    # Try to get IP from ip route
    ip=$(ip route get 1 | awk 'NR==1 {print $(NF-2)}' 2>/dev/null)
    
    if [ -z "$ip" ] || [[ "$ip" == "0.0.0.0" ]]; then
        # Fall back to hostname -I
        ip=$(hostname -I | awk '{print $1}')
    fi
    
    if [ -z "$ip" ]; then
        ip="unknown"
    fi
    
    echo "$ip"
}

# ==============================================================================
# STORAGE DETECTION
# ==============================================================================

detect_storage_type() {
    # Detect available storage types: local|nfs|smb|block|unknown
    # For OVH: will usually be local (disk partition)
    # For homelab with NAS: will be nfs
    
    local storage_type="local"
    
    # Check for NFS mounts
    if mountpoint -q /mnt 2>/dev/null; then
        if mount | grep -q "nfs"; then
            storage_type="nfs"
        fi
    fi
    
    # Check for SMB/CIFS mounts
    if mount | grep -q "cifs"; then
        storage_type="smb"
    fi
    
    # Check for block device (/dev/vdb, /dev/sdb, etc. - cloud block storage)
    if ls /dev/vd* /dev/sd* 2>/dev/null | grep -q "vdb\|sdb"; then
        # Additional check that it's not the root disk
        if ! lsblk -d -n -o NAME,MOUNTPOINT | grep -E "(vdb|sdb)" | grep -q "/$"; then
            storage_type="block"
        fi
    fi
    
    echo "$storage_type"
}

detect_proxmox_storage() {
    # Detect if running on Proxmox and what storage backend it uses
    # Returns: local-lvm|zfs|ceph|local-disk|none
    
    if ! command -v pvesh &> /dev/null && ! command -v pct &> /dev/null; then
        echo "none"
        return
    fi
    
    # We're on Proxmox, detect storage
    if pvesh get /nodes 2>/dev/null | grep -q "local-lvm"; then
        echo "local-lvm"
    elif pvesh get /nodes 2>/dev/null | grep -q "zfs"; then
        echo "zfs"
    elif pvesh get /nodes 2>/dev/null | grep -q "ceph"; then
        echo "ceph"
    else
        echo "local"
    fi
}

detect_local_storage_path() {
    # Find a suitable local storage path for media
    # For OVH: likely /srv, /home, or mounted partition
    # For homelab: might be /mnt
    
    local paths=(
        "/mnt/media"
        "/srv/media"
        "/home/media"
        "/var/media"
        "/opt/media"
    )
    
    # Return first path that's on a dedicated partition (not root)
    for path in "${paths[@]}"; do
        if [ -d "${path%/*}" ]; then
            echo "${path%/*}"
            return
        fi
    done
    
    # Fall back to /mnt if nothing else
    echo "/mnt"
}

# ==============================================================================
# SYSTEM DETECTION
# ==============================================================================

detect_init_system() {
    # Detect init system: systemd|openrc|sysvinit
    
    if [ -d /run/systemd/system ]; then
        echo "systemd"
    elif [ -f /sbin/openrc-init ]; then
        echo "openrc"
    else
        echo "sysvinit"
    fi
}

detect_package_manager() {
    # Detect package manager: apt|apk|yum|dnf|pacman|unknown
    
    if command -v apt &> /dev/null; then
        echo "apt"
    elif command -v apk &> /dev/null; then
        echo "apk"
    elif command -v dnf &> /dev/null; then
        echo "dnf"
    elif command -v yum &> /dev/null; then
        echo "yum"
    elif command -v pacman &> /dev/null; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

detect_distro() {
    # Detect Linux distribution
    
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/lsb-release ]; then
        . /etc/lsb-release
        echo "${DISTRIB_ID,,}"
    else
        echo "unknown"
    fi
}

# ==============================================================================
# NETWORKING HELPERS
# ==============================================================================

has_internet_connectivity() {
    # Test if system has internet connectivity
    
    # Try multiple DNS servers
    if ping -c 1 -W 2 8.8.8.8 &> /dev/null; then
        return 0
    elif ping -c 1 -W 2 1.1.1.1 &> /dev/null; then
        return 0
    elif timeout 2 curl -s -m 2 https://dns.google &> /dev/null; then
        return 0
    fi
    
    return 1
}

test_gateway_reachability() {
    # Test if default gateway is reachable
    
    local gateway=$(detect_gateway)
    
    if [ -z "$gateway" ] || [ "$gateway" = "unknown" ]; then
        return 1
    fi
    
    if ping -c 1 -W 2 "$gateway" &> /dev/null; then
        return 0
    fi
    
    return 1
}

validate_ip_address() {
    # Validate if argument is a valid IP address
    local ip=$1
    
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 0
    fi
    
    return 1
}

ip_in_subnet() {
    # Check if IP is in a given subnet
    local ip=$1
    local subnet=$2
    
    # Simple check: convert to numbers and compare
    # This is a basic check; for production use `ipcalc`
    
    local ip_num=$(printf '%d.%d.%d.%d' ${ip//./ })
    
    return 0  # Simplified for now
}

# ==============================================================================
# DIAGNOSTIC FUNCTIONS
# ==============================================================================

print_detection_summary() {
    # Print a summary of detected environment
    
    local provider=$(detect_provider)
    local network_mode=$(detect_network_mode)
    local gateway=$(detect_gateway)
    local primary_ip=$(detect_primary_ip)
    local subnet=$(detect_subnet)
    local storage=$(detect_storage_type)
    local init=$(detect_init_system)
    local pm=$(detect_package_manager)
    local distro=$(detect_distro)
    
    echo ""
    echo -e "${BLUE}=== ENVIRONMENT DETECTION SUMMARY ===${NC}"
    echo ""
    echo -e "Provider:             ${GREEN}${provider}${NC}"
    echo -e "Network Mode:         ${GREEN}${network_mode}${NC}"
    echo -e "Primary IP:           ${GREEN}${primary_ip}${NC}"
    echo -e "Gateway:              ${GREEN}${gateway}${NC}"
    echo -e "Subnet:               ${GREEN}${subnet}${NC}"
    echo -e "Storage Type:         ${GREEN}${storage}${NC}"
    echo -e "Init System:          ${GREEN}${init}${NC}"
    echo -e "Package Manager:      ${GREEN}${pm}${NC}"
    echo -e "Distribution:         ${GREEN}${distro}${NC}"
    echo ""
    
    # Check connectivity
    if has_internet_connectivity; then
        echo -e "Internet:             ${GREEN}✓ Reachable${NC}"
    else
        echo -e "Internet:             ${RED}✗ Not reachable${NC}"
    fi
    
    if test_gateway_reachability; then
        echo -e "Gateway:              ${GREEN}✓ Reachable${NC}"
    else
        echo -e "Gateway:              ${RED}✗ Not reachable${NC}"
    fi
    
    echo ""
}

# ==============================================================================
# EXPORT FUNCTIONS FOR USE IN OTHER SCRIPTS
# ==============================================================================

# Detect and export to environment
export DETECTED_PROVIDER=$(detect_provider)
export DETECTED_NETWORK_MODE=$(detect_network_mode)
export DETECTED_GATEWAY=$(detect_gateway)
export DETECTED_SUBNET=$(detect_subnet)
export DETECTED_PRIMARY_IP=$(detect_primary_ip)
export DETECTED_STORAGE_TYPE=$(detect_storage_type)
export DETECTED_INIT=$(detect_init_system)
export DETECTED_PM=$(detect_package_manager)
export DETECTED_DISTRO=$(detect_distro)

# For use in condition checks
export HAS_INTERNET=$(has_internet_connectivity && echo "true" || echo "false")
export GATEWAY_REACHABLE=$(test_gateway_reachability && echo "true" || echo "false")
