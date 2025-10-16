# LANCache Setup Guide

This guide walks you through setting up LANCache to dramatically reduce internet bandwidth usage for game downloads.

## What LANCache Does (ELI5)

Imagine you have 200 kids who all want to download the same 50GB game:

**Without LANCache:**
- Kid 1 downloads 50GB from internet
- Kid 2 downloads 50GB from internet
- Kid 3 downloads 50GB from internet
- ...
- Kid 200 downloads 50GB from internet
- **Total**: 10,000GB (10TB) from internet
- **Time**: Many hours, possibly days

**With LANCache:**
- Kid 1 downloads 50GB from internet → LANCache saves a copy
- Kid 2 downloads 50GB from LANCache (super fast!)
- Kid 3 downloads 50GB from LANCache (super fast!)
- ...
- Kid 200 downloads 50GB from LANCache (super fast!)
- **Total**: 50GB from internet
- **Time**: About 30 minutes for everyone

That's a 99.5% reduction in internet usage! 🎉

## How It Works

LANCache uses a clever trick called "DNS hijacking":

```
Normal:
Client → "Where is epicgames.com?" → DNS → "It's at 1.2.3.4"
Client → Downloads from 1.2.3.4 (internet)

With LANCache:
Client → "Where is epicgames.com?" → LANCache DNS → "It's at 192.168.1.11" (lie!)
Client → Downloads from 192.168.1.11 (LANCache)
LANCache → If it has the file, serves it. If not, downloads from internet and saves.
```

The client thinks it's downloading from the real server, but it's actually getting it from your local cache!

## Prerequisites

- Phase 1 complete (repository structure)
- Phase 2 complete (iPXE server)
- Proxmox server running
- Large disk space (30TB recommended)
- `config.yaml` configured

## Step 1: Configure LANCache Settings

Edit your `config.yaml`:

```yaml
network:
  lancache_server_ip: "192.168.1.11"
  dns_primary: "192.168.1.11"  # IMPORTANT: Point to LANCache
  dns_secondary: "8.8.8.8"     # Fallback

vms:
  lancache_server:
    cores: 4          # More is better for high load
    memory: 16384     # 16GB minimum
    disk_size: 500    # OS disk
    cache_disk_size: 30000  # 30TB for game cache

games:
  clients:
    steam:
      enabled: true
    epic_games:
      enabled: true
    riot_client:
      enabled: true
    battle_net:
      enabled: false  # Enable if needed
```

Validate:
```bash
python3 scripts/validate_config.py config.yaml
```

## Step 2: Deploy LANCache

### Option A: Automated (Recommended)

```bash
./deploy.sh --component lancache
```

This will:
1. Create VM in Proxmox
2. Install Docker and Docker Compose
3. Deploy LANCache containers
4. Configure DNS hijacking
5. Start services

⏱️ **Time**: 15-20 minutes

### Option B: Manual

#### 2.1: Create VM
```bash
cd terraform
terraform apply -target=module.lancache_vm
```

#### 2.2: Run Setup Script
```bash
ssh ansible@192.168.1.11

# List available games
sudo /opt/lancache/prefill.sh --list

# Pre-fill specific game
sudo /opt/lancache/prefill.sh --game fortnite

# Pre-fill all configured games (takes HOURS!)
sudo /opt/lancache/prefill.sh --all
```

**Note**: Pre-filling requires:
- A client machine to actually download the games
- That client's DNS set to LANCache
- Time and bandwidth to download once

The script guides you through the process.

## Monitoring Your Cache

### Quick Status Check
```bash
ssh ansible@192.168.1.11 'lancache-status'
```

### Live Monitoring
```bash
ssh ansible@192.168.1.11 'lancache-monitor'
```

Shows real-time cache hits/misses:
```
MISS - Downloading from internet
HIT - Serving from cache
UPDATING - Updating cached content
```

### Cache Statistics
```bash
ssh ansible@192.168.1.11 'lancache-stats'
```

Shows:
- Total cache size
- Hit rate percentage
- Top cached games
- Number of files

### Web Dashboard

Access Grafana for fancy graphs:
```
http://192.168.1.11:3000
Username: admin
Password: admin (change this!)
```

## Troubleshooting

### Games Still Downloading from Internet

**Check DNS is being used:**
```bash
# From client machine
nslookup steamcdn.com
# Should return 192.168.1.11, not some other IP
```

**If it returns wrong IP:**
1. Check client's DNS settings: `ipconfig /all` (Windows)
2. Verify DHCP is giving correct DNS
3. Renew DHCP lease: `ipconfig /renew`

**Check DNS on LANCache server:**
```bash
ssh ansible@192.168.1.11
docker logs lancache-dns --tail=50
```

### Slow Cache Performance

**Check disk I/O:**
```bash
ssh ansible@192.168.1.11
iostat -x 1
```

If disk is slow:
- Consider SSD for cache storage
- Check for disk errors
- Verify RAID configuration

**Check network bandwidth:**
```bash
iftop
```

