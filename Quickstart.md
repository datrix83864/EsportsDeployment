# Quick Start Guide - 20 Minute Deployment

Get your esports LAN infrastructure running in 20 minutes.

## What You're Building

Three servers that enable 200+ gaming PCs to:
- ✅ Boot from the network (PXE)
- ✅ Cache game downloads locally (save bandwidth)
- ✅ Keep player settings when switching machines (roaming profiles)

## Prerequisites

### Hardware
- **1 Proxmox server** with:
  - 40GB+ RAM available (26GB minimum)
  - 35TB+ storage (or adjust cache size)
  - Network connection to your switch
  
- **Network switch** (Ubiquiti or similar)
  - You'll need to configure DHCP settings (instructions below)

### Software
You need a Linux machine (or WSL on Windows) with:
- Python 3
- Ansible
- SSH access to your Proxmox server

## Step 1: Install Prerequisites (5 minutes)

On your workstation:

```bash
# Ubuntu/Debian
sudo apt update
sudo apt install -y ansible python3 python3-pip
apt install -y python3-proxmoxer
pip3 install pyyaml

# Install Ansible collection
ansible-galaxy collection install community.general

# Verify
ansible --version
python3 --version
```

## Step 2: Get the Code (1 minute)

```bash
git clone https://github.com/your-org/esports-lan-infrastructure.git
cd esports-lan-infrastructure
git checkout v2-simple
```

## Step 3: Configure (5 minutes)

Copy and edit the config file:

```bash
cp config.example.yaml config.yaml
nano config.yaml  # or use your favorite editor
```

**Minimal required changes:**

```yaml
organization:
  name: "Lincoln High School Esports"

proxmox:
  host: "192.168.1.5"          # YOUR Proxmox IP
  user: "root@pam"
  password: "your-password"     # YOUR Proxmox password
  node: "pve"                   # Check: Proxmox UI → Datacenter
  storage: "local-lvm"          # Check: Proxmox UI → Storage

network:
  subnet: "192.168.1.0/24"      # YOUR network
  gateway: "192.168.1.1"        # YOUR router
  
  pxe_server: "192.168.1.10"
  lancache_server: "192.168.1.11"
  file_server: "192.168.1.12"
  
  dhcp_start: "192.168.1.100"
  dhcp_end: "192.168.1.254"
```

**Save and close the file.**

## Step 4: Pre-Flight Check (1 minute)

```bash
./deploy.sh --check
```

This verifies:
- ✓ All tools installed
- ✓ Config is valid
- ✓ Can reach Proxmox
- ✓ SSH key exists

**Fix any errors before proceeding.**

## Step 5: Deploy! (15-20 minutes)

```bash
./deploy.sh
```

**What happens:**
1. Creates 3 VMs in Proxmox
2. Installs Ubuntu on each
3. Configures services
4. Tests everything

**Grab a coffee ☕ - this runs unattended**

You'll see progress like:
```
► Running Pre-Flight Checks
✓ Python 3 found
✓ Ansible found
...

▶ Starting Deployment

PLAY [Deploy Esports LAN Infrastructure] ****

TASK [Create VMs in Proxmox] ****
changed: [localhost] => (item=pxe-server)
changed: [localhost] => (item=lancache-server)
...
```

## Step 6: Verify (2 minutes)

When deployment completes, verify services:

```bash
# Check PXE server
ssh ansible@192.168.1.10 'systemctl status dnsmasq'

# Check LANCache
ssh ansible@192.168.1.11 'docker ps'

# Check File Server
ssh ansible@192.168.1.12 'systemctl status smbd'
```

All should show "active (running)"

## Step 7: Configure Your Network Switch (5 minutes)

### Option A: Use PXE Server as DHCP (Recommended)

1. Log into your Ubiquiti switch
2. Go to Settings → Networks → LAN
3. **Disable** DHCP server
4. Save

Your PXE server will now handle DHCP.

### Option B: Configure Switch to Point to PXE

1. Keep switch DHCP enabled
2. Set DHCP option 66 = `192.168.1.10` (PXE server)
3. Set DHCP option 67 = `undionly.kpxe` (for BIOS) or `ipxe.efi` (for UEFI)

## Step 8: Test with One Client (5 minutes)

1. Boot a gaming PC
2. Press F12 (or F8/DEL depending on BIOS) during startup
3. Select "Boot from Network" or "PXE Boot"
4. You should see:
   ```
   PXE-E51: No DHCP or proxyDHCP offers were received
   ```
   OR a boot menu (if DHCP is working)

