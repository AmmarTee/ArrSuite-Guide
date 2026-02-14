#!/bin/bash
# ----------------------------------------------------------------------------------
# arr-stack-deploy.sh - One-click deploy for the full media suite
# ----------------------------------------------------------------------------------
# Uses the excellent Proxmox VE Helper Scripts to deploy the full stack.
# Each service is isolated in its own unprivileged LXC container.
# ----------------------------------------------------------------------------------

set -e

echo "🚀 Starting Arr Stack Deployment..."

# Function to deploy a script
deploy() {
    local name=$1
    local url=$2
    echo "📦 Deploying $name..."
    bash -c "$(curl -fsSL $url)"
}

# Core Services
deploy "Prowlarr (Indexer Manager)" "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/prowlarr.sh"
deploy "qBittorrent (Download Client)" "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/qbittorrent.sh"
deploy "Sonarr (TV Automation)" "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/sonarr.sh"
deploy "Radarr (Movie Automation)" "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/radarr.sh"
deploy "Jellyfin (Media Server)" "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyfin.sh"
deploy "Jellyseerr (Request Management)" "https://raw.githubusercontent.com/community-scripts/ProxmoxVE/main/ct/jellyseerr.sh"

echo ""
echo "✅ Core stack deployment initiated."
echo "⚠️  REMINDER: You must run './ct-add-storage.sh <CTID>' for each container to mount your NAS storage."
echo "🔗 Access your services via the IPs shown above."
