# Universal Multi-Environment Community Guide Transformation Plan

**Project:** ArrSuite-Guide - Transform from homelab-specific to universal multi-environment community guide

**Status:** Planning Phase  
**Last Updated:** February 14, 2026  
**Current Branch:** staging  
**Target Environments:** Homelab, OVH Dedicated, Hetzner, AWS, DigitalOcean, Generic VPS

---

## Overview

Transform the homelab-specific ArrSuite-Guide into a universal, environment-aware community guide that works seamlessly across:
- **Dedicated servers** (OVH, Hetzner, Kimsufi)
- **Cloud VPS** (AWS EC2, DigitalOcean, Linode)
- **Homelab** (local hardware with DHCP)
- **Static IP environments** (OVH with MAC restrictions)
- **Restricted networking** (corporate, firewalled)

**Key Transformation Goals:**
1. Fix critical command errors (GitHub URLs, security issues, hardcoded values)
2. Add environment detection and adaptive configuration
3. Transform to proper community project (LICENSE, CONTRIBUTING.md, etc.)
4. Support multiple storage backends (local, NFS, SMB, cloud)
5. Support multiple networking modes (bridged, routed, NAT, DHCP, static)
6. Maintain backward compatibility for existing homelab users

---

## Phase 1: Environment Detection & Core Infrastructure

### 1.1 Create Environment Detection Library
**File:** `lib/detect-env.sh` (new)

**Tasks:**
- [ ] Detect cloud provider (AWS, GCP, OVH, Hetzner, DigitalOcean, or none)
- [ ] Detect network mode (bridged/routed/NAT-only)
- [ ] Test DHCP availability (ping DHCP server)
- [ ] Detect current subnet range and gateway
- [ ] Detect storage capabilities (local/NFS/block device)
- [ ] Detect Proxmox storage backend (local-lvm/ZFS/Ceph)
- [ ] Detect internet proxy presence
- [ ] Detect firewall type (iptables/cloud security groups/none)
- [ ] Detect init system (systemd/OpenRC)
- [ ] Detect package manager (apt/apk/yum)

**Functions:**
```bash
detect_cloud_provider()    # Returns: aws|gcp|ovh|hetzner|digitalocean|none
detect_network_mode()       # Returns: bridged|routed|nat
detect_dhcp_available()     # Returns: true|false
detect_gateway()            # Returns: IP address
detect_subnet()             # Returns: subnet in CIDR format
detect_storage_type()       # Returns: local|nfs|smb|block
detect_proxmox_storage()    # Returns: local-lvm|zfs|ceph|custom
has_internet_proxy()        # Returns: true|false
detect_init_system()        # Returns: systemd|openrc|sysvinit
```

### 1.2 Create Configuration Profiles System
**Directory:** `config/` (new)

**Profile Files to Create:**
- [ ] `config/homelab-dhcp.conf` - Original use case (bridged, DHCP, NAS)
- [ ] `config/ovh-static.conf` - OVH dedicated (static IP, MAC restrictions)
- [ ] `config/hetzner-routed.conf` - Hetzner (routed, 172.x subnet)
- [ ] `config/aws-vpc.conf` - AWS EC2 (security groups, 10.x subnet)
- [ ] `config/vps-generic.conf` - Generic VPS (single-IP, local storage)
- [ ] `config/environment.conf.example` - Template with all options

**Profile Contents:**
```bash
# Network Configuration
NETWORK_MODE="bridged|routed|nat"
DHCP_AVAILABLE="true|false"
SUBNET_RANGE="192.168.1.0/24"
GATEWAY_IP="192.168.1.1"
BRIDGE_NAME="vmbr0"

# Storage Configuration
STORAGE_TYPE="local|nfs|smb|block"
STORAGE_MOUNT_POINT="/mnt/storage"
NFS_SERVER_IP="192.168.1.200"
NFS_PATH="/exports/media"

# Proxmox Configuration
PROXMOX_STORAGE="local-lvm"
CONTAINER_ID_BASE="100"

# Cloud/Provider Configuration
CLOUD_PROVIDER="none|aws|ovh|hetzner"
FIREWALL_TYPE="iptables|security-groups|none"
```

### 1.3 Create Interactive Environment Setup Script
**File:** `environment-setup.sh` (new)

**Tasks:**
- [ ] Run environment detection functions
- [ ] Display detected environment to user
- [ ] Ask clarifying questions based on detected environment
- [ ] Offer to use detected profile or manual configuration
- [ ] Save validated configuration to `config/environment.conf`
- [ ] Validate all settings (reachable subnet, storage accessibility)
- [ ] Create summary report of configuration
- [ ] Test network connectivity
- [ ] Test storage accessibility

