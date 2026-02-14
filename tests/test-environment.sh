#!/bin/bash
#
# ArrSuite Environment Validation & Testing Script
#
# This script validates that your environment is properly configured
# for ArrSuite deployment. It tests:
#   - Network connectivity
#   - Storage accessibility
#   - Proxmox availability
#   - Configuration file validity
#   - System requirements
#
# Usage: bash tests/test-environment.sh [OPTIONS]
#   --verbose       Show detailed output
#   --config PATH   Use specific config file
#   --skip-storage  Skip storage validation
#   --fix           Attempt to fix common issues
#

# Note: Intentionally NOT using set -e to allow tests to continue
# even when individual checks fail, so we get a complete report

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config/environment.conf"
VERBOSE=false
SKIP_STORAGE=false
FIX_ISSUES=false
TEST_PASSED=0
TEST_FAILED=0
TEST_WARNINGS=0

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

# ==============================================================================
# HELPER FUNCTIONS
# ==============================================================================

print_header() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║         ArrSuite Environment Validation Test               ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

test_section() {
    echo ""
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${MAGENTA}▶ $1${NC}"
    echo -e "${MAGENTA}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

test_pass() {
    echo -e "${GREEN}  ✓ $1${NC}"
    ((TEST_PASSED++))
}

test_fail() {
    echo -e "${RED}  ✗ FAILED: $1${NC}"
    ((TEST_FAILED++))
}

test_warn() {
    echo -e "${YELLOW}  ⚠ WARNING: $1${NC}"
    ((TEST_WARNINGS++))
}

test_info() {
    if [ "$VERBOSE" = "true" ]; then
        echo -e "${BLUE}  ℹ $1${NC}"
    fi
}

ask_fix() {
    if [ "$FIX_ISSUES" = "true" ]; then
        return 0
    fi
    
    local response
    read -p "  Try to fix this? (y/N): " response
    [[ $response =~ ^[Yy]$ ]]
}

# ==============================================================================
# ARGUMENT PARSING
# ==============================================================================

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                VERBOSE=true
                shift
                ;;
            --config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            --skip-storage)
                SKIP_STORAGE=true
                shift
                ;;
            --fix)
                FIX_ISSUES=true
                shift
                ;;
            --help)
                show_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << EOF
ArrSuite Environment Validation Test

Usage: bash tests/test-environment.sh [OPTIONS]

Options:
  --verbose       Show detailed test information
  --config PATH   Use specific configuration file
  --skip-storage  Skip storage validation tests
  --fix           Automatically fix common issues
  --help          Show this help message

This script validates:
  ✓ Configuration file exists and is valid
  ✓ Network connectivity and routing
  ✓ Gateway and Internet reachability
  ✓ Storage accessibility and permissions
  ✓ Proxmox installation and tools
  ✓ Container support and settings
  ✓ Required system packages
  ✓ Firewall configuration
  ✓ NFS/SMB mount points (if configured)

Exit codes:
  0 = All tests passed
  1 = One or more tests failed
  2 = Warnings present (tests passed with caveats)

EOF
}

# ==============================================================================
# CONFIGURATION TESTS
# ==============================================================================

test_configuration() {
    test_section "Configuration File"
    
    if [ ! -f "$CONFIG_FILE" ]; then
        test_fail "Configuration file not found: $CONFIG_FILE"
        test_info "Run: bash environment-setup.sh"
        return 1
    fi
    
    test_pass "Configuration file exists"
    
    # Try to source it
    if ! bash -n "$CONFIG_FILE" 2>/dev/null; then
        test_fail "Configuration file has syntax errors"
        test_info "Run: bash environment-setup.sh"
        return 1
    fi
    
    test_pass "Configuration file syntax is valid"
    
    # Load config
    source "$CONFIG_FILE" || {
        test_fail "Failed to load configuration"
        return 1
    }
    
    test_pass "Configuration loaded successfully"
    
    # Check required variables
    local required_vars=(
        "DETECTED_PROVIDER"
        "NETWORK_MODE"
        "STORAGE_TYPE"
        "STORAGE_MOUNT_POINT"
    )
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var:-}" ]; then
            test_warn "Required variable not set: $var"
        else
            test_info "$var = ${!var}"
        fi
    done
}