Should see high throughput between clients and cache.

**Check cache container resources:**
```bash
docker stats lancache
```

If CPU or memory maxed out, increase VM resources in `config.yaml`.

### Cache Not Saving Files

**Check disk space:**
```bash
df -h /srv/lancache/data
```

If full:
```bash
# Clear old content
sudo lancache-clear

# Or increase cache disk size in config.yaml and redeploy
```

**Check permissions:**
```bash
ls -la /srv/lancache/data
# Should be owned by nobody:nogroup
```

**Fix permissions if needed:**
```bash
sudo chown -R nobody:nogroup /srv/lancache/data
```

### DNS Not Resolving

**Check dnsmasq in container:**
```bash
docker logs lancache-dns
```

**Test DNS directly:**
```bash
dig @192.168.1.11 epicgames.com
```

**Restart DNS container:**
```bash
cd /opt/lancache
docker-compose restart lancache-dns
```

### Specific Game Not Caching

**Check if domain is in cache list:**
```bash
docker exec lancache-dns cat /etc/dnsmasq.d/cache-domains.conf | grep <game-domain>
```

**Check nginx logs:**
```bash
tail -f /srv/lancache/logs/access.log | grep <domain>
```

**Some games use HTTPS** (which can't be cached):
- Most game CDNs use HTTP by design
- Some content may still use HTTPS
- This is normal - cache what you can

## Performance Tips

### For 200 Concurrent Clients

Increase resources in `config.yaml`:
```yaml
vms:
  lancache_server:
    cores: 8      # More cores = more concurrent downloads
    memory: 32768 # 32GB for better caching
```

Redeploy:
```bash
./deploy.sh --component lancache
```

### Network Optimization

**Use 10Gb networking:**
- Install 10Gb NIC in Proxmox server
- Connect to 10Gb switch
- Update VM network settings

**Enable jumbo frames:**
```bash
# On Proxmox host
ip link set eth0 mtu 9000

# On LANCache VM
sudo ip link set eth0 mtu 9000
```

**Optimize TCP settings:**
```bash
# Add to /etc/sysctl.conf
net.core.rmem_max = 134217728
net.core.wmem_max = 134217728
net.ipv4.tcp_rmem = 4096 87380 67108864
net.ipv4.tcp_wmem = 4096 65536 67108864

# Apply
sudo sysctl -p
```

### Storage Optimization

**Use SSD for cache** (if budget allows):
- Dramatically faster cache serving
- Better for random access patterns
- Worth the investment for large events

**Separate OS and cache disks:**
```yaml
# Terraform will create separate disks automatically
# OS on fast storage
# Cache on large (cheaper) storage
```

## Pre-Event Checklist

One week before event:
- [ ] LANCache running and tested
- [ ] DNS configuration verified
- [ ] Pre-fill all tournament games
- [ ] Test with multiple clients
- [ ] Monitor cache hit rates
- [ ] Check disk space
- [ ] Verify backup plan

Day before event:
- [ ] Update games to latest version
- [ ] Clear any errors from logs
- [ ] Test cache serving speed
- [ ] Confirm monitoring working
- [ ] Brief staff on how to check status

During event:
- [ ] Monitor cache hit rates
- [ ] Watch for errors
- [ ] Track bandwidth savings
- [ ] Be ready to restart services if needed

## Understanding Cache Hit Rates

**What's normal:**
- **First event**: 40-60% hit rate (building cache)
- **Second event**: 80-90% hit rate (cache warming up)
- **Ongoing**: 95%+ hit rate (fully populated)

**Why not 100%?**
- New game updates since last event
- DLC or new content
- Some HTTPS content can't be cached
- Background updates from Windows/apps

**95%+ is excellent!** You're still saving massive bandwidth.

## Bandwidth Savings Calculator

Example for 200 clients downloading Fortnite (50GB):

**Without cache:**
- Downloads: 200 × 50GB = 10,000GB
- Time @ 1Gbps: ~22 hours
- ISP cost: $$

**With cache (95% hit rate):**
- Internet: 50GB + (5% × 200 × 50GB) = 550GB
- Time @ 10Gbps LAN: ~30 minutes total
- ISP cost: $
- **Savings: 94.5% bandwidth, 95%+ time**

## Advanced Configuration

### Multiple LANCache Servers

For very large events (500+ clients):

```yaml
network:
  lancache_servers:
    primary: "192.168.1.11"
    secondary: "192.168.1.12"
```

Use DNS round-robin or load balancer.

### Selective Game Caching

Only cache specific games:

```bash
# Edit /opt/lancache/lancache-dns.env
DISABLE_STEAM=true   # Don't cache Steam
DISABLE_RIOT=false   # Do cache Riot games
```

Restart containers:
```bash
cd /opt/lancache
docker-compose restart
```

### Custom Cache Domains

Add custom CDN domains:

```bash
# Edit lancache-dns configuration
docker exec lancache-dns vi /etc/dnsmasq.d/custom-domains.conf
```

Add domains that should be cached.

### Monitoring Integration

Export metrics to your monitoring system:
```bash
# Prometheus endpoint
curl http://192.168.1.11:9113/metrics
```

## Security Considerations

### Access Control

Restrict access to management interfaces:
```bash
# Only allow LAN access to Grafana
sudo ufw allow from 192.168.1.0/24 to any port 3000
```

### DNS Security

LANCache DNS only works on local network:
- External clients unaffected
- No impact on internet routing
- Safe to use on isolated networks

### Log Monitoring

Monitor for unusual patterns:
```bash
# Large unexpected downloads
# Unusual domains being cached
# Failed authentication attempts
```

## Maintenance

### Daily
- Check cache size: `lancache-stats`
- Review hit rates
- Monitor for errors

### Weekly
- Review top cached games
- Check disk space trends
- Update container images:
  ```bash
  cd /opt/lancache
  docker-compose pull
  docker-compose up -d
  ```

### Monthly
- Clear unused cache:
  ```bash
  # Remove content not accessed in 90 days
  find /srv/lancache/data -atime +90 -delete
  ```
- Review and update cache domains
- Test failover procedures

### Before Events
- Pre-fill all games
- Verify cache integrity
- Test with multiple clients
- Update game clients

## Common Questions

**Q: Do clients need special configuration?**
A: No! Just point their DNS to LANCache. The PXE boot does this automatically.

**Q: What if LANCache goes down?**
A: Clients will fail over to secondary DNS (8.8.8.8) and download from internet. Slower, but works.

**Q: Can I cache Windows Updates?**
A: Yes! LANCache caches Windows Update by default.

**Q: Does this work with game clients like Steam?**
A: Yes! Works with Steam, Epic, Riot, Battle.net, Origin, and more.

**Q: How much bandwidth will I save?**
A: Typically 90-95% reduction in internet bandwidth for game downloads.

**Q: Do I need to pre-fill the cache?**
A: Not required, but highly recommended. First downloads are slow, subsequent ones are fast.

**Q: What about HTTPS/SSL games?**
A: Can't cache encrypted traffic. But most game CDNs use HTTP by design.

## Next Steps

✅ LANCache is now running!

Next in Phase 4:
- Set up file server for user profiles
- Configure roaming profiles
- Enable seamless machine switching
- Store user settings centrally

Continue to: [Phase 4 - File Server Setup](../phase4-fileserver/setup.md)

## Quick Reference

```bash
# Status
lancache-status

# Live monitoring
lancache-monitor

# Statistics
lancache-stats

# View logs
lancache-logs

# Clear cache (DESTRUCTIVE)
lancache-clear

# Restart services
cd /opt/lancache && docker-compose restart

# Update containers
cd /opt/lancache && docker-compose pull && docker-compose up -d

# Test DNS
nslookup steamcdn.com 192.168.1.11

# Monitor network
iftop

# Check disk I/O
iostat -x 1
```.168.1.11
sudo bash /path/to/setup.sh
```

#### 2.3: Deploy with Ansible
```bash
cd ansible
ansible-playbook playbooks/deploy_lancache.yml
```

## Step 3: Update iPXE DHCP

**CRITICAL STEP**: Clients need to use LANCache DNS!

Update `config.yaml`:
```yaml
network:
  dns_primary: "192.168.1.11"  # LANCache DNS
```

Redeploy iPXE:
```bash
./deploy.sh --component ipxe
```

This updates DHCP to give clients the LANCache DNS server.

## Step 4: Verify Installation

```bash
# Check services are running
ssh ansible@192.168.1.11 'lancache-status'
```

You should see:
```
LANCache Server Status
======================

Docker Containers:
lancache-dns    running
lancache        running
sniproxy        running

Cache Storage:
/srv/lancache/data   30T   1.0G   30T   1% /srv/lancache/data

Cache Size:
1.0G    /srv/lancache/data

Active Connections:
0
```

## Step 5: Test DNS Resolution

From a client machine (or the LANCache server):

```bash
# Should return LANCache IP (192.168.1.11)
nslookup steamcdn.com 192.168.1.11
nslookup epicgames.com 192.168.1.11
nslookup riotgames.com 192.168.1.11
```

If these return the LANCache IP, DNS hijacking is working! ✅

## Step 6: Test with a Small Game

Let's test with a small download:

1. Boot a client machine via PXE
2. Open Steam (or Epic Games Launcher)
3. Download a small game (Under 5GB)
4. Monitor on LANCache server:

```bash
ssh ansible@192.168.1.11 'lancache-monitor'
```

You should see log entries showing:
- `MISS` - First download (fetching from internet)
- File being cached
- Traffic flowing through

5. On a second client, download the same game
6. Monitor again - you should see:
- `HIT` - Served from cache!
- Much faster download speed

## Step 7: Pre-fill Cache (Optional but Recommended)

Before your event, pre-download all the games:

```bash
ssh ansible@192