**Workflow:**
```
1. Welcome message
2. Run auto-detection
3. Display results: "Detected: AWS EC2, routed networking, local storage"
4. Ask: "Use AWS profile? (Y/n)"
5. If yes: Load config/aws-vpc.conf
6. If no: Interactive configuration questions
7. Validate all settings (ping gateway, test storage)
8. Save to config/environment.conf
9. Display summary and next steps
```

---

## Phase 2: Make Storage Universal

### 2.1 Replace NFS-Only Storage with Universal Storage Handler
**File:** `nfs-setup.sh` → **rename to** `storage-setup.sh`

**Tasks:**
- [ ] Add storage type detection/selection menu
- [ ] **Option 1: Local Disk** (VPS/single-server)
  - [ ] Detect available disks
  - [ ] Format if needed
  - [ ] Mount to configurable path
  - [ ] Add to fstab
- [ ] **Option 2: NFS** (homelab with NAS)
  - [ ] Prompt for NFS server IP
  - [ ] Prompt for NFS export path
  - [ ] Test NFS connectivity
  - [ ] Mount with proper options
- [ ] **Option 3: SMB/CIFS** (Windows shares)
  - [ ] Install cifs-utils
  - [ ] Prompt for credentials
  - [ ] Mount with credentials file
- [ ] **Option 4: Cloud Block Storage** (EBS, Persistent Disk)
  - [ ] Detect attached block devices
  - [ ] Format if needed
  - [ ] Mount with cloud-optimized options
- [ ] Make mount point configurable from environment.conf
- [ ] Change `chmod 777` → `chmod 755` with proper ownership
- [ ] Add validation for each storage type's mount options
- [ ] Create folder structure based on storage type

**Security Fix:**
```bash
# OLD (insecure):
chmod -R 777 "$MOUNT_POINT"

# NEW (secure):
chmod -R 755 "$MOUNT_POINT"
chown -R 1000:1000 "$MOUNT_POINT"  # Or configurable UID/GID
```

### 2.2 Update Storage Helper for Multiple Backends
**File:** `ct-add-storage.sh` (modify)

**Tasks:**
- [ ] Read mount point from environment.conf instead of hardcoded
- [ ] Support different mount methods:
  - [ ] Bind mount (local storage)
  - [ ] mp mount (NFS/network)
  - [ ] Volume (cloud storage)
- [ ] Add `--auto` flag to read from environment.conf
- [ ] Add `--storage-type` parameter for manual override
- [ ] Add `--mount-point` parameter for custom paths
- [ ] Make it work on non-Proxmox LXC (detect container manager)
- [ ] Validate mount success before exiting
- [ ] Add rollback on failure

**Example Usage:**
```bash
# Auto-mode (reads from environment.conf)
ct-add-storage --auto 106

# Manual override
ct-add-storage --storage-type nfs --mount-point /mnt/data 106

# Current (backward compatible)
ct-add-storage 106
```

### 2.3 Make Storage Watchdog Universal
**File:** `nfs-watchdog.sh` (modify)

**Tasks:**
- [ ] Read configuration from environment.conf
- [ ] Skip NFS-specific checks if storage type is local
- [ ] Support multiple storage protocols (NFS, SMB, local)
- [ ] Add timeout command check, fallback to alternative
- [ ] Add cloud storage health checks (EBS volume status)
- [ ] Make storage server IP configurable, not hardcoded
- [ ] Add email/webhook alerts (optional)

**Fixes:**
```bash
# OLD (hardcoded):
NFS_SERVER="192.168.1.200"
MOUNT_PATH="/mnt/cold-storage"

# NEW (configurable):
source /etc/arrsuite/environment.conf
NFS_SERVER="${STORAGE_SERVER_IP}"
MOUNT_PATH="${STORAGE_MOUNT_POINT}"

# Only run NFS checks if using NFS
if [ "$STORAGE_TYPE" = "nfs" ]; then
    # NFS-specific health checks
fi
```

---

## Phase 3: Network Universality

### 3.1 Make Network Configuration Environment-Aware
**File:** `vpn-setup.sh` (modify)

**Tasks:**
- [ ] Detect environment before starting
- [ ] Offer appropriate subnet range based on detected provider
- [ ] Auto-detect available bridge or offer routed mode
- [ ] Validate entered IPs are in valid range for provider
- [ ] Add security group/firewall rule guidance for cloud
- [ ] Fix Alpine template selection with validation
- [ ] Support OVH MAC-based filtering
- [ ] Support Hetzner routed networking
- [ ] Support AWS VPC with security groups