# ==============================================================================
# NETWORK TESTS
# ==============================================================================

test_network() {
    test_section "Network Connectivity"
    
    # Check if running in container
    if grep -q "docker\|lxc\|kubernetes" /proc/1/cgroup 2>/dev/null; then
        test_warn "Running inside a container - some tests may be limited"
    else
        test_pass "Running on host system"
    fi
    
    # Check default route
    if ip route | grep -q "^default"; then
        local gateway=$(ip route | grep "^default" | awk '{print $3}')
        test_pass "Default gateway found: $gateway"
    else
        test_fail "No default gateway configured"
        return 1
    fi
    
    # Check primary IP
    local primary_ip=$(hostname -I | awk '{print $1}')
    if [ -n "$primary_ip" ]; then
        test_pass "Primary IP: $primary_ip"
    else
        test_fail "Unable to determine primary IP"
        return 1
    fi
    
    # Test gateway reachability
    test_info "Testing gateway reachability..."
    if timeout 2 ping -c 1 "$gateway" &>/dev/null; then
        test_pass "Gateway is reachable"
    else
        test_warn "Gateway is not reachable: $gateway"
    fi
    
    # Test internet connectivity
    test_info "Testing internet connectivity..."
    local internet_ok=false
    for ip in 8.8.8.8 1.1.1.1 208.67.222.222; do
        if timeout 2 ping -c 1 "$ip" &>/dev/null; then
            test_pass "Internet is reachable (via $ip)"
            internet_ok=true
            break
        fi
    done
    
    if [ "$internet_ok" = "false" ]; then
        test_warn "Internet does not appear to be reachable"
    fi
    
    # Test DNS
    test_info "Testing DNS resolution..."
    if timeout 2 nslookup google.com &>/dev/null; then
        test_pass "DNS resolution working"
    else
        test_warn "DNS resolution may have issues"
    fi
}

# ==============================================================================
# STORAGE TESTS
# ==============================================================================

test_storage() {
    test_section "Storage Configuration"
    
    if [ "$SKIP_STORAGE" = "true" ]; then
        test_info "Storage tests skipped"
        return 0
    fi
    
    # Load config if needed
    if [ -z "${STORAGE_TYPE:-}" ] && [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" || true
    fi
    
    STORAGE_TYPE=${STORAGE_TYPE:-"unknown"}
    STORAGE_MOUNT_POINT=${STORAGE_MOUNT_POINT:-"/mnt/media"}
    
    test_pass "Storage type: $STORAGE_TYPE"
    test_pass "Mount point: $STORAGE_MOUNT_POINT"
    
    case "$STORAGE_TYPE" in
        local)
            test_local_storage
            ;;
        nfs)
            test_nfs_storage
            ;;
        smb)
            test_smb_storage
            ;;
        *)
            test_warn "Unknown storage type: $STORAGE_TYPE"
            ;;
    esac
}

test_local_storage() {
    test_info "Testing local storage..."
    
    if [ ! -d "$STORAGE_MOUNT_POINT" ]; then
        test_fail "Storage mount point does not exist: $STORAGE_MOUNT_POINT"
        
        if ask_fix; then
            mkdir -p "$STORAGE_MOUNT_POINT"
            test_pass "Created storage mount point"
        fi
        return 1
    fi
    
    test_pass "Storage mount point exists"
    
    # Check permissions
    if [ -w "$STORAGE_MOUNT_POINT" ]; then
        test_pass "Storage mount point is writable"
    else
        test_fail "Storage mount point is not writable"
        test_info "Permissions: $(ls -ld $STORAGE_MOUNT_POINT | awk '{print $1}')"
        return 1
    fi
    
    # Test read/write
    local test_file="$STORAGE_MOUNT_POINT/.test-$$"
    if echo "test" > "$test_file" 2>/dev/null && rm "$test_file" 2>/dev/null; then
        test_pass "Storage mount point read/write test passed"
    else
        test_fail "Cannot write to storage mount point"
        return 1
    fi
    
    # Check available space
    local available=$(df -h "$STORAGE_MOUNT_POINT" | tail -1 | awk '{print $4}')
    test_pass "Available space: $available"
}

