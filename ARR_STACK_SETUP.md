<div align="center">

# Arr Stack Setup Guide for Proxmox VE

[![GitHub](https://img.shields.io/badge/GitHub-ArrSuite--Guide-blue?logo=github)](https://github.com/AmmarTee/ArrSuite-Guide)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](https://opensource.org/licenses/MIT)
[![Proxmox](https://img.shields.io/badge/Proxmox-VE-orange?logo=proxmox)](https://www.proxmox.com/)

**A minimal, developer-friendly guide to setting up a complete media automation stack on Proxmox using LXC containers.**

[Installation Flow](#-complete-installation-flow) • [Quick Reference](#-quick-reference) • [Troubleshooting](#-troubleshooting) • [Resources](#-resources)

</div>

---

## 📦 Included Files

This guide includes helper scripts and configuration examples:

- 📝 **[Quick Setup Checklist](example-configs/quick-setup-checklist.md)** - Don't miss any steps!
- 📁 **[Path Configuration Guide](example-configs/sonarr-radarr-paths.md)** - Exact paths to use
- 🔧 **[ct-add-storage.sh](ct-add-storage.sh)** - Automatic storage mounting script
- 🗄️ **[nfs-setup.sh](nfs-setup.sh)** - Interactive NFS setup

---

## 📋 Overview

This guide uses [Proxmox VE Community Scripts](https://github.com/community-scripts/ProxmoxVE) to deploy each service as a lightweight LXC container. Each container is isolated, resource-efficient, and easy to manage.

**What is an Arr Stack?** Think of it as your personal Netflix automation system. It automatically finds, downloads, organizes, and serves your media content without manual intervention.

## ✅ Prerequisites

- Proxmox VE host with root access (your server/computer running Proxmox)
- Network connectivity (containers will auto-configure networking)
- Shared storage for media files - NFS or local storage (22TB+ recommended)
- Basic Linux command line knowledge

## 📁 Recommended Folder Structure

Before setting up services, create this folder structure on your storage:

```
/mnt/cold-storage/           # Your NFS or main storage mount
├── downloads/               # Incomplete downloads (qBittorrent)
│   ├── complete/           # Completed downloads
│   └── incomplete/         # In-progress downloads
├── ready/                  # Organized media ready for streaming
│   ├── movies/            # Movies library (Radarr manages this)
│   ├── tv/                # TV shows library (Sonarr manages this)
│   └── adult/             # Adult content (Whisparr manages this)
└── torrents/              # .torrent files and session data
```

**Why this structure?** Having consistent paths across all services prevents confusion and allows seamless file transfers between downloading, organizing, and streaming.

---

## 🗄️ Setting Up NFS Storage (Shared Storage)

**What is NFS?** Network File System (NFS) lets multiple computers (or containers) access the same files over a network. Think of it like Dropbox, but on your local network.

### Option 1: Using an Existing NFS Server

If you already have a NAS (like TrueNAS, Synology, QNAP) with NFS enabled:

#### Step 1: Mount NFS on Proxmox Host

```bash
# Install NFS client tools
apt update && apt install nfs-common -y

# Create mount point
mkdir -p /mnt/cold-storage

# Mount the NFS share (replace with your NAS IP and path)
mount -t nfs 192.168.1.200:/nfs/Proxmox /mnt/cold-storage
```

#### Step 2: Make it Permanent

Add to `/etc/fstab` so it mounts automatically on reboot:

```bash
# Edit fstab
nano /etc/fstab

# Add this line (adjust IP and path for your setup):
192.168.1.200:/nfs/Proxmox /mnt/cold-storage nfs defaults,_netdev 0 0

# Save: CTRL+O, Enter, then CTRL+X to exit
```

#### Step 3: Test the Mount

```bash
# Unmount
umount /mnt/cold-storage

# Mount using fstab
mount -a

# Verify it worked
df -h | grep cold-storage
```

You should see something like:
```
192.168.1.200:/nfs/Proxmox   22T  5.4T   17T  26% /mnt/cold-storage
```

### Option 2: Using Local Storage

If you have a large local disk attached to Proxmox:

```bash
# Format the disk (WARNING: This erases all data! Skip if already formatted)
mkfs.ext4 /dev/sdb1

# Create mount point
mkdir -p /mnt/cold-storage

# Mount the disk
mount /dev/sdb1 /mnt/cold-storage

# Add to /etc/fstab for automatic mounting
echo "/dev/sdb1 /mnt/cold-storage ext4 defaults 0 0" >> /etc/fstab
```

### Creating the ct-add-storage Helper Script

This script automatically shares your storage with containers:

```bash
# Create the script
nano /usr/local/bin/ct-add-storage
```

Paste this content:

```bash
#!/bin/bash
# Add storage mounts to a container
# Usage: ct-add-storage <vmid>

if [ -z "$1" ]; then
    echo "Usage: ct-add-storage <vmid>"
    echo "Example: ct-add-storage 106"
    exit 1
fi

VMID=$1

# Check if container exists
if ! pct status "$VMID" >/dev/null 2>&1; then
    echo "Error: Container $VMID does not exist"
    exit 1
fi

echo "Adding storage mounts to CT $VMID..."

# Add cold-storage NFS mount
if pct set "$VMID" -mp0 /mnt/cold-storage,mp=/mnt/cold-storage 2>/dev/null; then
    echo "✓ Added /mnt/cold-storage"
else
    echo "✓ /mnt/cold-storage already configured or failed"
fi

echo ""
echo "Storage mounts configured for CT $VMID"
echo "Note: You may need to reboot the container for changes to take effect:"
echo "  pct reboot $VMID"
```

Make it executable:

```bash
chmod +x /usr/local/bin/ct-add-storage
```

**What does this do?** This script creates a "bind mount" - it makes your Proxmox host's `/mnt/cold-storage` folder appear inside the container at the same path. All containers see the same files.

---

## 🎯 Core Stack Components

### 1. Prowlarr - Your Indexer Manager 🔍

**What it does:** Prowlarr is like a phone book for torrent sites. Instead of manually adding torrent sites to each app, you configure them once in Prowlarr, and it shares them with all your other apps.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/prowlarr.sh)"
```

**Setup Steps:**

1. **Access Web UI:** Open `http://YOUR-PROXMOX-IP:9696` in your browser
2. **Add Indexers:** 
   - Go to `Indexers` → `Add Indexer`
   - Search for public indexers like `1337x`, `The Pirate Bay`, `RARBG`
   - Or add private trackers if you have accounts
3. **Connect to Apps (do this AFTER installing Sonarr/Radarr):**
   - Go to `Settings` → `Apps` → `Add Application`
   - Select `Sonarr` or `Radarr`
   - Prowlarr URL: `http://localhost:9696`
   - Sonarr/Radarr URL: `http://CONTAINER-IP:PORT`
   - Get API key from Sonarr/Radarr → `Settings` → `General`

> 💡 **Pro Tip:** Configure Prowlarr first, but connect it to apps AFTER you install them.

---

### 2. qBittorrent - Your Download Manager ⬇️

**What it does:** The actual downloader. When Sonarr or Radarr finds a movie/show, qBittorrent downloads it.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/qbittorrent.sh)"
```

**Add Storage:**

```bash
# Get your container ID from the installation output (usually 106)
ct-add-storage 106
pct reboot 106
```

**Setup Steps:**

1. **Access Web UI:** Open `http://YOUR-PROXMOX-IP:8080`
   - Default login: `admin` / `adminadmin`
   
2. **Change Password:**
   - Go to `Tools` → `Options` → `Web UI`
   - Change the password immediately!

3. **Configure Download Paths:**
   - Go to `Tools` → `Options` → `Downloads`
   - Default Save Path: `/mnt/cold-storage/downloads/complete`
   - Temp Path: `/mnt/cold-storage/downloads/incomplete`
   - Check "Keep incomplete torrents in:"
   - Check "Append .!qB extension to incomplete files"

4. **Create Category for Movies:**
   - Right-click in the categories section → `Add category`
   - Name: `movies`
   - Save path: `/mnt/cold-storage/downloads/complete/movies`

5. **Create Category for TV:**
   - Name: `tv`
   - Save path: `/mnt/cold-storage/downloads/complete/tv`

**Configuration File Location:**

Inside container: `/config/qBittorrent/config/qBittorrent.conf`

**Sample qBittorrent.conf:**

```ini
[Preferences]
Downloads\SavePath=/mnt/cold-storage/downloads/complete
Downloads\TempPath=/mnt/cold-storage/downloads/incomplete
Downloads\TempPathEnabled=true

[BitTorrent]
Session\DefaultSavePath=/mnt/cold-storage/downloads/complete
Session\TempPath=/mnt/cold-storage/downloads/incomplete
Session\TempPathEnabled=true
```

---

### 3. Sonarr - TV Show Automation 📺

**What it does:** Sonarr is your TV show librarian. Tell it what shows you want, and it automatically searches, downloads, and organizes them.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/sonarr.sh)"
```

**Add Storage:**

```bash
# Get container ID (usually 102)
ct-add-storage 102
pct reboot 102
```

**Setup Steps:**

1. **Access Web UI:** `http://YOUR-PROXMOX-IP:8989`

2. **Add Root Folder:**
   - `Settings` → `Media Management` → `Root Folders`
   - Add: `/mnt/cold-storage/ready/tv`
   - This is where organized TV shows will live

3. **Connect Download Client:**
   - `Settings` → `Download Clients` → `+`
   - Select `qBittorrent`
   - Name: `qBittorrent`
   - Host: `QBITTORRENT-CONTAINER-IP` (find with `pct list`)
   - Port: `8080`
   - Category: `tv` (matches what you created in qBittorrent)
   - Test and Save

4. **Indexers Auto-Added:**
   - If you configured Prowlarr correctly, indexers appear automatically
   - Check `Settings` → `Indexers`

5. **Add a TV Show:**
   - Click `Add New` → `Add Series`
   - Search for a show (e.g., "Breaking Bad")
   - Root Folder: `/mnt/cold-storage/ready/tv`
   - Quality Profile: `HD-1080p` or `Any`
   - Monitor: `All Episodes`
   - Search for Missing Episodes: ✓
   - Add Series

**Configuration File:**

Inside container: `/config/config.xml`

**Key Settings to Check:**

```bash
# Enter the container
pct enter 102

# Check config
cat /config/config.xml | grep -A 5 "DownloadClientSettings"
```

---

### 4. Radarr - Movie Automation 🎬

**What it does:** Same as Sonarr, but for movies. Your personal movie collector.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/radarr.sh)"
```

**Add Storage:**

```bash
# Get container ID (usually 101)
ct-add-storage 101
pct reboot 101
```

**Setup Steps:**

1. **Access Web UI:** `http://YOUR-PROXMOX-IP:7878`

2. **Add Root Folder:**
   - `Settings` → `Media Management` → `Root Folders`
   - Add: `/mnt/cold-storage/ready/movies`

3. **Connect Download Client:**
   - `Settings` → `Download Clients` → `+`
   - Select `qBittorrent`
   - Name: `qBittorrent`
   - Host: `QBITTORRENT-CONTAINER-IP`
   - Port: `8080`
   - Category: `movies`
   - Test and Save

4. **Add a Movie:**
   - Click `Add New` → `Add Movie`
   - Search for a movie
   - Root Folder: `/mnt/cold-storage/ready/movies`
   - Quality Profile: `HD-1080p`
   - Add Movie

**Configuration follows same pattern as Sonarr.**

---

### 5. Jellyfin - Your Media Server 📺🎬

**What it does:** Jellyfin is like your personal Netflix. It streams all your media to any device - phones, tablets, smart TVs, browsers.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh)"
```

**Add Storage:**

```bash
# Get container ID (usually 105)
ct-add-storage 105
pct reboot 105
```

**Setup Steps:**

1. **Access Web UI:** `http://YOUR-PROXMOX-IP:8096`

2. **Initial Wizard:**
   - Set your username and password
   - Skip library setup (we'll do it manually)

3. **Add Libraries:**
   - `Dashboard` → `Libraries` → `Add Media Library`
   - **For Movies:**
     - Content type: `Movies`
     - Display name: `Movies`
     - Folders: `/mnt/cold-storage/ready/movies`
     - Save
   - **For TV Shows:**
     - Content type: `Shows`
     - Display name: `TV Shows`
     - Folders: `/mnt/cold-storage/ready/tv`
     - Save

4. **Scan Libraries:**
   - `Dashboard` → `Scan All Libraries`

5. **Connect from your devices:**
   - Download Jellyfin app on your phone/TV
   - Connect to `http://YOUR-PROXMOX-IP:8096`

**Configuration:**

Inside container: `/config/` and `/config/data/`

---

### 6. Jellyseerr - Request Management 🎫

**What it does:** Gives your family/friends a nice interface to request movies and shows without accessing Sonarr/Radarr directly. Like having a suggestion box for your media server.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyseerr.sh)"
```

**Setup Steps:**

1. **Access Web UI:** `http://YOUR-PROXMOX-IP:5055`

2. **Connect to Jellyfin:**
   - Enter Jellyfin URL: `http://JELLYFIN-CONTAINER-IP:8096`
   - Sign in with your Jellyfin account

3. **Connect to Sonarr:**
   - `Settings` → `Services` → `+ Add Sonarr Server`
   - Server Name: `Sonarr`
   - Hostname/IP: `SONARR-CONTAINER-IP`
   - Port: `8989`
   - API Key: (from Sonarr `Settings` → `General`)
   - Root Folder: `/mnt/cold-storage/ready/tv`
   - Quality Profile: `HD-1080p`
   - Test and Save

4. **Connect to Radarr:**
   - `Settings` → `Services` → `+ Add Radarr Server`
   - Similar to Sonarr setup
   - Root Folder: `/mnt/cold-storage/ready/movies`

5. **Share with users:**
   - Give them the URL: `http://YOUR-PROXMOX-IP:5055`
   - They sign in with their Jellyfin account
   - They can now request content!

---

## 🔧 Optional Utilities

### Whisparr - Adult Content 🔞

**What it does:** Same as Sonarr, but for adult content.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/whisparr.sh)"
```

**Setup:** Follow the same steps as Sonarr, but use `/mnt/cold-storage/ready/adult` as root folder.

---

### Configarr - Auto-Configuration 🤖

**What it does:** Automatically configures quality profiles, naming schemes, and other settings across all *arr apps using community best practices (TRaSH Guides).

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/configarr.sh)"
```