**Example Changes:**
```bash
# Detect environment
source lib/detect-env.sh
PROVIDER=$(detect_cloud_provider)
NETWORK_MODE=$(detect_network_mode)

case "$PROVIDER" in
    ovh)
        print_info "OVH detected. You'll need to add MAC address to OVH panel."
        ;;
    hetzner)
        print_info "Hetzner detected. Using routed mode (no bridge)."
        NETWORK_MODE="routed"
        ;;
    aws)
        print_info "AWS detected. Remember to configure security groups."
        ;;
esac
```

### 3.2 Add Networking Mode Documentation
**File:** `docs/NETWORKING_MODES.md` (new)

**Sections:**
- [ ] **Bridged Networking** (homelab, some dedicated servers)
  - [ ] What it is, how it works
  - [ ] Configuration examples
  - [ ] When to use
- [ ] **Routed Networking** (Hetzner, AWS, some VPS)
  - [ ] What it is, how it works
  - [ ] Provider examples (Hetzner, AWS)
  - [ ] Configuration examples
- [ ] **NAT-Only** (restricted environments)
  - [ ] What it is, limitations
  - [ ] Port forwarding requirements
- [ ] **Static IP Configuration** (OVH, Hetzner)
  - [ ] Provider-specific guides
  - [ ] MAC address requirements (OVH)
  - [ ] IP allocation
- [ ] Provider-Specific Examples:
  - [ ] OVH vRack configuration
  - [ ] AWS VPC setup
  - [ ] Hetzner network configuration
  - [ ] DigitalOcean private networking

### 3.3 Update Container Deployment for Static IP
**File:** `arr-stack-deploy.sh` (modify)

**Tasks:**
- [ ] Source environment.conf at start
- [ ] Check if DHCP or static IP mode
- [ ] If static: Prompt for IP allocation plan before deployment
- [ ] Pass network config to community scripts via environment variables
- [ ] Add error handling to deploy() function
- [ ] Verify each container gets network accessibility before proceeding
- [ ] Add rollback on failure
- [ ] Create IP allocation table for user reference

**Error Handling:**
```bash
deploy() {
    local name=$1
    local url=$2
    echo "📦 Deploying $name..."
    
    # Download and execute
    if bash -c "$(curl -fsSL $url 2>&1)"; then
        echo "✓ $name deployed successfully"
        
        # Verify container is accessible
        if ! verify_container_network "$LAST_CTID"; then
            echo "✗ $name network verification failed!"
            read -p "Continue anyway? (y/N): " -n 1 -r
            [[ ! $REPLY =~ ^[Yy]$ ]] && exit 1
        fi
    else
        echo "✗ $name deployment failed!"
        exit 1
    fi
}
```

---

## Phase 4: Fix Critical Issues

### 4.1 Fix All GitHub Branch References
**Files:** `README.md`, all markdown files, all scripts

**Tasks:**
- [ ] Change all URLs in README.md from `/main/` to `/staging/`
- [ ] Search entire workspace: `grep -r "raw.githubusercontent.com/AmmarTee/ArrSuite-Guide/main"`
- [ ] Update all instances to `/staging/`
- [ ] Add note in README about branch strategy:
  - `main` = stable releases
  - `staging` = development/testing

**Files to Update:**
- [ ] README.md (5+ instances)
- [ ] ARR_STACK_SETUP.md
- [ ] VPN_GETTING_STARTED.md
- [ ] VPN_SPLIT_TUNNEL_SETUP.md
- [ ] Any other docs with URLs

### 4.2 Standardize Command Formatting
**Files:** All markdown documentation

**Tasks:**
- [ ] Replace all `wget` commands with `curl` for consistency
- [ ] Add prerequisite checks to all scripts (verify curl availability)
- [ ] Add missing `chmod +x` instructions in ARR_STACK_SETUP.md
- [ ] Add missing `chmod +x` instructions in VPN_GETTING_STARTED.md
- [ ] Use `pct exec` one-liners instead of multi-step `pct enter/exit`
- [ ] Add download + permission steps to all script usage examples

**Standard Format:**
```bash
# Download
curl -fsSL https://raw.githubusercontent.com/.../script.sh -o script.sh

# Make executable
chmod +x script.sh

# Run
./script.sh
```

### 4.3 Add Input Validation to All Scripts
**Files:** All .sh scripts

**Tasks:**
- [ ] **nfs-setup.sh → storage-setup.sh**
  - [ ] Validate IP addresses (regex)
  - [ ] Test NFS connectivity before mounting
  - [ ] Validate mount point path
