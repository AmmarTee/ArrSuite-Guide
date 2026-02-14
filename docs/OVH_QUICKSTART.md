# OVH Dedicated Server - ArrSuite Quick Start Guide

## Overview

This guide will help you deploy the complete ArrSuite media automation stack on an OVH dedicated server with static IP configuration.

**What is ArrSuite?**
A complete media management solution featuring:
- **Prowlarr** - Unified indexer manager
- **Sonarr** - TV show management
- **Radarr** - Movie management
- **qBittorrent** - Torrent client
- **Jellyfin** - Media streaming server

**OVH Setup Advantages:**
- ✓ Full dedicated hardware (no virtualization overhead)
- ✓ Generous bandwidth and storage
- ✓ Static IP assignments
- ✓ Anti-DDoS protection included
- ✓ Supports vRack for private networking

---

## Prerequisites

### Hardware Requirements

**Minimum for OVH Standard Server:**
- 4+ CPU cores
- 16GB+ RAM
- 500GB+ SSD storage
- Adequate bandwidth for media streaming

**OVH Server Examples That Work:**
- OVH Rise (RP-2C-16GB-500SSD) - Good entry level
- OVH Advance (RP-2C-32GB-1000SSD) - Recommended
- OVH High Grade (RP-4C-64GB-2000SSD) - Excellent

### Pre-Deployment Checklist

- [ ] Order OVH dedicated server
- [ ] Server is online and accessible via SSH
- [ ] Proxmox VE 8.x is installed (OVH provides ISO options)
- [ ] You have root/sudo access via SSH
- [ ] Stable internet connection
- [ ] At least one additional static IP allocated (for containers)

### Your OVH Server Details (Write These Down)

```
Server IP:          _______________
Netmask:            _______________
Gateway:            _______________
MAC Address:        _______________
Hostname:           _______________
OVH Control Panel:  https://www.ovh.com/
```

---

## Step 1: Access Your OVH Server

### Connect via SSH

```bash
ssh root@YOUR_SERVER_IP
```

### Verify Proxmox Installation

```bash
# Check Proxmox is running
pvesh get /version

# Should output something like:
# {
#   "version": "8.x.x",
#   ...
# }
```

### Update System

```bash
apt-get update && apt-get upgrade -y
```

---

## Step 2: Get ArrSuite Scripts

### Clone or Download Repository

**Option A: Clone from Git**
```bash
cd /root
git clone https://github.com/AmmarTee/ArrSuite-Guide.git
cd ArrSuite-Guide
```

**Option B: Download ZIP**
```bash
cd /root
wget https://github.com/AmmarTee/ArrSuite-Guide/archive/refs/heads/main.zip
unzip main.zip
cd ArrSuite-Guide-main
```

### Verify Files

```bash
ls -la
# Should see:
# - environment-setup.sh
# - storage-setup.sh
# - ct-add-storage.sh
# - vpn-setup.sh
# - lib/detect-env.sh
# - config/ovh-static.conf
# - tests/test-environment.sh
```

---

## Step 3: Configure Your Environment

### Run Environment Setup

```bash
bash environment-setup.sh
```

This interactive script will:
1. **Auto-detect** your OVH server configuration
2. **Ask clarifying questions** about your setup
3. **Detect available IPs** and storage
4. **Create environment.conf** with your settings

### Expected Prompts:

```
1. Environment Detection
   ✓ Status: OVH Detected
   
2. Configuration Profile
   - OVH Static IP configuration loaded
   
3. Network Configuration
   - Primary IP: 1.2.3.4
   - Gateway: 1.2.3.254
   - Subnet: 1.2.3.0/24
   
4. Storage Configuration
   - Type: Local (OVH doesn't provide NAS)
   - Mount Point: /srv/media
   
5. Proxmox Configuration
   - Container IDs: 100-120
   - CPU per container: 2 cores
   - RAM per container: 2048 MB
```

### Verify Configuration

```bash
cat config/environment.conf
```

---

## Step 4: Prepare Storage

OVH servers typically have secondary storage available. We'll format and mount it.

### Check Available Disks

```bash
lsblk
```

You should see:
- `sda` or `nvme0n1` - Your primary disk (Proxmox)
- `sdb` or `nvme1n1` - Secondary disk (for media storage)

### Setup Storage

```bash
bash storage-setup.sh --auto
```

This script will:
1. Detect your secondary disk
2. Ask for confirmation (will format!)
3. Create filesystem (ext4)
4. Mount to `/srv/media`
5. Add to fstab for persistence