**Setup Steps:**

1. Access Web UI (check container for port)
2. Add your Sonarr/Radarr API keys
3. Select TRaSH Guide profiles to apply
4. Apply configuration

**Why use this?** Instead of manually configuring naming schemes and quality settings, Configarr applies tested community standards automatically.

---

### Notifiarr - Notifications 📢

**What it does:** Centralized notification system. Get alerts on Discord, Telegram, or other platforms when downloads complete, requests are made, etc.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/notifiarr.sh)"
```

**Setup Steps:**

1. Sign up at [notifiarr.com](https://notifiarr.com)
2. Get your API key
3. Access container and configure with your API key
4. Configure notification channels (Discord, Telegram, etc.)
5. In each *arr app: `Settings` → `Connect` → Add `Notifiarr`

---

### Cleanuparr - Automatic Cleanup 🧹

**What it does:** Automatically removes content based on rules (watched status, age, disk space).

**Default Port:** `11011`

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/cleanuparr.sh)"
```

**Setup Steps:**

1. **Access Web UI:** Open `http://YOUR-PROXMOX-IP:11011` in your browser
2. **Connect to Media Server:**
   - Settings → Media Servers
   - Add Jellyfin/Plex/Emby
3. **Configure Rules:**
   - Settings → Rules → Add Rule
   - Example: Delete movies unwatched after 90 days
   - Example: Remove TV shows after fully watched