- [ ] **vpn-setup.sh**
  - [ ] Validate CTID is numeric and not in use
  - [ ] Validate IP is in correct subnet
  - [ ] Test gateway reachability
  - [ ] Validate config file exists and is readable
- [ ] **ct-add-storage.sh**
  - [ ] Validate CTID exists
  - [ ] Validate mount point exists on host
  - [ ] Verify mount success
- [ ] **All scripts**
  - [ ] Check for required commands before proceeding
  - [ ] Add usage/help output
  - [ ] Add dry-run mode for testing

**Example Validation:**
```bash
# IP address validation
validate_ip() {
    local ip=$1
    if [[ ! $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        return 1
    fi
    return 0
}

# Gateway reachability test
test_gateway() {
    local gw=$1
    if ping -c 1 -W 2 "$gw" >/dev/null 2>&1; then
        return 0
    fi
    return 1
}
```

---

## Phase 5: Documentation Restructuring

### 5.1 Create Provider-Specific Quick Start Guides
**Directory:** `docs/quickstart/` (new)

**Files to Create:**
- [ ] `docs/quickstart/homelab.md` - Original homelab setup
  - [ ] Hardware requirements
  - [ ] Network setup (router, DHCP)
  - [ ] NAS configuration
  - [ ] Step-by-step deployment
- [ ] `docs/quickstart/ovh.md` - OVH dedicated server
  - [ ] Order server and setup
  - [ ] Configure static IP and MAC
  - [ ] vRack configuration (optional)
  - [ ] Storage setup (local)
  - [ ] Firewall rules
- [ ] `docs/quickstart/hetzner.md` - Hetzner dedicated
  - [ ] Server setup
  - [ ] Routed networking configuration
  - [ ] 172.x subnet setup
  - [ ] Local storage
- [ ] `docs/quickstart/aws.md` - AWS EC2
  - [ ] VPC setup
  - [ ] Security groups
  - [ ] EBS volume configuration
  - [ ] Elastic IP assignment
- [ ] `docs/quickstart/generic-vps.md` - Generic VPS providers
  - [ ] Single-IP setup
  - [ ] Local storage
  - [ ] Reverse proxy for multiple services
  - [ ] Firewall configuration

**Structure for Each:**
```markdown
# Quick Start: [Provider]

## Prerequisites
- List specific requirements

## Step 1: Environment Setup
- Run environment-setup.sh
- Expected output

## Step 2: Storage Configuration
- Provider-specific storage setup

## Step 3: Deploy Services
- Run arr-stack-deploy.sh with provider config

## Step 4: Configure Networking
- Provider-specific networking (firewall, etc.)

## Step 5: External Access
- How to access services externally

## Troubleshooting
- Common issues for this provider
```

### 5.2 Restructure Main README for Universal Audience
**File:** `README.md` (major rewrite)

**Changes:**
- [ ] Title: "The Ultimate Media Homelab Wiki" → "Universal Media Automation Guide for Proxmox"
- [ ] Add "🌍 Choose Your Environment" section at top:
  ```markdown
  ## 🌍 Choose Your Environment
  
  This guide supports multiple deployment environments:
  - 🏠 [Homelab](docs/quickstart/homelab.md) - Local hardware with NAS
  - 🖥️ [OVH Dedicated Server](docs/quickstart/ovh.md) - Static IP, vRack
  - 🔧 [Hetzner Dedicated](docs/quickstart/hetzner.md) - Routed networking
  - ☁️ [AWS EC2](docs/quickstart/aws.md) - VPC with security groups
  - 🌐 [Generic VPS](docs/quickstart/generic-vps.md) - DigitalOcean, Linode, etc.
  ```
- [ ] Update subtitle to reflect universal nature
- [ ] Update architecture diagram to show multiple deployment scenarios
- [ ] Change personal tone: "Give it a ⭐" → community-focused
- [ ] Add supported environments badges
- [ ] Update prerequisites section to be environment-aware

### 5.3 Create Deployment Scenarios Documentation
**File:** `docs/DEPLOYMENT_SCENARIOS.md` (new)

**Sections:**
- [ ] **Scenario 1: Homelab with NAS** (original use case)
  - Architecture diagram
  - Pros/cons
  - Network topology
  - Step-by-step guide
- [ ] **Scenario 2: Single Server with Local Storage** (VPS)
  - Architecture diagram
  - Pros/cons
  - When to use
  - Step-by-step guide