### Verify Storage

```bash
df -h /srv/media
# Should show: /dev/sdb mounted at /srv/media

ls -la /srv/media
# Should show: downloads, incomplete, tv, movies, etc folders
```

---

## Step 5: Create Proxmox Containers

### Run Deployment Script

The main deployment script creates and configures all containers with proper networking and storage.

```bash
bash arr-stack-deploy.sh
```

**Note:** If this script doesn't exist, use the manual container creation steps below.

### Manual Container Creation (If Needed)

Create each container with static IP from your OVH subnet:

**Example: Create Prowlarr Container (ID 101)**
```bash
pct create 101 \
  --hostname prowlarr \
  --memory 1024 \
  --cores 1 \
  --storage local-lvm \
  --ostype debian \
  --net0 name=eth0,ip=1.2.3.10/24,gw=1.2.3.254,bridge=vmbr0
```

**Example: Create Sonarr Container (ID 102)**
```bash
pct create 102 \
  --hostname sonarr \
  --memory 2048 \
  --cores 2 \
  --storage local-lvm \
  --ostype debian \
  --net0 name=eth0,ip=1.2.3.11/24,gw=1.2.3.254,bridge=vmbr0
```

Repeat for:
- Radarr (103)
- qBittorrent (104)
- Jellyfin (105)

### Verify Containers are Running

```bash
pct list
# Should show all containers with status "running"
```

---

## Step 6: Mount Storage to Containers

### Add Storage Mount to Each Container

```bash
ct-add-storage 100 --auto
ct-add-storage 101 --auto
ct-add-storage 102 --auto
ct-add-storage 103 --auto
ct-add-storage 104 --auto
ct-add-storage 105 --auto
```

### Verify Mount

```bash
# Check storage is visible in container
pct exec 101 -- ls -la /srv/media
# Should show media folders: downloads, tv, movies, etc
```

---

## Step 7: Validate Everything

### Run Environment Tests

```bash
bash tests/test-environment.sh
```

**Expected Output:**
```
✓ Configuration file valid
✓ Network connectivity - gateway reachable
✓ Internet connectivity - working
✓ Storage mount point exists
✓ Storage read/write test passed
✓ Proxmox tools installed
✓ Can list containers
✓ OVH environment detected
```

If any test fails, review the error message and fix before continuing.

---

## Step 8: IP Address Registration (Important for OVH)

For each container IP you created, you must register it with OVH:

### Get Container MAC Address

```bash
pct config 101 | grep hwaddr
# Output: hwaddr: aa:bb:cc:dd:ee:01
```

### Add to OVH Control Panel

1. Go to: https://www.ovh.com/
2. Login with your credentials
3. Navigate to: Bare Metal Cloud → Your Server
4. Go to: IP Management
5. Click "Add IP"
6. Enter:
   - IP Address: 1.2.3.10
   - MAC Address: aa:bb:cc:dd:ee:01
   - VLAN: (leave empty unless using vRack)
7. Click "Apply"
8. **Wait 5-10 minutes for propagation**

### Repeat for Each Container IP

Repeat steps above for each container's IP and MAC address.

**Troubleshooting if IPs don't work:**
- Verify MAC address format (with colons)
- Check OVH control panel Applied status
- Wait full 10 minutes after adding
- Reboot container: `pct reboot 101`

---

## Step 9: Test Network Connectivity

### From Proxmox Host

```bash
# Test each container is reachable
ping -c 3 1.2.3.10  # Prowlarr
ping -c 3 1.2.3.11  # Sonarr
ping -c 3 1.2.3.12  # Radarr
ping -c 3 1.2.3.13  # qBittorrent
ping -c 3 1.2.3.14  # Jellyfin
```

### From Inside a Container

```bash
# Access container shell
pct enter 101

# Test internet from inside
ping 8.8.8.8

# Test storage
ls /srv/media
df -h /srv/media

# Exit
exit
```

---

## Step 10: Configure OVH Anti-DDoS (Optional)

OVH provides included Anti-DDoS protection. To configure:

1. Login to OVH Control Panel
2. Navigate to: Bare Metal Cloud → Your Server
3. Click: Anti-DDoS
4. Configure protection level:
   - **Normal** - Basic protection (default, recommended)
   - **High** - More aggressive filtering (may impact legitimate traffic)
   - **Auto** - Automatic mode

---

## Accessing Your Services

### From OVH Network (Internal)

Each service runs on port 8000-8005:

