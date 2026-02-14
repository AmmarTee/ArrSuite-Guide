# Cleanuparr Cloudflare Access Configuration

This guide covers the configuration for allowing `https://cleanuparr.trostrum.com/` to access your Cleanuparr instance running in LXC container 115.

---

## Configuration Summary

**Container:** LXC 115 (Cleanuparr)  
**Port:** 11011 (internal)  
**Domain:** https://cleanuparr.trostrum.com/  
**Access Method:** Cloudflare Tunnel (no proxy)

---

## What Was Changed

### 1. Cleanuparr Service Configuration

The systemd service file was updated to enable forwarded headers support, which is essential for reverse proxy/Cloudflare Tunnel access.

**File Location:** `/etc/systemd/system/cleanuparr.service` (inside LXC 115)

**Changes Made:**
```bash
# Added these environment variables:
Environment="ASPNETCORE_URLS=http://*:11011"
Environment="ASPNETCORE_FORWARDEDHEADERS_ENABLED=true"
```

**What these do:**
- `ASPNETCORE_URLS=http://*:11011` - Tells Cleanuparr to listen on all interfaces on port 11011
- `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` - Enables support for X-Forwarded-* headers from Cloudflare

### 2. Service Restart

After configuration changes:
```bash
systemctl daemon-reload
systemctl restart cleanuparr
```

**Backup:** A backup was created at `/etc/systemd/system/cleanuparr.service.backup`

---

## Cloudflare Tunnel Configuration

Since you're using Cloudflare to handle all domains, you need to set up either:

### Option A: Cloudflare Tunnel (Recommended)

1. **Access Cloudflare Zero Trust Dashboard:**
   - Go to https://one.dash.cloudflare.com/
   - Navigate to `Access` → `Tunnels`

2. **Create or Edit Tunnel:**
   - If you don't have a tunnel, create one
   - Install cloudflared in a container or on the Proxmox host

3. **Add Public Hostname:**
   - Public hostname: `cleanuparr.trostrum.com`
   - Service Type: `HTTP`
   - Service URL: `http://<LXC-115-IP>:11011`
   - Additional application settings:
     - No TLS Verify: Off (leave default)
     - HTTP Host Header: (leave empty to forward original)

4. **Save Configuration**

### Option B: DNS + Port Forwarding (Not Recommended)

If not using Cloudflare Tunnel:

1. **DNS Configuration:**
   - Go to Cloudflare DNS settings for `trostrum.com`
   - Add or edit A record:
     - Name: `cleanuparr`
     - IPv4 address: Your public IP
     - Proxy status: **Proxied** (Orange cloud ON)

2. **Port Forward on Router:**
   - Forward external HTTPS (443) to Proxmox IP:11011
   - Or use a reverse proxy like Nginx Proxy Manager

---

## Verification Steps

### 1. Test Internal Access (from Proxmox host)

```bash
# Test direct access
curl http://<LXC-115-IP>:11011/

# Test with Host header
curl -H "Host: cleanuparr.trostrum.com" http://<LXC-115-IP>:11011/
```

Both should return HTML (Cleanuparr web interface).

### 2. Test External Access

Open in browser: `https://cleanuparr.trostrum.com/`

You should see the Cleanuparr web interface.

---

## Get LXC 115 IP Address

To find the IP address of container 115:

```bash
# From Proxmox host
pct exec 115 -- ip addr show | grep "inet " | grep -v "127.0.0.1" | awk '{print $2}' | cut -d/ -f1
```

Or:

```bash
pct list | grep 115
```

---

## Troubleshooting

### Can't Access via Domain

**Check Cloudflare Tunnel Status:**
```bash
# If cloudflared is running on Proxmox host
systemctl status cloudflared

# If in a container
pct exec <CLOUDFLARED-CTID> -- systemctl status cloudflared
```

**Check Cleanuparr is Running:**
```bash
pct exec 115 -- systemctl status cleanuparr
```

**Check Cleanuparr Logs:**
```bash
pct exec 115 -- journalctl -u cleanuparr -f
```

### 502 Bad Gateway

- Verify LXC 115 is running: `pct status 115`
- Check Cleanuparr service: `pct exec 115 -- systemctl status cleanuparr`
- Verify port 11011 is listening: `pct exec 115 -- ss -tlnp | grep 11011`

### SSL/TLS Errors

- Cloudflare handles SSL - ensure your tunnel or DNS proxy is enabled
- Check Cloudflare SSL/TLS settings:
  - Go to SSL/TLS → Overview
  - Set to **Full** (not Full Strict unless you have a cert on Proxmox)

### CORS Errors

The configuration we applied should handle this, but if you still see CORS errors:

1. Check browser console for specific error
2. Verify `ASPNETCORE_FORWARDEDHEADERS_ENABLED=true` is in service file
3. Restart Cleanuparr: `pct exec 115 -- systemctl restart cleanuparr`

---

## Reverting Changes

If you need to revert to the original configuration:

```bash
# Inside Proxmox host
pct exec 115 -- cp /etc/systemd/system/cleanuparr.service.backup /etc/systemd/system/cleanuparr.service
pct exec 115 -- systemctl daemon-reload
pct exec 115 -- systemctl restart cleanuparr
```

---

## Advanced: Manual Service File Edit

If you need to modify the service file manually:

```bash
# Edit service file
pct exec 115 -- nano /etc/systemd/system/cleanuparr.service

# After editing, reload and restart
pct exec 115 -- systemctl daemon-reload
pct exec 115 -- systemctl restart cleanuparr
```

---

## Summary

✅ **What was configured:**
- Cleanuparr now accepts forwarded headers from Cloudflare
- Service listens on all interfaces (0.0.0.0:11011)
- Ready for Cloudflare Tunnel or reverse proxy access

✅ **What you need to do:**
1. Set up Cloudflare Tunnel pointing to `http://<LXC-115-IP>:11011`
2. Configure public hostname as `cleanuparr.trostrum.com`
3. Test access via `https://cleanuparr.trostrum.com/`

---

## Quick Reference

| Item | Value |
|------|-------|
| Container ID | 115 |
| Service Name | cleanuparr |
| Port | 11011 |
| Config Dir | /opt/cleanuparr/config |
| Service File | /etc/systemd/system/cleanuparr.service |
| Domain | https://cleanuparr.trostrum.com/ |

---

## Additional Resources

- [Cloudflare Tunnel Documentation](https://developers.cloudflare.com/cloudflare-one/connections/connect-apps/)
- [ASP.NET Core Forwarded Headers](https://learn.microsoft.com/en-us/aspnet/core/host-and-deploy/proxy-load-balancer)
- [Proxmox LXC Container Guide](https://pve.proxmox.com/wiki/Linux_Container)

---

**Last Updated:** February 14, 2026  
**Configuration Applied By:** Automated setup script
