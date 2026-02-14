# ArrSuite-Guide: Universal Media Automation for Proxmox

> **Complete media server automation stack** for Proxmox VE supporting **Homelab, OVH, Hetzner, AWS, and Generic VPS** deployments.

## 🌍 Supported Environments

This guide now supports multiple deployment scenarios:

- 🏠 **Homelab** - Local hardware with NAS (DHCP + NFS)
- 🖥️ **OVH Dedicated** - Static IP with local storage (NEW!)
- 🔧 **Hetzner** - Routed networking with local storage
- ☁️ **AWS/Cloud VPC** - Security groups with cloud storage
- 🌐 **VPS (Generic)** - Single IP with local storage

---

## ⚡ What's New (February 2026)

### 🆕 Environment Detection & Auto-Configuration
```bash
# Run once, auto-detects your setup
bash environment-setup.sh
```
Automatically detects:
- ✅ Cloud provider (OVH, Hetzner, AWS, homelab, generic)
- ✅ Network configuration (bridged, routed, NAT)
- ✅ Storage type (local, NFS, SMB, cloud block)
- ✅ System info (IP, gateway, init system, distro)

### 🆕 Universal Storage Setup
```bash
# Supports: Local, NFS, SMB/CIFS, Cloud Block
bash storage-setup.sh --auto
```

### 🆕 Comprehensive Validation Tests
```bash
# 19 automated tests covering everything
bash tests/test-environment.sh
```

### 🆕 OVH Quick Start Guide
Complete 450+ line guide for OVH deployments:
```bash
cat docs/OVH_QUICKSTART.md
```

### 🔒 Security Fixes
- ✅ Fixed: `chmod 777` → `chmod 755` (security vulnerability patched)
- ✅ Configuration-based (no hardcoded paths)
- ✅ Input validation for all user data

---

## 📋 Choose Your Path

### 🆕 **New to this? Start here:**
1. Read: **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** (2 min read)
2. Run: `bash environment-setup.sh` (5 min interactive)
3. Test: `bash tests/test-environment.sh` (1 min)

### 🔧 **OVH Dedicated Server:**
1. Read: **[docs/OVH_QUICKSTART.md](docs/OVH_QUICKSTART.md)** (30 min)
2. Follow step-by-step guide with OVH-specific sections

### 🏠 **Existing Homelab Setup:**
1. Read: **[ARR_STACK_SETUP.md](ARR_STACK_SETUP.md)** (original comprehensive guide)
2. Use `storage-setup.sh` instead of `nfs-setup.sh` for more options

### ☁️ **Cloud VPS (AWS, DigitalOcean, Linode):**
1. Run: `bash environment-setup.sh`
2. Select "Generic VPS" option
3. Follow the generated configuration

---

## Arr Stack Configuration Files

This directory contains helper scripts and configuration examples for setting up your Arr Stack on Proxmox VE.

## 📁 Files in This Repository

### 🆕 New Scripts & Configuration (v2.0)
- **[environment-setup.sh](environment-setup.sh)** - Interactive environment setup wizard
- **[storage-setup.sh](storage-setup.sh)** - Universal storage setup (local/NFS/SMB/cloud)
- **[lib/detect-env.sh](lib/detect-env.sh)** - Environment auto-detection library
- **[tests/test-environment.sh](tests/test-environment.sh)** - Comprehensive validation (19 tests)
- **[config/environment.conf.example](config/environment.conf.example)** - Master configuration template
- **[config/ovh-static.conf](config/ovh-static.conf)** - OVH-specific profile
- **[config/homelab-dhcp.conf](config/homelab-dhcp.conf)** - Homelab profile
- **[docs/OVH_QUICKSTART.md](docs/OVH_QUICKSTART.md)** - OVH deployment guide (450+ lines!)
- **[IMPLEMENTATION_SUMMARY.md](IMPLEMENTATION_SUMMARY.md)** - Technical details of new features
- **[QUICK_REFERENCE.md](QUICK_REFERENCE.md)** - Quick command reference

### Original Documentation  
- **[ARR_STACK_SETUP.md](ARR_STACK_SETUP.md)** - Complete setup guide with step-by-step instructions

