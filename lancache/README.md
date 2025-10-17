# LANCache Server

LANCache is a game content caching system that dramatically reduces internet bandwidth usage during tournaments and events by caching game downloads, updates, and DLC locally.

## How It Works

Think of LANCache as a smart mirror that sits between your gaming PCs and the internet:

1. **First Download**: Client requests Fortnite update → Goes through cache → Downloads from internet → Cache saves a copy
2. **Subsequent Downloads**: Other clients request same update → Cache serves it directly → No internet usage!

### The Magic: DNS Hijacking

LANCache uses DNS to transparently intercept requests:
- Client wants `epicgames.com` content
- DNS returns LANCache IP instead of real server
- Client downloads from cache thinking it's the real server
- No client configuration needed!

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│ LANCache Server                                          │
│                                                           │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
│  │   DNS Server │  │ Cache Proxy  │  │  Monitoring  │  │
│  │   (dnsmasq)  │  │   (nginx)    │  │  (optional)  │  │
│  │              │  │              │  │              │  │
│  │ Intercepts   │  │ Caches game  │  │ Stats &      │  │
│  │ CDN domains  │  │ downloads    │  │ dashboards   │  │
│  └──────────────┘  └──────────────┘  └──────────────┘  │
│                                                           │
│  Cache Storage: 30TB (configurable)                      │
└─────────────────────────────────────────────────────────┘
```

## Supported Platforms

LANCache caches content from:

### Gaming Platforms
- ✅ **Steam** - Games, updates, workshop content
- ✅ **Epic Games** - Fortnite, Rocket League, etc.
- ✅ **Riot Games** - League of Legends, Valorant
- ✅ **Battle.net** - Overwatch, WoW, etc.
- ✅ **Origin/EA** - Apex Legends, FIFA
- ✅ **Microsoft Store** - Xbox Game Pass games
- ✅ **GOG** - DRM-free games
- ✅ **Uplay/Ubisoft Connect** - Rainbow Six Siege

### System Updates
- ✅ **Windows Update** - OS updates and patches
- ✅ **Apple Updates** - macOS and iOS updates (if needed)
- ✅ **Linux Updates** - apt, yum repositories

## Directory Structure

```
lancache/
├── config/
│   ├── docker-compose.yml       # Container orchestration
│   ├── lancache-dns.env         # DNS configuration
│   ├── nginx.conf.j2            # Cache proxy config
│   └── cache-domains.json       # Domains to cache
│
├── scripts/
│   ├── setup.sh                 # Initial setup
│   ├── prefill.sh               # Pre-download popular games
│   ├── monitor.sh               # Cache statistics
│   └── clear_cache.sh           # Clear cache (maintenance)
│
└── README.md                    # This file
```

## Performance Characteristics

### Bandwidth Savings

**Scenario: 200 clients downloading 50GB Fortnite update**

Without LANCache:
- Total internet download: 200 × 50GB = 10,000GB (10TB)
- Time on 1Gbps: ~22 hours
- ISP bandwidth charges: 💰💰💰

With LANCache:
- Total internet download: 1 × 50GB = 50GB
- Subsequent downloads: LAN speed (10Gbps)
- Time: ~30 minutes for all clients
- ISP bandwidth charges: Minimal! 🎉

### Cache Hit Rates

Typical hit rates during events:
- **First day**: 40-60% (building cache)
- **Second day**: 80-95% (cache warmed up)
- **Ongoing events**: 95%+ (most content cached)

### Speed Improvements

| Content | Without Cache | With Cache | Improvement |
|---------|--------------|------------|-------------|
| 50GB Game | 45 min | 4 min | 11x faster |
| 5GB Update | 4.5 min | 25 sec | 10x faster |
| 500MB DLC | 27 sec | 2.5 sec | 10x faster |

*Based on 1Gbps internet, 10Gbps LAN*

## Configuration

All settings in `config.yaml`:

```yaml
vms:
  lancache_server:
    cores: 4
    memory: 16384  # 16GB RAM
    disk_size: 500  # OS disk
    cache_disk_size: 30000  # 30TB cache

network:
  lancache_server_ip: "192.168.1.11"
  
advanced:
  lancache:
    prefill_enabled: false
    prefill_schedule: "0 2 * * *"  # 2 AM daily
```

## Installation

### Automated (Recommended)
```bash
./deploy.sh --component lancache
```

### Manual
```bash
# Deploy VM with Terraform
cd terraform
terraform apply -target=module.lancache_vm

# Configure with Ansible
cd ../ansible
ansible-playbook playbooks/deploy_lancache.yml
```

## Pre-filling Cache

Pre-download games before your event:

```bash
# SSH to LANCache server
ssh ansible@192.168.1.11

# Pre-fill common games
sudo /opt/lancache/prefill.sh --game fortnite
sudo /opt/lancache/prefill.sh --game valorant
sudo /opt/lancache/prefill.sh --game league-of-legends

# Or pre-fill all configured games
sudo /opt/lancache/prefill.sh --all
```

⚠️ **Note**: Pre-filling requires downloading games, so do this before your event when you have time and bandwidth!

## Monitoring

### View Cache Statistics

```bash
# Quick status
ssh ansible@192.168.1.11 'lancache-status'