test_nfs_storage() {
    test_info "Testing NFS storage..."
    
    # Check for NFS tools
    if ! command -v mount.nfs &>/dev/null; then
        test_warn "NFS client tools not installed (nfs-common)"
        if ask_fix; then
            apt-get update && apt-get install -y nfs-common
            test_pass "Installed nfs-common"
        fi
        return
    fi
    
    test_pass "NFS client tools installed"
    
    # Check if already mounted
    if mountpoint -q "$STORAGE_MOUNT_POINT" 2>/dev/null; then
        test_pass "NFS is mounted: $STORAGE_MOUNT_POINT"
        
        # Check space
        local available=$(df -h "$STORAGE_MOUNT_POINT" | tail -1 | awk '{print $4}')
        test_pass "Available space: $available"
    else
        test_warn "NFS mount not found: $STORAGE_MOUNT_POINT"
        test_info "You may need to run: bash storage-setup.sh"
    fi
}

test_smb_storage() {
    test_info "Testing SMB storage..."
    
    if ! command -v mount.cifs &>/dev/null; then
        test_warn "SMB client tools not installed (cifs-utils)"
        if ask_fix; then
            apt-get update && apt-get install -y cifs-utils
            test_pass "Installed cifs-utils"
        fi
        return
    fi
    
    test_pass "SMB client tools installed"
    
    if mountpoint -q "$STORAGE_MOUNT_POINT" 2>/dev/null; then
        test_pass "SMB is mounted: $STORAGE_MOUNT_POINT"
    else
        test_warn "SMB mount not found: $STORAGE_MOUNT_POINT"
    fi
}

# ==============================================================================
# PROXMOX TESTS
# ==============================================================================

test_proxmox() {
    test_section "Proxmox Environment"
    
    # Check if Proxmox tools are installed
    if ! command -v pct &>/dev/null; then
        test_fail "Proxmox tools not found (pct command)"
        test_info "This script requires Proxmox VE"
        return 1
    fi
    
    test_pass "Proxmox tools installed"
    
    # Try to get Proxmox version
    if pvesh get /version 2>/dev/null | grep -q "version"; then
        test_pass "Can access Proxmox API"
    else
        test_warn "Unable to access Proxmox API (may require root)"
    fi
    
    # Test container commands
    if pct list 2>/dev/null | grep -q "VMID"; then
        test_pass "Can list containers"
    else
        test_warn "Cannot list containers (permission issue)"
    fi
    
    # Load config and check container ID settings
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" || true
        
        if [ -n "${CONTAINER_ID_BASE:-}" ]; then
            test_info "Container ID base: $CONTAINER_ID_BASE"
        fi
    fi
}

# ==============================================================================
# SYSTEM REQUIREMENTS TESTS
# ==============================================================================

test_system_requirements() {
    test_section "System Requirements"
    
    # Check kernel
    local kernel=$(uname -r)
    test_pass "Kernel: $kernel"
    
    # Check if 64-bit
    if [ "$(uname -m)" = "x86_64" ]; then
        test_pass "Architecture: x86_64 (64-bit)"
    else
        test_warn "Architecture is not x86_64: $(uname -m)"
    fi
    
    # Check system must have enough RAM
    local total_ram=$(free -h | grep "^Mem:" | awk '{print $2}')
    test_pass "Total RAM: $total_ram"
    
    # Required commands
    local required_cmds=(
        "curl"
        "wget"
        "tar"
        "grep"
        "awk"
        "sed"
        "ip"
        "mount"
    )
    
    test_info "Checking required commands..."
    for cmd in "${required_cmds[@]}"; do
        if command -v "$cmd" &>/dev/null; then
            test_info "  ✓ $cmd"
        else
            test_warn "Missing command: $cmd"
        fi
    done
    
    # Check if systemd is available
    if [ -d /run/systemd/system ]; then
        test_pass "Init system: systemd"
    else
        test_warn "Init system: not systemd"
    fi
}

# ==============================================================================
# FIREWALL TESTS
# ==============================================================================