4. **Set Thresholds:**
   - Delete when disk usage exceeds 90%
   - Keep minimum 100GB free space

**Example Use Cases:**
- Remove movies after 90 days if not watched
- Delete shows after all episodes are watched
- Free space when storage reaches 90% capacity

**Remote Access:** Need to access Cleanuparr externally via domain (e.g., through Cloudflare)? See [docs/CLEANUPARR_CLOUDFLARE_SETUP.md](docs/CLEANUPARR_CLOUDFLARE_SETUP.md) for complete configuration guide.

---

### Huntarr - Content Discovery 🔎

**What it does:** Automatically adds popular content to your *arr apps based on trending lists, IMDb top 250, etc.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/huntarr.sh)"
```

---

### Tdarr - Transcoding 🎞️

**What it does:** Converts your media files to save space or ensure compatibility. For example, converting large 4K files to 1080p, or changing video codecs to H.265 for better compression.

**Installation:**

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/tdarr.sh)"
```

**Add Storage:**

```bash
ct-add-storage <TDARR-CONTAINER-ID>
pct reboot <TDARR-CONTAINER-ID>
```

**Setup Steps:**

1. **Access Web UI:** `http://YOUR-PROXMOX-IP:8265`
2. **Add Library:**
   - Select source folder (e.g., `/mnt/cold-storage/ready/movies`)
   - Select output folder (same location for in-place transcode)
