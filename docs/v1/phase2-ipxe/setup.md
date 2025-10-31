# iPXE Boot Server Setup Guide

This guide walks you through setting up the iPXE boot server for network booting client machines.

## What You're Setting Up

The iPXE boot server provides three key services:

1. **DHCP Server** - Assigns IP addresses to client machines
2. **TFTP Server** - Serves boot files (small files)
3. **HTTP Server** - Serves Windows images (large files, faster than TFTP)

Think of it like a vending machine that hands out fresh Windows installations to every computer that asks for one!

## Prerequisites

Before you start:

- [ ] Proxmox server is running
- [ ] Network is configured (switches, cables)
- [ ] `config.yaml` is configured with your settings
- [ ] Phase 1 is complete

## Step 1: Verify Configuration

Make sure your `config.yaml` has the iPXE settings:

```yaml
network:
  ipxe_server_ip: "192.168.1.10"
  dhcp_range_start: "192.168.1.100"
  dhcp_range_end: "192.168.1.254"
  gateway: "192.168.1.1"
  dns_primary: "8.8.8.8"
  dns_secondary: "8.8.4.4"

vms:
  ipxe_server:
    cores: 2
    memory: 2048
    disk_size: 32
```

Validate it:

```bash
python3 scripts/validate_config.py config.yaml
```

## Step 2: Deploy iPXE Server VM

### Option A: Automated Deployment (Recommended)

Deploy everything with one command:

```bash
./deploy.sh --component ipxe
```

This will:

1. Create the VM in Proxmox using Terraform
2. Install all required software
3. Configure DHCP, TFTP, and HTTP
4. Start all services

⏱️ **Time**: 10-15 minutes

### Option B: Manual Step-by-Step

If you prefer to do it manually or need to troubleshoot:

#### 2.1: Create VM with Terraform

```bash
cd terraform

# Initialize Terraform
terraform init

# Create just the iPXE VM
terraform apply -target=module.ipxe_vm

# Note the VM IP address
terraform output ipxe_server_ip
```

#### 2.2: Run Setup Script

SSH into the new VM:

```bash
ssh ansible@192.168.1.10
```

Run the setup script:

```bash
cd /tmp
# Copy the setup script to the VM (from your workstation)
# Then run:
sudo bash setup.sh
```

#### 2.3: Deploy Configuration with Ansible

Back on your workstation:

```bash
cd ansible

# Run the iPXE playbook
ansible-playbook -i inventory/hosts playbooks/deploy_ipxe.yml
```

## Step 3: Verify Installation

Run the test script:

```bash
ssh ansible@192.168.1.10 'bash /usr/local/bin/test_pxe.sh'
```

You should see all tests pass:

```
✓ dnsmasq (DHCP) is running
✓ tftpd-hpa (TFTP) is running
✓ nginx (HTTP) is running
✓ Port 67 (DHCP) is listening
✓ Port 69 (TFTP) is listening
✓ Port 80 (HTTP) is listening
...
✓ All tests passed!
```

## Step 4: Test DHCP (Optional)

From another machine on your network:

```bash
# Test DHCP discovery
sudo nmap --script broadcast-dhcp-discover
```

You should see your iPXE server respond with IP addresses in your configured range.

## Step 5: Test PXE Boot

Now for the fun part - boot a client machine!

### 5.1: Configure Client BIOS

1. Turn on a client machine
2. Enter BIOS/UEFI (usually F2, DEL, or F12)
3. Find "Boot Order" settings
4. Enable "Network Boot" or "PXE Boot"
5. Move "Network Boot" to the top of the boot order
6. Save and exit

### 5.2: Boot from Network

1. Restart the client machine
2. You should see:
   - DHCP request
   - IP address assignment
   - iPXE loading
   - Your organization's boot menu!

If you see the boot menu, **congratulations!** 🎉 Your PXE server is working!

### 5.3: Test Menu Navigation

Try these menu options:

- **Network Information** - Shows the client's IP, MAC address, etc.
- **Boot from Local Disk** - Boots from the hard drive
- **Reboot** - Restarts the computer

The "Boot Windows 11" option won't work yet - we'll set that up in Phase 5.

## Troubleshooting

### Client doesn't get IP address

**Check DHCP server:**

```bash
ssh ansible@192.168.1.10
sudo systemctl status dnsmasq
```

**Check DHCP logs:**

```bash
sudo journalctl -u dnsmasq -f
```

**Common issues:**

- Another DHCP server on the network (like your router)
- Firewall blocking port 67
- Wrong network interface configured

**Solution:**

```bash
# Check which interface dnsmasq is using
sudo cat /etc/dnsmasq.conf | grep interface

# Make sure it matches your network interface
ip addr show
```

### Client gets IP but doesn't boot

**Check TFTP server:**

```bash
ssh ansible@192.168.1.10
sudo systemctl status tftpd-hpa
```