```
Prowlarr:    http://1.2.3.10:8080
Sonarr:      http://1.2.3.11:8989
Radarr:      http://1.2.3.12:7878
qBittorrent: http://1.2.3.13:8080
Jellyfin:    http://1.2.3.14:8096
```

### From External Network (For Remote Access)

Option A: Direct IP (requires port forwarding or firewall rules)
```
http://1.2.3.10:8080
```

Option B: Use Reverse Proxy (recommended)
- Install Nginx/Caddy on host
- Create vhost for each service
- Use domain names with SSL

Option C: VPN Access
- Deploy WireGuard container: `bash vpn-setup.sh`
- Connect via VPN
- Access internal IPs securely

---

## Troubleshooting OVH-Specific Issues

### Container IP Not Reachable

**Symptoms:** `ping 1.2.3.10` hangs/times out

**Solutions:**
1. Verify MAC registered in OVH panel
2. Check IP is not conflicting with gateway
3. Reboot container: `pct reboot 101`
4. Check Proxmox network config
5. Verify OVH firewall isn't blocking

### Anti-DDoS Blocking Legitimate Traffic

**Symptoms:** Services intermittently unavailable

**Solutions:**
1. Lower Anti-DDoS protection level in OVH panel
2. Whitelist your IPs if accessing from fixed location
3. Contact OVH support if issue persists

### Storage I/O Issues

**Symptoms:** Slow file access, timeouts

**Solutions:**
1. Check disk health: `smartctl -a /dev/sdb`
2. Monitor disk usage: `df -h`
3. Check RAID status (if applicable): `cat /proc/mdstat`
4. Look for hardware issues in OVH panel

### Internet Connectivity Issues

**Symptoms:** Cannot reach external network

**Solutions:**
1. Check gateway is reachable: `ping 1.2.3.254`
2. Check DNS: `nslookup google.com`
3. Verify default route: `ip route show`
4. Contact OVH support for network issues

---

## Performance Tips for OVH

### Optimize Container Resources

Adjust based on your server specs:

```bash
# For high-end server (64GB+ RAM)
CONTAINER_RAM="4096"    # 4GB per service
CONTAINER_CPU="4"       # 4 cores per service

# For basic server (16GB RAM)
CONTAINER_RAM="2048"    # 2GB per service
CONTAINER_CPU="2"       # 2 cores per service
```

### Enable CPU Governor

```bash
# Set to performance mode for better throughput
echo "performance" > /sys/devices/system/cpu/cpu0/cpufreq/scaling_governor
```

### Monitor Resource Usage

```bash
# Watch container stats
while true; do
  clear
  pct list
  pct status
  sleep 2
done
```

---

## Maintenance

### Regular Updates

```bash
# Update OVH host OS
apt-get update && apt-get upgrade -y

# Update Proxmox
apt-get install proxmox-ve
```

### Backup Important Data

```bash
# If using local storage, backup media regularly
rsync -avz /srv/media/ /backup/media/
```

### Monitor Disk Space

```bash
# Check disk usage
df -h

# Monitor in real-time
watch -n 5 'df -h'
```

---

## Next Steps

1. ✓ Deploy ArrSuite services
2. ✓ Configure arr applications (Sonarr, Radarr, etc.)
3. ✓ Add indexers to Prowlarr
4. ✓ Add download client (qBittorrent)
5. ✓ Configure media libraries in Jellyfin
6. ✓ Set up reverse proxy for external access
7. ✓ Enable VPN forwarding (optional)

---

## Support & Help

### Get Help
- **GitHub Issues:** https://github.com/AmmarTee/ArrSuite-Guide/issues
- **Reddit:** r/Proxmox, r/sonarr, r/radarr
- **OVH Support:** Contact OVH for infrastructure issues

### Useful Commands

```bash
# View Proxmox Web UI
# Open browser to: https://YOUR_SERVER_IP:8006

# Access container shell
pct enter 101

# View container logs
pct exec 101 -- journalctl -u arrservice -n 50

# Reboot container
pct reboot 101

# Stop container
pct stop 101

# Start container
pct start 101

# List all containers
pct list
```

---

## OVH Resources

- **OVH Control Panel:** https://www.ovh.com/
- **OVH Documentation:** https://docs.ovh.com/
- **OVH Support:** https://www.ovh.com/support/
- **Proxmox Documentation:** https://pve.proxmox.com/

---

**Happy Streaming! 🎬**

*Last Updated: February 14, 2026*
*For OVH Dedicated Servers with Proxmox VE 8.x*