3. **Add Transcode Rules:**
   - Navigate to `Plugins`
   - Popular: `Migz-Transcode to H265/HEVC`
   - This converts to H.265 which saves ~30-50% space
4. **Workers:**
   - Tdarr needs "workers" (processing power)
   - Install Tdarr Node on the same or different machines
   - Workers process the transcoding queue

**Warning:** Transcoding is CPU/GPU intensive. Monitor system resources.

**Warning:** Transcoding is CPU/GPU intensive. Monitor system resources.

---

## 🚀 Complete Installation Flow

### Phase 1: Foundation (30 minutes)

**Step 1: Setup Storage**

First, set up your NFS or local storage following the [NFS Setup Guide](#️-setting-up-nfs-storage-shared-storage) above.

```bash
# Create folder structure
mkdir -p /mnt/cold-storage/{downloads/{complete,incomplete},ready/{movies,tv,adult},torrents}

# Set permissions (allows containers to write)
chmod -R 777 /mnt/cold-storage
```

**Step 2: Install Prowlarr** (your indexer hub)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/prowlarr.sh)"
```

Note the container ID (e.g., 104). Access at `http://YOUR-IP:9696`

**Step 3: Install qBittorrent** (download client)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/qbittorrent.sh)"

# Add storage access
ct-add-storage 106
pct reboot 106
```

Access at `http://YOUR-IP:8080` (user: `admin`, pass: `adminadmin`)

---

### Phase 2: Content Management (20 minutes)

**Step 4: Install Sonarr** (TV shows)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/sonarr.sh)"

# Add storage
ct-add-storage 102
pct reboot 102
```

Access at `http://YOUR-IP:8989`

**Step 5: Install Radarr** (Movies)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/radarr.sh)"