### Helper Scripts
- **[ct-add-storage.sh](ct-add-storage.sh)** - Automatically share storage with containers (now config-aware!)
- **[nfs-setup.sh](nfs-setup.sh)** - Interactive NFS storage setup script (security fixed)
- **[vpn-setup.sh](vpn-setup.sh)** - Automated WireGuard VPN container setup with Surfshark

### Configuration Examples
- **[example-configs/sonarr-radarr-paths.md](example-configs/sonarr-radarr-paths.md)** - Path configuration reference
- **[example-configs/quick-setup-checklist.md](example-configs/quick-setup-checklist.md)** - Step-by-step checklist
- **[example-configs/container-management.md](example-configs/container-management.md)** - Container commands reference
- **[example-configs/quick-reference.md](example-configs/quick-reference.md)** - One-page cheat sheet
- **[example-configs/vpn-quick-reference.md](example-configs/vpn-quick-reference.md)** - VPN management commands

### Advanced Setup Guides
- **[VPN_SPLIT_TUNNEL_SETUP.md](VPN_SPLIT_TUNNEL_SETUP.md)** - WireGuard VPN with split tunneling
- **[docs/CLEANUPARR_CLOUDFLARE_SETUP.md](docs/CLEANUPARR_CLOUDFLARE_SETUP.md)** - Cloudflare domain access for Cleanuparr  
- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical architecture deep-dive
- **[PLAN.md](PLAN.md)** - Future development roadmap

---

## 🚀 Quick Start

### Option 1: Automated Setup (Recommended for New Users)

```bash
# Clone or download the repository
git clone https://github.com/AmmarTee/ArrSuite-Guide.git
cd ArrSuite-Guide

# 1. Interactive configuration (auto-detects your setup)
bash environment-setup.sh

# 2. Validate everything is configured correctly
bash tests/test-environment.sh --skip-storage

# 3. Setup storage (if needed)
bash storage-setup.sh --auto

# 4. Create containers and deploy (requires arr-stack-deploy.sh)
bash arr-stack-deploy.sh

# 5. Mount storage to each container
for id in 100 101 102 103 104 105; do
  ct-add-storage $id --auto
done
```

### Option 2: Traditional Manual Setup

Follow the original guide for more control:

```bash
# Follow the comprehensive setup guide
cat ARR_STACK_SETUP.md

# Setup NFS storage:
bash nfs-setup.sh

# Install ct-add-storage helper:
cp ct-add-storage.sh /usr/local/bin/ct-add-storage
chmod +x /usr/local/bin/ct-add-storage
```

---

## 📊 Feature Comparison

| Feature | Homelab | OVH | Hetzner | AWS | Generic VPS |
|---------|---------|-----|---------|-----|------------|
| Network Mode | Bridged | Routed | Routed | VPC | Routed |
| Storage Type | NFS | Local | Local | EBS | Local |
| DHCP | Yes | No | No | No | No |
| Auto-Config | ✓ | ✓ | ✓ | ✓ | ✓ |
| Validation | ✓ | ✓ | ✓ | ✓ | ✓ |
| Guide | Yes | Yes* | Roadmap | Roadmap | Yes |

*OVH guide completed with 450+ lines of step-by-step instructions

---

## ⚠️ Security Updates

### Fixed: `chmod 777` Vulnerability
- **Issue:** Old `nfs-setup.sh` used world-writable permissions
- **Status:** ✅ **FIXED** in both `nfs-setup.sh` and new `storage-setup.sh`
- **Change:** `chmod 777` → `chmod 755` (secure permissions)

### Configuration Security
- Validatesall IP addresses
- Checks path accessibility before mounting
- Non-destructive (all operations are safe to test)

---

## 📚 Documentation Map

```
START HERE ↓

1) QUICK_REFERENCE.md (5 min, Overview)
   ↓
2) Choose your path:
   
   🏠 Homelab?          → ARR_STACK_SETUP.md
   🖥️ OVH Server?       → docs/OVH_QUICKSTART.md
   ☁️ Cloud VPS?        → environment-setup.sh
   🔧 First time?       → environment-setup.sh
   
3) Run setup scripts:
   environment-setup.sh → storage-setup.sh → arr-stack-deploy.sh
   
4) Reference:
   example-configs/      PLAN.md            ARCHITECTURE.md
```

---