# Detailed stats
ssh ansible@192.168.1.11 'lancache-monitor'
```

Shows:
- Cache size used/available
- Hit rate percentage
- Top cached games
- Bandwidth saved
- Active downloads

### Real-time Monitoring

```bash
# Watch cache activity
ssh ansible@192.168.1.11
tail -f /var/log/lancache/access.log
```

### Web Dashboard (Optional)

Access monitoring dashboard:
```
http://192.168.1.11:8080/stats
```

## DNS Configuration

LANCache requires clients to use its DNS server. Two approaches:

### Approach 1: DHCP DNS Override (Recommended)
Configure iPXE server to provide LANCache DNS:
```yaml
# config.yaml
network:
  dns_primary: "192.168.1.11"  # LANCache DNS
  dns_secondary: "8.8.8.8"     # Fallback
```

### Approach 2: Manual Client Configuration
Set DNS on each client (not recommended for 200 machines):
```
Primary DNS: 192.168.1.11
Secondary DNS: 8.8.8.8
```

## Cache Management

### View Cache Contents
```bash
du -sh /srv/lancache/*
```

### Clear Specific Game
```bash
sudo lancache-clear --game fortnite
```

### Clear All Cache (Nuclear Option)
```bash
sudo lancache-clear --all
# WARNING: This deletes everything!
```

### Cache Limits
```bash
# Set maximum cache size
sudo lancache-config --max-size 25TB

# Set per-game limits
sudo lancache-config --game-limit fortnite 100GB
```

## Troubleshooting

### Game not caching

**Check DNS is working:**
```bash
# From client machine
nslookup epicgames.com
# Should return LANCache IP (192.168.1.11)
```

**Check domain is in cache list:**
```bash
grep epicgames /etc/lancache/cache-domains.json
```

**Check nginx logs:**
```bash
tail -f /var/log/lancache/access.log | grep epicgames
```

### Slow cache performance

**Check cache disk I/O:**
```bash
iostat -x 1
```

**Check available space:**
```bash
df -h /srv/lancache
```

**Check nginx worker processes:**
```bash
ps aux | grep nginx
```

### DNS not resolving

**Check dnsmasq is running:**
```bash
systemctl status dnsmasq
```

**Test DNS resolution:**
```bash
dig @192.168.1.11 epicgames.com
```

**Check DNS logs:**
```bash
journalctl -u dnsmasq -f
```

### Cache not saving files

**Check permissions:**
```bash
ls -la /srv/lancache
```

**Check disk space:**
```bash
df -h /srv/lancache
```

**Check nginx error log:**
```bash
tail -f /var/log/lancache/error.log
```

## Best Practices

### Before Events
1. Pre-fill cache with tournament games
2. Test with a few clients
3. Monitor cache hit rates
4. Verify DNS is working

### During Events
1. Monitor cache performance
2. Watch for errors in logs
3. Track bandwidth savings
4. Keep cache statistics

### After Events
1. Review cache hit rates
2. Clear unused content
3. Document what worked/didn't
4. Plan for next event

## Security Considerations

### DNS Hijacking
- Only works on local network
- Clients must use LANCache DNS
- External clients unaffected

### HTTPS/SSL
- LANCache cannot cache HTTPS content
- Most game CDNs use HTTP (by design)
- Some platforms may not cache fully

### Access Control
- Restrict access to management interface
- Use firewall rules
- Monitor for unusual activity

## Performance Tuning

### For High Load (200+ clients)
```yaml
# config.yaml - increase resources
vms:
  lancache_server:
    cores: 8  # More CPU for concurrent requests
    memory: 32768  # 32GB RAM for caching
```

### Network Optimization
- Use 10Gb network interface
- Enable jumbo frames (MTU 9000)
- Use SSD for cache storage (if possible)

### Nginx Tuning
```nginx
worker_processes 8;  # Match CPU cores
worker_connections 4096;
```

## Known Limitations

1. **HTTPS Content**: Cannot cache encrypted traffic
2. **First Download**: Still requires internet
3. **Storage**: Large games need significant space
4. **Platform Changes**: CDN changes may break caching

## Integration

### With iPXE Server
- Provides DNS to clients via DHCP
- Seamless integration

### With File Server
- Can cache on same physical disk array
- Shared storage considerations

### With Windows Image
- Pre-configure DNS settings
- Install game clients

## Advanced Features

### Selective Caching
Cache only specific games:
```bash
lancache-config --enable-only fortnite valorant
```

### Geographic CDN Routing
Route to nearest CDN:
```yaml
advanced:
  lancache:
    geo_routing: true
    prefer_region: "us-east"
```

### Multiple Cache Servers
For very large events (500+ clients):
```yaml
network:
  lancache_servers:
    - "192.168.1.11"
    - "192.168.1.12"
    - "192.168.1.13"
```

## Support

For LANCache-specific issues:
1. Check logs: `lancache-logs`
2. Run diagnostics: `lancache-test`
3. Review this documentation
4. Check [LANCache.net](https://lancache.net)
5. GitHub issues

## References

- [LANCache Official Docs](https://lancache.net)
- [LANCache GitHub](https://github.com/lancachenet)
- [Supported CDNs](https://github.com/uklans/cache-domains)

---

**Next**: Integrate with iPXE DHCP and deploy!