# Add storage
ct-add-storage 101
pct reboot 101
```

Access at `http://YOUR-IP:7878`

---

### Phase 3: Media Server (15 minutes)

**Step 6: Install Jellyfin** (streaming server)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh)"

# Add storage
ct-add-storage 105
pct reboot 105
```

Access at `http://YOUR-IP:8096`

**Step 7: Install Jellyseerr** (request system)

```bash
bash -c "$(curl -fsSL https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyseerr.sh)"
```

Access at `http://YOUR-IP:5055`

---

### Phase 4: Configuration (30 minutes)

**Step 8: Configure Services**

Follow this order to connect everything:

1. **Prowlarr:**
   - Add 3-5 indexers (public or private trackers)
   - Note your API key from `Settings` → `General`

2. **qBittorrent:**
   - Change default password
   - Set download paths
   - Create categories: `movies`, `tv`

3. **Sonarr:**
   - Add root folder: `/mnt/cold-storage/ready/tv`
   - Add download client: qBittorrent (category: `tv`)
   - Verify indexers appeared from Prowlarr

4. **Radarr:**
   - Add root folder: `/mnt/cold-storage/ready/movies`
   - Add download client: qBittorrent (category: `movies`)
   - Verify indexers appeared from Prowlarr

5. **Prowlarr** (revisit):
   - `Settings` → `Apps` → Add Sonarr and Radarr
   - This syncs indexers automatically

6. **Jellyfin:**
   - Add library: Movies → `/mnt/cold-storage/ready/movies`
   - Add library: TV Shows → `/mnt/cold-storage/ready/tv`

7. **Jellyseerr:**
   - Connect to Jellyfin
   - Connect to Sonarr and Radarr

---

### Phase 5: Testing (10 minutes)

**Step 9: Test the Flow**

1. **In Sonarr:** Add a TV show (e.g., "Friends")
   - Click search
   - Watch it appear in qBittorrent
   - Once downloaded, it moves to `/mnt/cold-storage/ready/tv/Friends/`
   - Appears in Jellyfin automatically

2. **In Radarr:** Add a movie
   - Same process
   - Should appear in Jellyfin after download

3. **In Jellyseerr:** Request content
   - Search for a movie/show
   - Request it
   - Watch it appear in Sonarr/Radarr
   - Track progress in Download Queue

**Success!** 🎉 You now have a fully automated media system!

---

## 🔄 How It All Works Together

Here's the complete flow when someone requests a movie:

```
User requests movie in Jellyseerr
         ↓
Jellyseerr tells Radarr to add it
         ↓
Radarr searches indexers (via Prowlarr)
         ↓
Radarr finds best release and sends to qBittorrent
         ↓
qBittorrent downloads to: /mnt/cold-storage/downloads/complete/movies/
         ↓
Radarr detects completed download
         ↓
Radarr moves/renames to: /mnt/cold-storage/ready/movies/Movie Name (Year)/
         ↓
Jellyfin scans library and finds new movie
         ↓
User can now watch in Jellyfin!
```

**Total time: 5 minutes to 2 hours** (depending on download speed)

---

##  Finding Container IPs

From Proxmox host:

```bash
# List all containers with IPs
pct list

# Get specific container IP
pct exec <CTID> -- ip addr show
```

## 📊 Quick Reference

| Service | Default Port | Purpose |
|---------|--------------|---------|
| Prowlarr | 9696 | Indexer management |
| Sonarr | 8989 | TV automation |
| Radarr | 7878 | Movie automation |
| Whisparr | 6969 | Adult content |
| qBittorrent | 8080 | Download client |
| Jellyfin | 8096 | Media server |
| Jellyseerr | 5055 | Request management |
| Tdarr | 8265 | Transcoding |

**📄 Need a printable version?** See the [Quick Reference Sheet](example-configs/quick-reference.md) for a one-page cheat sheet!

**🔧 Container commands?** Check [Container Management Guide](example-configs/container-management.md) for all Proxmox commands.

## ⚡ Common Commands

```bash
# Enter container shell
pct enter <CTID>

# Restart container
pct reboot <CTID>

# Stop/Start container
pct stop <CTID>
pct start <CTID>

# Update Proxmox host
apt update && apt dist-upgrade -y
```

## 🎬 Bare Minimum Setup