**If you see a menu:**
- ✅ Success! PXE is working
- Select "Boot from local disk" for now (we'll add Windows images later)

**If you see errors:**
- Check Step 7 (network switch config)
- Verify DHCP is working: `ssh ansible@192.168.1.10 'cat /var/lib/misc/dnsmasq.leases'`

## Step 9: Create User Accounts (5 minutes)

Create accounts for players:

```bash
# SSH to file server
ssh ansible@192.168.1.12

# Create single user
sudo create-user player001 password123

# Or create many users at once
sudo create-bulk-users player 200 changeme

# Verify
sudo pdbedit -L
```

## Step 10: Test Profiles (Optional)

From a client PC (or another machine):

```bash
# Test file server connection
smbclient //192.168.1.12/profiles -U player001
# Enter password when prompted
# Type 'ls' to see profile
# Type 'quit' to exit
```

## You're Done! 🎉

Your infrastructure is running. Here's what you have:

- **PXE/DHCP Server** (192.168.1.10)
  - Assigns IPs to clients
  - Will boot Windows via network (once you add images)
  
- **LANCache** (192.168.1.11)
  - Caches Steam, Epic, Riot game downloads
  - Saves 95%+ bandwidth after first download
  
- **File Server** (192.168.1.12)
  - Stores user profiles
  - Players can move between machines

## Next Steps

### For Testing
1. Boot a few client PCs via PXE
2. Download a game on one PC
3. Check LANCache logs: `ssh ansible@192.168.1.11 'docker logs lancache'`
4. Download same game on another PC (should be fast!)

### For Production
1. Add Windows images to PXE server (see docs/windows-deployment.md)
2. Configure clients to use roaming profiles
3. Test with small group before tournament
4. Monitor during event

## Troubleshooting

### "Can't reach Proxmox"
```bash
ping 192.168.1.5  # Your Proxmox IP
ssh root@192.168.1.5  # Test SSH access
```

### "VM creation failed"
- Check Proxmox UI → storage has space
- Verify node name: `config.yaml` vs Proxmox UI
- Check Proxmox logs: `/var/log/pve/tasks/`

### "PXE boot doesn't work"
- Verify DHCP: `ssh ansible@192.168.1.10 'systemctl status dnsmasq'`
- Check leases: `ssh ansible@192.168.1.10 'cat /var/lib/misc/dnsmasq.leases'`
- Test from client: `ipconfig /renew` (Windows) or `dhclient` (Linux)

### "Games don't cache"
- Check DNS: `nslookup steamcdn.com` should return 192.168.1.11
- Check LANCache logs: `ssh ansible@192.168.1.11 'docker logs lancache'`
- Verify containers running: `ssh ansible@192.168.1.11 'docker ps'`

### "Profiles don't load"
- Test SMB: `smbclient -L 192.168.1.12 -N`
- Check Samba: `ssh ansible@192.168.1.12 'systemctl status smbd'`
- Verify users exist: `ssh ansible@192.168.1.12 'sudo pdbedit -L'`

## Common Questions

**Q: Do I need to add Windows images?**  
A: Not initially. You can PXE boot and let machines boot from their local drives. Windows images are for wiping/reimaging machines.

**Q: How much does LANCache save?**  
A: First download uses internet. Every subsequent download of the same content is from local cache. Typically 95%+ bandwidth savings.

**Q: Can players really move between machines?**  
A: Yes! Profiles store their settings. When they log into any machine, their profile loads. Game settings, Discord, etc. all persist.

**Q: What if the file server goes down?**  
A: Players can still play, but won't have their saved settings. Games run from local drives.

**Q: How do I update games?**  
A: Games update through their clients (Steam, Epic, etc.) as normal. Updates are cached by LANCache automatically.

## Getting Help

- **Documentation**: Check `docs/` folder
- **Logs**: Each server logs to `/var/log/` and systemd journal
- **Community**: Open an issue on GitHub
- **Quick fixes**: See `docs/troubleshooting.md`

## Deployment Checklist

Before your event:

- [ ] All 3 VMs running and accessible
- [ ] PXE boot works on test client
- [ ] LANCache caches a test game download
- [ ] User accounts created
- [ ] Profile loads on test client
- [ ] Network switch configured correctly
- [ ] DHCP assigning IPs to clients
- [ ] Staff knows how to check server status
- [ ] Backup plan if something fails

**Time to full deployment: ~30 minutes**  
**Time to test and verify: ~30 minutes**  
**Total: 1 hour from zero to tested infrastructure**

Now go host an amazing tournament! 🎮