**Test TFTP manually:**

```bash
echo "get test.ipxe" | tftp 192.168.1.10
```

**Common issues:**

- TFTP files missing
- Wrong file permissions
- Firewall blocking port 69

**Solution:**

```bash
# Check files exist
ls -la /srv/tftp/

# Fix permissions
sudo chown -R tftp:tftp /srv/tftp
sudo chmod -R 755 /srv/tftp

# Check firewall
sudo ufw status
```

### Boot menu doesn't appear

**Check HTTP server:**

```bash
curl http://192.168.1.10/boot.ipxe
```

**Check nginx status:**

```bash
sudo systemctl status nginx
```

**Common issues:**

- boot.ipxe syntax error
- nginx not running
- Firewall blocking port 80

**Solution:**

```bash
# Test nginx config
sudo nginx -t

# View nginx logs
sudo tail -f /var/log/nginx/error.log

# Restart nginx
sudo systemctl restart nginx
```

### "Conflict with existing DHCP server"

If you have another DHCP server (like your router), you have a few options:

**Option 1: Disable router DHCP** (Recommended)

1. Log into your router/switch
2. Disable its DHCP server
3. Let dnsmasq handle all DHCP

**Option 2: Set DHCP relay/helper**

1. Configure your router to forward DHCP to your iPXE server
2. This is more advanced - see your router's documentation

**Option 3: Use separate VLAN**

1. Put gaming PCs on a separate VLAN
2. Configure dnsmasq to only serve that VLAN

## Monitoring

### View Status

```bash
ssh ansible@192.168.1.10
ipxe-status
```

Shows:

- Service status
- Active DHCP leases
- Recent activity
- Disk usage

### Live Logs

Watch DHCP activity:

```bash
sudo journalctl -u dnsmasq -f
```

Watch TFTP requests:

```bash
sudo journalctl -u tftpd-hpa -f
```

Watch HTTP requests:

```bash
sudo tail -f /var/log/nginx/access.log
```

### Performance Monitoring

During 200 concurrent boots:

```bash
# Monitor CPU/RAM
htop

# Monitor network
iftop

# Monitor disk I/O
iotop
```

## Network Topology

```
┌─────────────────┐
│  UniFi Switch   │
│  192.168.1.1    │
└────────┬────────┘
         │
         ├─────────────────┬──────────────────┬──────────
         │                 │                  │
    ┌────▼────┐       ┌────▼────┐       ┌────▼────┐
    │  iPXE   │       │LANCache │       │  File   │
    │ Server  │       │ Server  │       │ Server  │
    │  .10    │       │  .11    │       │  .12    │
    └─────────┘       └─────────┘       └─────────┘
         │
    ┌────▼─────────────────────────────────────────┐
    │  Client Machines (DHCP: .100 - .254)         │
    │  [PC1] [PC2] [PC3] ... [PC200]               │
    └──────────────────────────────────────────────┘
```

## Advanced Configuration

### Custom Boot Timeout

Edit `config.yaml`:

```yaml
advanced:
  pxe:
    timeout_seconds: 10  # Wait 10 seconds before auto-boot
    default_boot: "windows"  # or "local"
```

Redeploy:

```bash
./deploy.sh --component ipxe
```

### Multiple Boot Images

You can add additional Windows images later. Edit `/srv/tftp/boot.ipxe` to add menu entries.

### Static IP Reservations

Reserve specific IPs for specific machines.

Edit `/etc/dnsmasq.conf`:

```conf
# Tournament PC #1
dhcp-host=aa:bb:cc:dd:ee:01,192.168.1.101,ESPORTS-001

# Tournament PC #2  
dhcp-host=aa:bb:cc:dd:ee:02,192.168.1.102,ESPORTS-002
```

Restart dnsmasq:

```bash
sudo systemctl restart dnsmasq
```

### VLAN Support

If using VLANs, update `config.yaml`:

```yaml
network:
  vlan_id: 100
```

Redeploy to apply changes.

## Next Steps

✅ iPXE server is now running!

Next in Phase 3:

- Set up LANCache for game downloads
- Dramatically reduce internet bandwidth usage
- Cache Steam, Epic, Riot games locally

Continue to: [Phase 3 - LANCache Setup](../phase3-lancache/setup.md)

## Quick Reference

```bash
# Check status
ssh ansible@192.168.1.10 'ipxe-status'

# View DHCP leases
ssh ansible@192.168.1.10 'cat /var/lib/misc/dnsmasq.leases'

# Restart services
ssh ansible@192.168.1.10 'sudo systemctl restart dnsmasq tftpd-hpa nginx'

# Run tests
ssh ansible@192.168.1.10 'bash -c "$(cat /root/test_pxe.sh)"'

# View logs
ssh ansible@192.168.1.10 'sudo journalctl -u dnsmasq -f'
```