For a functional basic stack, follow the **Phase 1-3** in the [Complete Installation Flow](#-complete-installation-flow):

**Essential Services (4 containers):**

1. ✅ **Prowlarr** (Port 9696) - Indexer management → [Detailed Setup](#1-prowlarr---your-indexer-manager-)
2. ✅ **qBittorrent** (Port 8080) - Downloads → [Detailed Setup](#2-qbittorrent---your-download-manager-️)
3. ✅ **Radarr** OR **Sonarr** (Ports 7878/8989) - Content management → [Movies](#4-radarr---movie-automation-) | [TV](#3-sonarr---tv-show-automation-)
4. ✅ **Jellyfin** (Port 8096) - Media playback → [Detailed Setup](#5-jellyfin---your-media-server-)

**Total Setup Time:** ~60-90 minutes for first-time setup

**What you get:**
- Automatic content discovery and downloading
- Organized media library
- Stream to any device (phone, tablet, TV, browser)

**Next steps after basics:**
- Add Jellyseerr for user requests
- Add Notifiarr for notifications
- Fine-tune quality profiles

## 💡 Tips

- **Storage Paths**: Use consistent paths across all containers (e.g., `/media/downloads`, `/media/movies`, `/media/tv`)
- **Resource Allocation**: LXC containers are lightweight - 1GB RAM per container is usually sufficient
- **Networking**: Containers get DHCP by default; set static IPs in Proxmox for stability
- **Backups**: Use Proxmox built-in backup for easy restoration
- **Updates**: Services auto-update or can be updated via their web UI

## 🐛 Troubleshooting

### "Can't access web UI"

**Problem:** Can't reach service at `http://IP:PORT`

**Solutions:**

```bash
# 1. Check if container is running
pct status <CTID>

# If stopped, start it
pct start <CTID>

# 2. Check container logs
pct enter <CTID>
journalctl -xe

# 3. Verify service is running inside container
pct enter <CTID>
ps aux | grep -i prowlarr  # or sonarr, radarr, etc.

# 4. Check firewall (if enabled)
iptables -L | grep <PORT>

# 5. Test from Proxmox host
curl http://localhost:<PORT>
```

---

### "Permission denied" errors

**Problem:** Services can't read/write to `/mnt/cold-storage`

**Solutions:**

```bash
# 1. Check NFS mount
df -h | grep cold-storage

# 2. Check permissions
ls -la /mnt/cold-storage

# 3. Fix permissions
chmod -R 777 /mnt/cold-storage
# Or more secure (if you know container UIDs):
chown -R 1000:1000 /mnt/cold-storage

# 4. Inside container, verify mount exists
pct enter <CTID>
ls -la /mnt/cold-storage
```

---

### "Sonarr/Radarr can't find downloads"

**Problem:** Download completes but doesn't import

**Checklist:**

1. **Same paths everywhere:**
   ```bash
   # In qBittorrent: /mnt/cold-storage/downloads/complete/tv
   # In Sonarr: /mnt/cold-storage/downloads/complete/tv
   # Must be IDENTICAL
   ```

2. **Check Sonarr Activity:**
   - Go to `Activity` → `Queue`
   - Look for import errors

3. **Manual Import:**
   - `Activity` → `Manual Import`
   - Select `/mnt/cold-storage/downloads/complete`
   - See what files are pending

4. **Check Download Client Settings:**
   - `Settings` → `Download Clients` → Edit qBittorrent
   - Remote Path Mapping usually NOT needed if paths match
   - Category must match (tv/movies)

---

### "Indexers failing in Prowlarr"

**Problem:** Searches return no results or errors

**Solutions:**

1. **Check indexer status:**
   - Some public indexers go down frequently
   - Try different indexers

2. **Wait for rate limits:**
   - Many indexers limit requests (e.g., 1 search per 10 seconds)
   - Wait and retry

3. **Check indexer settings:**
   - Some require cookies or API keys
   - Verify credentials are correct

---

### "Jellyfin library not updating"

**Problem:** New media doesn't appear

**Solutions:**

```bash
# 1. Manual scan
# In Jellyfin: Dashboard → Scan All Libraries

# 2. Check library paths
# Dashboard → Libraries → Edit
# Verify path is: /mnt/cold-storage/ready/movies

# 3. Check file permissions
pct enter <JELLYFIN-CTID>
ls -la /mnt/cold-storage/ready/movies

# 4. Enable automatic library scan
# Dashboard → Scheduled Tasks → Scan Media Library → Every 10 minutes
```

---

### "Container won't start after reboot"

**Problem:** NFS mount fails, container fails to start

**Solutions:**

```bash
# 1. Check NFS is mounted on host
df -h | grep cold-storage

# If not mounted:
mount -a

# 2. Add _netdev to fstab to wait for network
nano /etc/fstab
# Add _netdev option:
192.168.1.200:/nfs/Proxmox /mnt/cold-storage nfs defaults,_netdev 0 0

# 3. Start container
pct start <CTID>
```

---

### "High CPU usage / System slow"

**Problem:** One service consuming too many resources

**Solutions:**

```bash
# 1. Check what's using CPU
htop

# 2. Limit container resources
pct set <CTID> -cores 2 -memory 2048

# 3. If Tdarr is transcoding, pause workers

# 4. Check qBittorrent connections
# In qBittorrent: Tools → Options → Connection
# Limit global connections to 500
# Limit per-torrent to 100
```

---

### "Downloads are slow"

**Problem:** Torrents downloading slowly

**Solutions:**

1. **Check seeders:**
   - In Sonarr/Radarr, look for releases with more seeders
   - Adjust quality profiles to prefer releases with >10 seeders

2. **Port forwarding:**
   - Forward port 6881-6889 to your qBittorrent container IP
   - In qBittorrent: Tools → Options → Connection
   - Enable UPnP or set port manually

3. **VPN issues:**
   - If using VPN, it may slow downloads
   - Consider split tunneling or VPN with good speeds

---

### Common Error Messages

| Error | Meaning | Fix |
|-------|---------|-----|
| "No indexers available" | Prowlarr not connected | Add indexers to Prowlarr, sync to Sonarr/Radarr |
| "Download client unavailable" | Can't reach qBittorrent | Check qBittorrent container is running |
| "Import failed: No files found" | Path mismatch | Verify paths match exactly in all apps |
| "Unable to connect to indexer" | Indexer offline or blocked | Try different indexer or check IP not banned |
| "Quality not met" | Download quality below threshold | Adjust quality profile or wait for better release |

---

## 📝 Configuration File Reference

### Location of Config Files

All containers store configs in `/config/`:

```bash
# Prowlarr
pct enter 104
cat /config/config.xml

# Sonarr
pct enter 102
cat /config/config.xml

# Radarr
pct enter 101
cat /config/config.xml

# qBittorrent
pct enter 106
cat /config/qBittorrent/config/qBittorrent.conf

# Jellyfin
pct enter 105
ls /config/
```

### Backup Important Files

```bash
# Create backup directory
mkdir -p /mnt/cold-storage/backups

# Backup all arr configs
for ctid in 101 102 104; do
    pct enter $ctid -c "tar czf /mnt/cold-storage/backups/ct${ctid}-config.tar.gz /config/"
done

# Restore example
pct enter 102
cd /
tar xzf /mnt/cold-storage/backups/ct102-config.tar.gz
```

---

## � Pro Tips & Best Practices

### Storage Optimization

- **Storage Paths**: Use consistent paths across all containers (e.g., `/mnt/cold-storage/downloads`, `/mnt/cold-storage/ready`)
- **Hardlinks vs Copy**: Configure Sonarr/Radarr to use hardlinks instead of copy/move:
  - `Settings` → `Media Management` → Enable "Use Hardlinks instead of Copy"
  - Saves disk space (same file, multiple directory entries)
  - Only works if downloads and media are on the same filesystem

### Resource Allocation

- **LXC containers are lightweight** - 1-2GB RAM per container is usually sufficient
- **CPU cores**: 2 cores per container works well
- **Storage**: Container OS needs only 8GB, media storage separate

### Networking

- **Static IPs**: Containers get DHCP by default; set static IPs in Proxmox for stability
  - Edit container: `Datacenter` → `Container` → `Network`
- **Firewall**: Configure Proxmox firewall if you need external access
- **Reverse Proxy**: Consider using Nginx Proxy Manager for SSL and domains

### Backups

- **Use Proxmox built-in backup** for easy restoration:
  ```bash
  # Backup a container
  vzdump <CTID> --storage local --compress zstd
  
  # Automated backups
  # Datacenter → Backup → Add job
  ```
- **Backup configs separately**: Keep `/config/` directories backed up to NFS

### Updates

- **Services auto-update** or can be updated via their web UI
- **Container OS updates**:
  ```bash
  pct enter <CTID>
  apt update && apt upgrade -y
  ```

### Security

- **Change default passwords** immediately (especially qBittorrent)
- **API keys**: Keep them safe, they're like passwords
- **Network isolation**: Consider separate VLAN for media stack
- **VPN**: Route qBittorrent through VPN for privacy

### Quality Settings

- **Start with "Any" quality profile** to test the system
- **Upgrade later** to HD-1080p or 4K once it's working
- **Use TRaSH Guides** (or Configarr) for optimal quality profiles
- **Custom formats**: In Sonarr/Radarr, set custom formats to prefer:
  - Proper/Repack releases
  - Releases with more seeders
  - Groups you trust

### Monitoring

- **Check Sonarr/Radarr System Status**:
  - `System` → `Status` (shows health checks)
- **Monitor disk space**:
  ```bash
  df -h
  ```
- **Set up notifications** via Notifiarr for:
  - Download failures
  - Disk space warnings
  - Update available

---

## 📚 Resources

### Official Documentation

- [Proxmox VE Community Scripts](https://github.com/community-scripts/ProxmoxVE) - Official installation scripts
- [Servarr Wiki](https://wiki.servarr.com/) - Official *arr documentation
- [Jellyfin Docs](https://jellyfin.org/docs/) - Jellyfin documentation

### Configuration Guides

- [TRaSH Guides](https://trash-guides.info/) - **Best resource** for detailed *arr configuration
  - Quality profiles
  - Custom formats
  - Naming schemes
  - Best practices
- [Sonarr Quality Definitions](https://trash-guides.info/Sonarr/Sonarr-Quality-Settings-File-Size/)
- [Radarr Quality Definitions](https://trash-guides.info/Radarr/Radarr-Quality-Settings-File-Size/)

### Community Support

- [r/Radarr](https://www.reddit.com/r/radarr/) - Radarr subreddit
- [r/Sonarr](https://www.reddit.com/r/sonarr/) - Sonarr subreddit
- [r/Jellyfin](https://www.reddit.com/r/jellyfin/) - Jellyfin subreddit
- [r/Proxmox](https://www.reddit.com/r/Proxmox/) - Proxmox support
- [Servarr Discord](https://discord.gg/servarr) - Official Discord server

### Video Tutorials

- Search YouTube for "Proxmox Arr Stack" for visual guides
- [TRaSH Guides YouTube](https://www.youtube.com/@TRaSHGuides) - Configuration tutorials

### Useful Tools

- [Notepad++](https://notepad-plus-plus.org/) - For editing config files
- [WinSCP](https://winscp.net/) - GUI for file transfers (Windows)
- [MobaXterm](https://mobaxterm.mobatek.net/) - Advanced SSH client (Windows)

---

## 🎓 Glossary (Layman's Terms)

| Term | What it means |
|------|---------------|
| **Arr Stack** | Collection of apps (Sonarr, Radarr, etc.) that automate media downloading |
| **LXC Container** | Lightweight virtual machine (uses less resources than full VM) |
| **Indexer** | Website that lists available torrents (like a search engine for torrents) |
| **Download Client** | Program that downloads torrents (qBittorrent, Transmission, etc.) |
| **Root Folder** | Main folder where media is stored (e.g., /mnt/cold-storage/ready/movies) |
| **Quality Profile** | Rules for what quality to download (720p, 1080p, 4K, etc.) |
| **Custom Format** | Advanced rules to prefer certain releases (codec, group, etc.) |
| **API Key** | Password that lets apps talk to each other |
| **Bind Mount** | Making host folder appear inside container |
| **NFS** | Network File System - share files over network |
| **Hardlink** | File that exists in multiple locations without copying (saves space) |
| **Transcode** | Convert video to different format/quality |
| **Seeders** | Number of people sharing a torrent (more = faster download) |
| **CTID/VMID** | Container ID number in Proxmox |

---

## ❓ FAQ

**Q: Is this legal?**  
A: The software is legal. What you download is your responsibility. Use only content you own or have rights to.

**Q: Do I need a VPN?**  
A: Depends on your country's laws and your ISP. Many users route qBittorrent through a VPN for privacy.

**Q: How much storage do I need?**  
A: Depends on usage. 2TB is a minimum, 10TB+ is comfortable for a large library.

**Q: Can I use Docker instead of LXC?**  
A: Yes, but LXC containers use fewer resources on Proxmox. Docker works too.

**Q: What if my NAS is off when Proxmox boots?**  
A: Add `_netdev` to fstab (covered in NFS setup). This waits for network before mounting.

**Q: Can I run this on a Raspberry Pi?**  
A: Not Proxmox, but you can run these same apps via Docker on a Pi.

**Q: How do I add more storage later?**  
A: Mount new storage, update paths in all services, move existing media.

**Q: My downloads are stuck at 99%**  
A: Check if qBittorrent has write permissions. Check disk space.

**Q: Can I share my Jellyfin with friends remotely?**  
A: Yes, but you need port forwarding or a reverse proxy with SSL. Security considerations apply.

**Q: How do I update services?**  
A: Most auto-update. Or manually: Service Settings → Updates → Install.

---

## 🌟 What's Next?

Once your basic stack is running, consider:

1. **Better Quality Profiles** - Use TRaSH Guides or Configarr
2. **Notifications** - Set up Notifiarr or Discord webhooks
3. **Request System** - Let family request content via Jellyseerr
4. **Automated Cleanup** - Use Cleanuparr to manage disk space
5. **Transcoding** - Set up Tdarr to optimize file sizes
6. **Hardware Acceleration** - Add GPU passthrough to Jellyfin for smooth 4K playback
7. **Reverse Proxy** - Use Nginx Proxy Manager for pretty URLs and SSL
8. **Monitoring** - Add Grafana + Prometheus for system metrics
9. **Lists** - Auto-add trending content with Huntarr
10. **Backups** - Automate config backups to prevent data loss

---

<div align="center">

**This setup runs each service in isolated LXC containers for maximum efficiency and security on Proxmox VE.**

### 🌟 Found this helpful? Give it a star on [GitHub](https://github.com/AmmarTee/ArrSuite-Guide)!

*Last updated: February 2026*

</div>