test_firewall() {
    test_section "Firewall & Security"
    
    # Check for UFW
    if command -v ufw &>/dev/null; then
        if ufw status 2>/dev/null | grep -q "Status: active"; then
            test_info "UFW is active"
        else
            test_info "UFW is inactive"
        fi
    fi
    
    # Check for iptables
    if command -v iptables &>/dev/null; then
        test_pass "iptables available"
    fi
    
    # Check if port forwarding is enabled (for routing)
    if [ -f /proc/sys/net/ipv4/ip_forward ]; then
        local forward=$(cat /proc/sys/net/ipv4/ip_forward)
        if [ "$forward" = "1" ]; then
            test_pass "IP forwarding enabled"
        else
            test_info "IP forwarding disabled (may be needed for routing)"
        fi
    fi
    
    # Check for AppArmor/SELinux
    if command -v aa-status &>/dev/null; then
        test_info "AppArmor available"
    fi
    
    if command -v getenforce &>/dev/null; then
        test_warn "SELinux may need configuration"
    fi
}

# ==============================================================================
# PROVIDER-SPECIFIC TESTS
# ==============================================================================

test_provider_specific() {
    test_section "Provider-Specific Configuration"
    
    if [ -f "$CONFIG_FILE" ]; then
        source "$CONFIG_FILE" || true
    fi
    
    local provider="${DETECTED_PROVIDER:-unknown}"
    test_info "Provider: $provider"
    
    case "$provider" in
        ovh)
            test_ovh_specific
            ;;
        homelab)
            test_homelab_specific
            ;;
        *)
            test_info "No provider-specific tests for: $provider"
            ;;
    esac
}

test_ovh_specific() {
    test_info "OVH Dedicated Server Tests"
    
    # Check for OVH markers
    if grep -q "OVH" /etc/issue 2>/dev/null; then
        test_pass "OVH environment detected"
    else
        test_info "OVH environment markers not found (may be in custom OS)"
    fi
    
    # Check network interface
    if ip link show | grep -q "eth0"; then
        test_pass "Primary network interface: eth0"
    fi
    
    # Check static IP configuration
    if [ -f /etc/network/interfaces ]; then
        if grep -q "static" /etc/network/interfaces; then
            test_pass "Static IP configuration found"
        else
            test_warn "Static IP configuration not found - expected for OVH"
        fi
    fi
}

test_homelab_specific() {
    test_info "Homelab Environment Tests"
    
    # Check for bridge interface
    if ip link show | grep -q "bridge"; then
        test_pass "Bridge interface found"
    else
        test_warn "No bridge interface found - expected for homelab"
    fi
    
    # Check if DHCP is available
    if grep -q "DHCP" /etc/network/interfaces 2>/dev/null || \
       grep -q "dhcp" /etc/network/interfaces 2>/dev/null; then
        test_pass "DHCP configuration found"
    fi
}

# ==============================================================================
# SUMMARY
# ==============================================================================

print_summary() {
    echo ""
    echo -e "${BLUE}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║                      TEST SUMMARY                           ║${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    echo -e "${GREEN}Passed:  $TEST_PASSED${NC}"
    if [ $TEST_WARNINGS -gt 0 ]; then
        echo -e "${YELLOW}Warnings: $TEST_WARNINGS${NC}"
    fi
    if [ $TEST_FAILED -gt 0 ]; then
        echo -e "${RED}Failed:  $TEST_FAILED${NC}"
    fi
    echo ""
    
    if [ $TEST_FAILED -eq 0 ]; then
        if [ $TEST_WARNINGS -eq 0 ]; then
            echo -e "${GREEN}✓ All tests passed!${NC}"
            echo ""
            echo "Your environment is ready for ArrSuite deployment:"
            echo "  1. Run: bash storage-setup.sh (if not already done)"
            echo "  2. Run: bash arr-stack-deploy.sh"
            return 0
        else
            echo -e "${YELLOW}✓ Tests passed with warnings${NC}"
            echo "Review the warnings above and fix if needed."
            return 2
        fi
    else
        echo -e "${RED}✗ Some tests failed${NC}"
        echo "Please fix the failures above and run this test again."
        return 1
    fi
}

# ==============================================================================
# MAIN
# ==============================================================================

main() {
    parse_arguments "$@"
    
    print_header
    
    test_configuration
    test_network
    test_storage
    test_proxmox
    test_system_requirements
    test_firewall
    test_provider_specific
    
    print_summary
    exit $?
}

main "$@"