## 🧪 Testing Your Setup

```bash
# Full validation (tests network, storage, Proxmox)
bash tests/test-environment.sh

# Verbose mode (see detailed test results)
bash tests/test-environment.sh --verbose

# Skip storage tests (if storage setup incomplete)
bash tests/test-environment.sh --skip-storage
```

Expected output on working system:
```
✓ 19 tests passed
✓ All tests passed!
Your environment is ready for ArrSuite deployment.
```

---

## 💬 Support & Contributing

- **Issues/Bugs:** [GitHub Issues](https://github.com/AmmarTee/ArrSuite-Guide/issues)
- **Discussions:** Coming soon (GitHub Discussions)
- **Reddit:** r/Proxmox, r/Sonarr, r/Radarr
- **Arr Community:** [Servarr Wiki](https://wiki.servarr.com/)

---

## 📄 License & Contributors

This project is open source and welcomes contributions!

See [CONTRIBUTING.md](CONTRIBUTING.md) (coming soon) for guidelines.

---

## 🎯 What's Inside

An **integrated media automation stack** featuring:

- 📺 **Prowlarr** - Unified indexer management
- 📺 **Sonarr** - TV show automation
- 🎬 **Radarr** - Movie automation
- 🌐 **Jellyfin** - Open-source media streaming
- ⬇️ **qBittorrent** - Torrent downloading

All running in **isolated LXC containers** on **Proxmox VE**, with automated storage mounting and network configuration.

---

## ✨ Key Features

✅ **Multi-Environment Support** - Works on homelab, OVH, cloud, and generic VPS  
✅ **Auto-Detection** - Detects your setup automatically  
✅ **Configuration Management** - Centralized settings, no hardcoding  
✅ **Universal Storage** - Supports local, NFS, SMB, and cloud block storage  
✅ **Validation Testing** - 19 comprehensive tests included  
✅ **Security-First** - Proper permissions, input validation  
✅ **Well-Documented** - 450+ line  OVH guide + inline help  
✅ **Production-Ready** - Tested on actual OVH infrastructure  

---

## 🎓 Learning Resources

- **[ARCHITECTURE.md](ARCHITECTURE.md)** - Technical deep-dive
- **[PLAN.md](PLAN.md)** - Future roadmap and enhancements
- **[example-configs/](example-configs/)** - Practical configuration examples
- **[ARR_STACK_SETUP.md](ARR_STACK_SETUP.md)** - Complete original guide

---

**Last Updated:** February 14, 2026  
**Status:** Production-Ready ✅  
**Tested On:** Proxmox VE 8.x | OVH Dedicated Server | Homelab  

---

## 🚀 Ready to Deploy?

1. **Quick users:** `bash environment-setup.sh`
2. **OVH users:** Read `docs/OVH_QUICKSTART.md`
3. **Detailed guide:** See `ARR_STACK_SETUP.md`
4. **Validation:** Run `bash tests/test-environment.sh`
   See [VPN_SPLIT_TUNNEL_SETUP.md](VPN_SPLIT_TUNNEL_SETUP.md) for details

## 📚 What You'll Learn

- How to set up NFS storage for Proxmox
- How to install and configure Prowlarr, Sonarr, Radarr, qBittorrent, Jellyfin, and Jellyseerr
- How to set up WireGuard VPN for selective traffic routing (split tunneling)
- How to connect all services together
- How to troubleshoot common issues
- Best practices for media automation

## 🎯 End Result

A fully automated media system where:
- Users request content via Jellyseerr
- Sonarr/Radarr automatically search and download
- qBittorrent handles downloads
- Content is automatically organized
- Jellyfin streams to any device

## 💡 Support

If you found this helpful:
- ⭐ Star the repository on [GitHub](https://github.com/AmmarTee/ArrSuite-Guide)
- 📢 Share with others
- 🐛 Open an issue for problems or improvements

## 📖 Additional Resources

- [TRaSH Guides](https://trash-guides.info/) - Detailed configuration guides
- [Servarr Wiki](https://wiki.servarr.com/) - Official documentation
- [Proxmox Community Scripts](https://github.com/community-scripts/ProxmoxVE) - Container installation scripts

---

**Disclaimer:** This setup is for educational purposes. Only download content you have the legal right to access.
