# Path Configuration for Arr Stack

**Last Updated: February 27, 2026**

This document shows the exact paths to use in each service to ensure everything works together seamlessly.

## 🌐 Service URLs

| Service | LXC ID | IP Address | URL |
|---------|--------|------------|-----|
| Radarr | 101 | 192.168.1.161 | http://192.168.1.161:7878 |
| Sonarr | 102 | 192.168.1.216 | http://192.168.1.216:8989 |
| Jellyseerr | 103 | 192.168.1.153 | http://192.168.1.153:5055 |
| Prowlarr | 104 | 192.168.1.142 | http://192.168.1.142:9696 |
| Jellyfin | 105 | 192.168.1.201 | http://192.168.1.201:8096 |
| qBittorrent | 106 | 192.168.1.137 | http://192.168.1.137:8080 |
| Cleanuparr | 115 | 192.168.1.154 | http://192.168.1.154:5030 |

## 🗂️ Folder Structure

```
/mnt/storage/                    ← Local SSD Storage (1.8TB, fast)
├── downloads/
│   ├── complete/                ← qBittorrent completed downloads
│   ├── incomplete/              ← qBittorrent active downloads
│   ├── movies/                  ← Movies category folder
│   ├── tv/                      ← TV category folder
│   └── adult/                   ← Adult category folder
└── media/                       ← Local organized media (optional, for quick access)
    ├── movies/
    ├── tv/
    └── adult/

/mnt/cold-storage/               ← NFS Storage (22TB, bulk)
├── downloads/
│   ├── radarr/                  ← Radarr download imports
│   ├── tv-sonarr/               ← Sonarr download imports
│   └── tv-whisparr/             ← Whisparr download imports
├── media/                       ← Final organized media location
│   ├── movies/                  ← Radarr stores movies here
│   ├── tv/                      ← Sonarr stores TV shows here
│   └── adult/                   ← Whisparr stores adult content here
└── ready/                       ← Legacy folder (being phased out)
    ├── radarr/
    └── tv-sonarr/
```

## 📺 Sonarr Configuration

**URL:** http://192.168.1.216:8989

### Root Folder
```
Path: /mnt/cold-storage/media/tv
```
This is where Sonarr will move completed and renamed TV shows.

### Download Client (qBittorrent)
```
Host: 192.168.1.137
Port: 8080
Username: admin
Category: tv
```

**Important:** The category `tv` must match exactly with the category created in qBittorrent.

### Media Management Settings
- **Rename Episodes:** ☑ Yes
- **Replace Illegal Characters:** ☑ Yes
- **Import Extra Files:** ☑ Yes (srt, nfo, etc.)
- **Unmonitor Deleted Episodes:** ☑ Yes

### Expected Behavior
1. Sonarr sends download to qBittorrent with category `tv`
2. qBittorrent saves to: `/mnt/storage/downloads/complete/` (or per-category folder)
3. Sonarr detects completion at: `/mnt/storage/downloads/complete/`
4. Sonarr moves and renames to: `/mnt/cold-storage/media/tv/Show Name (Year)/Season 01/`

## 🎬 Radarr Configuration

**URL:** http://192.168.1.161:7878

### Root Folder
```
Path: /mnt/cold-storage/media/movies
```

### Download Client (qBittorrent)
```
Host: 192.168.1.137
Port: 8080
Username: admin
Category: movies
```

### Media Management Settings
- **Rename Movies:** ☑ Yes
- **Replace Illegal Characters:** ☑ Yes
- **Movie Naming Format:** `{Movie Title} ({Release Year})`

### Expected Behavior
1. Radarr sends download to qBittorrent with category `movies`
2. qBittorrent saves to: `/mnt/storage/downloads/complete/`
3. Radarr detects completion
4. Radarr moves and renames to: `/mnt/cold-storage/media/movies/Movie Name (Year)/Movie Name (Year).mkv`

## ⬇️ qBittorrent Configuration

**URL:** http://192.168.1.137:8080

### Default Save Path
```
Tools → Options → Downloads
Default Save Path: /mnt/storage/downloads/complete
```

### Incomplete Downloads
```
Keep incomplete torrents in: /mnt/storage/downloads/incomplete
☑ Append .!qB extension to incomplete files
```

### Categories (Create These!)

**Movies Category:**
```
Name: movies
Save Path: /mnt/storage/downloads/movies
```

**TV Category:**
```
Name: tv
Save Path: /mnt/storage/downloads/tv
```

**Adult Category (if using Whisparr):**
```
Name: adult
Save Path: /mnt/storage/downloads/adult
```

### Additional Settings
- **Maximum active downloads:** 3-5 (adjust based on bandwidth)
- **Maximum active uploads:** 5-10
- **Share ratio limit:** 2.0 (adjust based on your preferences)
- **Seeding time limit:** 10080 minutes (1 week)

## 📺 Jellyfin Configuration

**URL:** http://192.168.1.201:8096

### Movie Library
```
Content Type: Movies
Display Name: Movies
Folder: /mnt/cold-storage/media/movies
```

### TV Show Library
```
Content Type: Shows
Display Name: TV Shows
Folder: /mnt/cold-storage/media/tv
```

### Adult Library (Optional)
```
Content Type: Shows (or Movies, depending on content)
Display Name: Adult
Folder: /mnt/cold-storage/media/adult
```

### Recommended Settings
- **Enable automatic library scanning:** ☑ Yes
- **Scan library on startup:** ☑ Yes
- **Monitor library for changes:** ☑ Yes
- **Days between library refreshes:** 1

## � Prowlarr Configuration

**URL:** http://192.168.1.142:9696