- [ ] **Scenario 3: OVH Dedicated with Static IP**
  - Architecture diagram
  - OVH-specific setup (MAC, vRack)
  - Pros/cons
  - Step-by-step guide
- [ ] **Scenario 4: Cloud VPS** (AWS/DigitalOcean)
  - Architecture diagram
  - Security groups/firewall
  - Block storage setup
  - Step-by-step guide
- [ ] **Scenario 5: Behind Restrictive Firewall**
  - Limitations
  - Workarounds (Tailscale, Cloudflare Tunnel)
  - Step-by-step guide

### 5.4 Add Alternative Approaches Section
**Files:** `ARCHITECTURE.md`, `README.md`

**Tasks:**
- [ ] Add "Alternative Deployment Methods" section to ARCHITECTURE.md:
  - [ ] LXC containers (this guide's focus)
  - [ ] Docker Compose
  - [ ] Docker in VM
  - [ ] Native services on Proxmox host
  - [ ] Kubernetes (advanced)
  - Comparison table with pros/cons
- [ ] Add "Alternative Storage Solutions":
  - [ ] NFS (homelab)
  - [ ] SMB/CIFS (Windows)
  - [ ] Local storage (VPS)
  - [ ] Cloud block storage (AWS EBS, GCP Persistent Disk)
  - [ ] Ceph (Proxmox cluster)
  - [ ] ZFS (single server)
- [ ] Change prescriptive language:
  - "Best practice" → "Recommended approach"
  - "You must" → "It's recommended to"
  - "The only way" → "One effective method"
- [ ] Add "When NOT to use this guide" section
- [ ] Add "Related Guides" section with links to alternatives

---

## Phase 6: Community Infrastructure

### 6.1 Add Essential Community Files

#### LICENSE (new file)
- [ ] Create `LICENSE` file with MIT license text
- [ ] Copyright holder: "ArrSuite-Guide Contributors" (not personal)
- [ ] Include full MIT license text

#### CONTRIBUTING.md (new file)
- [ ] **How to Contribute**
  - Fork and clone
  - Branch naming conventions
  - Commit message guidelines
- [ ] **Types of Contributions Welcome**
  - Bug reports and fixes
  - Documentation improvements
  - Feature suggestions
  - Script enhancements
  - Alternative approaches
  - Provider-specific guides
- [ ] **Testing Requirements**
  - Test on target environment
  - Provide environment details
  - Verify scripts execute without errors
  - Check documentation renders correctly
- [ ] **Coding Standards for Scripts**
  - Use bashate or shellcheck
  - Include help/usage
  - Add error handling
  - Make configurable via environment.conf
- [ ] **Documentation Standards**
  - Clear structure
  - Code examples
  - Expected output
  - Troubleshooting section
- [ ] **Pull Request Process**
  - Target `staging` branch, not `main`
  - Describe changes
  - Link related issues
  - Wait for review

#### CODE_OF_CONDUCT.md (new file)
- [ ] Use Contributor Covenant (standard)
- [ ] Define community standards
- [ ] Enforcement guidelines
- [ ] Contact information

### 6.2 Create GitHub Templates
**Directory:** `.github/` (new)

#### Issue Templates
- [ ] `.github/ISSUE_TEMPLATE/bug_report.yml`
  ```yaml
  name: Bug Report
  description: Report a bug or issue
  body:
    - type: dropdown
      attributes:
        label: Environment
        options:
          - Homelab (local hardware)
          - OVH Dedicated Server
          - Hetzner Dedicated Server
          - AWS EC2
          - DigitalOcean
          - Other VPS
    - type: dropdown
      attributes:
        label: Component
        options:
          - Networking
          - Storage
          - Scripts
          - Documentation
    - type: textarea
      attributes:
        label: Description
  ```
- [ ] `.github/ISSUE_TEMPLATE/feature_request.yml`
- [ ] `.github/ISSUE_TEMPLATE/documentation.yml`
- [ ] `.github/ISSUE_TEMPLATE/config.yml` (configure issue creation)

#### Pull Request Template
- [ ] `.github/PULL_REQUEST_TEMPLATE.md`
  ```markdown
  ## Description
  <!-- What does this PR do? -->
  
  ## Type of Change
  - [ ] Bug fix
  - [ ] New feature
  - [ ] Documentation update
  - [ ] Breaking change
  
  ## Environment Tested
  - [ ] Homelab
  - [ ] OVH
  - [ ] Hetzner
  - [ ] AWS
  - [ ] Generic VPS
  
  ## Testing
  - [ ] Tested on Proxmox VE 8.x
  - [ ] Scripts execute without errors
  - [ ] Documentation renders correctly
  - [ ] No hardcoded values introduced
  
  ## Related Issues
  Closes #
  ```

### 6.3 Add Community Sections to README
**File:** `README.md` (additions)

**New Sections:**
- [ ] **"🌍 Supported Environments"** with badges
  ```markdown
  ![Homelab](https://img.shields.io/badge/Homelab-✓-green)
  ![OVH](https://img.shields.io/badge/OVH-✓-green)
  ![Hetzner](https://img.shields.io/badge/Hetzner-✓-green)
  ![AWS](https://img.shields.io/badge/AWS-✓-green)
  ![VPS](https://img.shields.io/badge/VPS-✓-green)
  ```
- [ ] **"🆘 Getting Help"**
  ```markdown
  - **Issues:** [Report bugs](../../issues)
  - **Discussions:** [Ask questions](../../discussions)
  - **r/Proxmox:** Reddit community
  - **r/sonarr, r/radarr:** App-specific help
  ```
- [ ] **"👥 Contributors"**
  ```markdown
  This project exists thanks to all contributors:
  <!-- ALL-CONTRIBUTORS-LIST:START -->
  See [Contributors Graph](../../graphs/contributors)
  <!-- ALL-CONTRIBUTORS-LIST:END -->
  ```
- [ ] **"🙏 Acknowledgments"**
  ```markdown
  - [Proxmox Community Scripts](https://github.com/community-scripts/ProxmoxVE)
  - [TRaSH Guides](https://trash-guides.info/)
  - [Servarr Community](https://wiki.servarr.com/)
  - All contributors and users
  ```
- [ ] **Community badges** (add to top)
  ```markdown
  ![Contributors](https://img.shields.io/github/contributors/AmmarTee/ArrSuite-Guide)
  ![Issues](https://img.shields.io/github/issues/AmmarTee/ArrSuite-Guide)
  ![Pull Requests](https://img.shields.io/github/issues-pr/AmmarTee/ArrSuite-Guide)
  ![Last Commit](https://img.shields.io/github/last-commit/AmmarTee/ArrSuite-Guide)
  ```

---

## Phase 7: Advanced Features

### 7.1 Add Firewall & Security Documentation
**File:** `docs/FIREWALL_CONFIGURATION.md` (new)

**Sections:**
- [ ] **Port Requirements Table**
  ```markdown
  | Service | Port | Protocol | Purpose |
  |---------|------|----------|---------|
  | Prowlarr | 9696 | TCP | Web UI |
  | Sonarr | 8989 | TCP | Web UI |
  | Radarr | 7878 | TCP | Web UI |
  | qBittorrent | 8080 | TCP | Web UI |
  | qBittorrent | 6881 | TCP/UDP | Torrenting |
  | Jellyfin | 8096 | TCP | Web UI |
  | Jellyseerr | 5055 | TCP | Web UI |
  ```
- [ ] **Internal Communication Requirements**
  - Which services need to talk to each other
  - Required open ports between containers
- [ ] **iptables Configuration** (homelab/VPS)
  - Example rules
  - Allow internal LXC traffic
  - NAT for outbound
- [ ] **AWS Security Groups Examples**
  - Inbound rules
  - Outbound rules
  - Security group for each service
- [ ] **GCP Firewall Rules Examples**
- [ ] **Azure NSG Configuration**
- [ ] **OVH Firewall Configuration**
  - Anti-DDoS considerations
  - Port restrictions
- [ ] **UFW Configuration** (simple firewall)
- [ ] **firewalld Configuration** (RHEL-based)

### 7.2 Add Remote Access Guides per Environment
**Files:** Update `VPN_GETTING_STARTED.md`, create `docs/REVERSE_PROXY_SETUP.md`

#### Update VPN_GETTING_STARTED.md
- [ ] Add environment-specific sections:
  - **Homelab**: Port forwarding, dynamic DNS
  - **VPS with Public IP**: Direct access, reverse proxy
  - **Cloud**: Load balancer configuration
  - **Behind CGNAT**: Tailscale, Cloudflare Tunnel required
- [ ] Add reverse proxy configuration stubs (link to detailed guide)

#### Create docs/REVERSE_PROXY_SETUP.md (new)
- [ ] **Why Reverse Proxy?**
  - Multiple services on one IP
  - SSL/TLS termination
  - Domain names for each service
- [ ] **Nginx Configuration**
  - Installation
  - Configuration for each service
  - SSL with Let's Encrypt
- [ ] **Traefik Configuration**
  - Docker Compose setup
  - Automatic SSL
  - Service discovery
- [ ] **Caddy Configuration**
  - Simplest setup
  - Automatic HTTPS
- [ ] **Cloud Load Balancers**
  - AWS Application Load Balancer
  - GCP Load Balancer
- [ ] **Cloudflare Tunnel Setup**
  - Installation
  - Configuration
  - When to use (CGNAT, no public IP)
- [ ] **Tailscale Subnet Router**
  - Installation on Proxmox
  - Subnet routing configuration
  - Access services via Tailscale

### 7.3 Add Troubleshooting Per Environment
**File:** `docs/TROUBLESHOOTING.md` (new)

**Sections:**
- [ ] **Network Connectivity Issues**
  - **Homelab**: DHCP not working, containers no IP
  - **OVH**: MAC not authorized, IP not assigned
  - **Hetzner**: Routed mode misconfiguration
  - **AWS**: Security groups blocking traffic
  - **VPS**: Firewall blocking connections
- [ ] **Storage Mount Failures**
  - **NFS**: "Stale file handle", mount failed
  - **SMB**: Authentication errors
  - **Local**: Disk not detected, permissions
  - **Cloud**: EBS not attached, formatting issues
- [ ] **Container Communication Problems**
  - Containers can't reach each other
  - Firewall blocking internal traffic
  - DNS resolution issues
- [ ] **Firewall Blocking**
  - By environment (iptables, cloud, provider)
  - How to diagnose
  - How to fix
- [ ] **Provider-Specific Gotchas**
  - **OVH**: MAC filter, anti-DDoS
  - **Hetzner**: Routed mode requirements
  - **AWS**: Security groups, NACLs
  - **DigitalOcean**: Firewall, droplet limits
- [ ] **Script Errors**
  - Common error messages
  - How to debug
  - Where to get help
- [ ] **Service-Specific Issues**
  - Prowlarr indexers failing
  - qBittorrent not downloading
  - Sonarr/Radarr not finding files
  - Jellyfin transcoding issues

---

## Phase 8: Testing & Validation

### 8.1 Create Environment Test Scripts
**Directory:** `tests/` (new)

#### tests/test-environment.sh (new)
- [ ] Test environment detection functions
- [ ] Verify network connectivity (ping gateway)
- [ ] Test storage accessibility (read/write)
- [ ] Check if containers can communicate
- [ ] Validate configuration file syntax
- [ ] Test internet connectivity
- [ ] Check required commands exist
- [ ] Report summary of tests

#### tests/test-deployment.sh (new)
- [ ] Validate full deployment process
- [ ] Check each container is running
- [ ] Verify each service is accessible via HTTP
- [ ] Test internal service communication
- [ ] Verify storage is mounted in containers
- [ ] Check logs for errors
- [ ] Report deployment status

#### tests/validate-config.sh (new)
- [ ] Validate environment.conf syntax
- [ ] Check all required fields present
- [ ] Validate IP addresses format
- [ ] Test network reachability
- [ ] Verify storage paths exist
- [ ] Check Proxmox storage exists

### 8.2 Add Verification Steps to All Docs
**Files:** All quickstart guides and main docs

**Add to Each Guide:**
- [ ] **Verification Section** after each major step
  ```markdown
  ### Verify This Step
  Run these commands to verify everything worked:
  
  ```bash
  # Check network
  pct exec 100 -- ping -c 3 8.8.8.8
  
  # Check storage mount
  pct exec 100 -- ls -lh /mnt/storage
  ```
  
  Expected output:
  ```
  [Show actual expected output]
  ```
  ```
- [ ] **"What Could Go Wrong"** sections for critical steps
- [ ] **Expected Output Examples** for all major commands
- [ ] **Troubleshooting Links** to specific sections

---

## Phase 9: Final Polish & Release

### 9.1 Code Quality Improvements
- [ ] Run shellcheck on all scripts
- [ ] Fix any warnings
- [ ] Add help/usage to all scripts (`script.sh --help`)
- [ ] Add version numbers to scripts
- [ ] Add dry-run mode to destructive operations
- [ ] Standardize error messages
- [ ] Standardize success messages
- [ ] Add progress indicators for long operations

### 9.2 Documentation Review
- [ ] Proofread all documentation
- [ ] Check all links work
- [ ] Verify code examples are correct
- [ ] Ensure consistent formatting
- [ ] Check all images/diagrams load
- [ ] Verify markdown renders correctly on GitHub
- [ ] Test all one-liner commands

### 9.3 Testing on Real Environments
- [ ] **Test on Homelab**
  - [ ] Fresh Proxmox install
  - [ ] Run environment-setup.sh
  - [ ] Deploy full stack
  - [ ] Verify all services work
- [ ] **Test on OVH Dedicated**
  - [ ] Static IP configuration
  - [ ] Run environment-setup.sh
  - [ ] Deploy stack
  - [ ] Verify networking
- [ ] **Test on AWS EC2**
  - [ ] Fresh instance
  - [ ] Run environment-setup.sh
  - [ ] Configure security groups
  - [ ] Deploy stack
- [ ] **Test on Generic VPS**
  - [ ] Local storage only
  - [ ] Single IP
  - [ ] Deploy stack

### 9.4 Create Release Notes
**File:** `CHANGELOG.md` (new)

**Sections:**
- [ ] What's new in this version
- [ ] Breaking changes (if any)
- [ ] Migration guide (for existing users)
- [ ] Known issues
- [ ] Contributors for this release

### 9.5 Update Main README
- [ ] Add version badge
- [ ] Add "tested on" badges with environments
- [ ] Update screenshots (if any)
- [ ] Add quick start links prominently
- [ ] Add "What's New" section
- [ ] Update table of contents

---

## Verification Checklist

After all phases complete:

### Code Quality
- [ ] No hardcoded IPs remain: `grep -r "192.168.1" . --exclude-dir=.git`
- [ ] No hardcoded paths: `grep -r "/mnt/cold-storage" . --exclude-dir=.git`
- [ ] No main branch refs: `grep -r "raw.githubusercontent.com.*main" . --exclude-dir=.git`
- [ ] All scripts pass shellcheck
- [ ] All scripts have help output
- [ ] All scripts source environment.conf

### Documentation
- [ ] All links work
- [ ] All code examples are correct
- [ ] Markdown renders correctly on GitHub
- [ ] Community files present (LICENSE, CONTRIBUTING, CODE_OF_CONDUCT)
- [ ] Issue templates work
- [ ] PR template works

### Functionality
- [ ] environment-setup.sh works on each target environment
- [ ] storage-setup.sh supports all storage types
- [ ] arr-stack-deploy.sh works with static and DHCP
- [ ] vpn-setup.sh adapts to environment
- [ ] Tests pass on all target environments

### Community
- [ ] Tone is community-focused, not personal
- [ ] Alternative approaches documented
- [ ] Contributing guidelines clear
- [ ] Code of conduct in place
- [ ] Help/support channels listed

---

## Future Enhancements (Post-Release)

### Phase 10: Advanced Features (Optional)
- [ ] Add Ansible playbook version
- [ ] Add Terraform for cloud deployments
- [ ] Add Kubernetes deployment option
- [ ] Add monitoring setup (Prometheus, Grafana)
- [ ] Add backup/restore scripts
- [ ] Add migration scripts (move between environments)
- [ ] Add high availability setup guide (Proxmox cluster)
- [ ] Add GPU passthrough guide per environment
- [ ] Add WireGuard VPN server setup
- [ ] Add Cloudflare DDNS update script

### Phase 11: Community Growth
- [ ] Create Discord server
- [ ] Setup GitHub Discussions categories
- [ ] Create video tutorials
- [ ] Write blog posts
- [ ] Submit to awesome lists
- [ ] Present at conferences/meetups
- [ ] Partner with related projects

---

## Timeline Estimate

| Phase | Estimated Time | Priority |
|-------|----------------|----------|
| Phase 1: Environment Detection | 2-3 days | Critical |
| Phase 2: Storage Universal | 2-3 days | Critical |
| Phase 3: Network Universality | 2-3 days | Critical |
| Phase 4: Fix Critical Issues | 1-2 days | Critical |
| Phase 5: Documentation Restructure | 3-4 days | High |
| Phase 6: Community Infrastructure | 1-2 days | High |
| Phase 7: Advanced Features | 2-3 days | Medium |
| Phase 8: Testing & Validation | 3-4 days | Critical |
| Phase 9: Final Polish | 1-2 days | High |
| **Total** | **17-28 days** | |

---

## Notes

- Maintain backward compatibility where possible
- Existing homelab users should be able to continue without changes
- All new features should be opt-in via environment.conf
- Document all breaking changes in CHANGELOG.md
- Test thoroughly on each target environment before release
- Keep community informed via GitHub Discussions during development

---

## Contributors to This Plan

- Initial plan created: February 14, 2026
- Contributors: [Add names as people contribute]

---

## Related Documents

- [ARCHITECTURE.md](ARCHITECTURE.md) - Technical architecture
- [CONTRIBUTING.md](CONTRIBUTING.md) - How to contribute (to be created)
- [README.md](README.md) - Main project README