Prowlarr manages your indexers centrally and syncs them to Sonarr, Radarr, etc.

### Add Applications (Apps)
1. Go to **Settings → Apps**
2. Add Sonarr:
   - Name: Sonarr
   - Sync Level: Full Sync
   - Prowlarr Server: http://localhost:9696
   - Sonarr Server: http://192.168.1.216:8989
   - API Key: (Get from Sonarr Settings → General)

3. Add Radarr:
   - Name: Radarr
   - Sync Level: Full Sync
   - Prowlarr Server: http://localhost:9696
   - Radarr Server: http://192.168.1.161:7878
   - API Key: (Get from Radarr Settings → General)

### Download Clients (Optional)
Prowlarr can also send manual searches directly to qBittorrent:
- Host: 192.168.1.137
- Port: 8080
- Category: manual

## 🧹 Cleanuparr Configuration

**URL:** http://192.168.1.154:5030

Cleanuparr automatically cleans up torrents based on rules.

### Paths to Monitor
```
Radarr Movies: /mnt/cold-storage/media/movies
Sonarr TV: /mnt/cold-storage/media/tv
```

### Typical Settings
- **Delete torrents after import:** ☑ Yes
- **Minimum seed time:** 72 hours
- **Minimum seed ratio:** 2.0
- **Keep seeding if under ratio:** ☑ Yes

## 🎬 Jellyseerr Configuration

**URL:** http://192.168.1.153:5055

Jellyseerr is a request management and media discovery tool.

### Connect to Jellyfin
```
Settings → Services → Jellyfin
Server URL: http://192.168.1.201:8096
```

### Connect to Sonarr
```
Settings → Services → Sonarr
Server URL: http://192.168.1.216:8989
API Key: (Get from Sonarr)
Quality Profile: HD-1080p (or your preferred profile)
Root Folder: /mnt/cold-storage/media/tv
```

### Connect to Radarr
```
Settings → Services → Radarr
Server URL: http://192.168.1.161:7878
API Key: (Get from Radarr)
Quality Profile: HD-1080p (or your preferred profile)
Root Folder: /mnt/cold-storage/media/movies
```

## �🔗 Path Mapping (Usually NOT Needed)

**When paths match exactly across all containers, you DON'T need remote path mapping.**

If you do need it (rare cases where containers see different paths):

In Sonarr/Radarr → Settings → Download Clients → Advanced Settings:
```
Remote Path Mapping:
  Host: <qbittorrent-ip>
  Remote Path: /downloads/complete/
  Local Path: /mnt/cold-storage/downloads/complete/
```

But again, **if you followed this guide, you don't need this!**

## ✅ Verification Checklist

Run these commands on the Proxmox host to verify paths exist and permissions are correct:

```bash
# Verify directory structure
ls -la /mnt/storage/downloads/
ls -la /mnt/storage/media/
ls -la /mnt/cold-storage/downloads/
ls -la /mnt/cold-storage/media/

# Verify from within containers
pct exec 102 -- ls -la /mnt/storage/downloads/      # Sonarr
pct exec 101 -- ls -la /mnt/cold-storage/media/     # Radarr
pct exec 106 -- ls -la /mnt/storage/downloads/      # qBittorrent
pct exec 105 -- ls -la /mnt/cold-storage/media/     # Jellyfin
```

All commands should show the same folders. If you get "Permission denied" or "No such file or directory", your storage mounts aren't configured correctly.

### Permission Check
```bash
# Set proper permissions (run on Proxmox host)
chmod -R 775 /mnt/storage/downloads/
chmod -R 775 /mnt/storage/media/
chmod -R 775 /mnt/cold-storage/media/
chown -R 100000:100000 /mnt/storage/
```

## 🎯 Quick Test

To test the complete flow:

1. **In Sonarr (http://192.168.1.216:8989):** Add a single episode test show
2. **Watch qBittorrent (http://192.168.1.137:8080):** Download should start in category `tv`
3. **Check path in qBittorrent:** Right-click torrent → Show in folder → Should be `/mnt/storage/downloads/tv/` or `/mnt/storage/downloads/complete/`
4. **Wait for completion**
5. **Check Sonarr:** Activity → Queue → Should show "Importing"
6. **Check final location on host:** 
   ```bash
   ls -la /mnt/cold-storage/media/tv/
   ```
   Should show: `Show Name (Year)/Season 01/`
7. **Check Jellyfin (http://192.168.1.201:8096):** Scan library → Show should appear

If any step fails, check:
- Mount points are configured in all containers
- Permissions are correct (775 for directories)
- Categories in qBittorrent match Sonarr/Radarr settings
- Root folders in Sonarr/Radarr match the final destination

## 📝 Summary of Changes

**What was changed:**
1. Created standardized directory structure:
   - `/mnt/storage/downloads/` for active downloads (fast SSD)
   - `/mnt/cold-storage/media/` for organized final media (bulk NFS)
2. Separated download categories for better organization
3. All services configured to use consistent path structure
4. Permissions set to 775 for proper access

**Next Steps:**
1. Access each service via the URLs above
2. Configure paths exactly as shown in this document
3. Add your indexers in Prowlarr
4. Test with a single movie and TV show
5. Monitor the complete download → import → organize flow

**Backup Note:** The old `/mnt/cold-storage/ready/` structure has been preserved. You can migrate content when convenient:
```bash
# Example migration (run on Proxmox host)
mv /mnt/cold-storage/ready/tv-sonarr/* /mnt/cold-storage/media/tv/
mv /mnt/cold-storage/ready/radarr/* /mnt/cold-storage/media/movies/
```
