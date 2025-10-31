# Diagnosing Slow Download Speeds on Proxmox Server

## Quick Diagnostics

Run these commands on your Proxmox host to identify the bottleneck:

### 1. Test Internet Speed

```bash
# SSH to Proxmox
ssh root@<proxmox-ip>

# Install speedtest-cli if not present
apt-get update && apt-get install -y speedtest-cli

# Run speed test
speedtest-cli

# Expected output:
# Download: XX.XX Mbps
# Upload: XX.XX Mbps
# If download is < 10 Mbps, that's your issue!
```

### 2. Test DNS Resolution

```bash
# Check DNS response time
time nslookup cloud-images.ubuntu.com

# Should be < 1 second
# If > 5 seconds, DNS is slow
```

### 3. Test Connection to Ubuntu Servers

```bash
# Test ping to cloud-images server
ping -c 10 cloud-images.ubuntu.com

# Look for:
# - High latency (> 100ms)
# - Packet loss (should be 0%)
# - Timeouts
```

### 4. Check Network Interface Speed

```bash
# Check link speed
ethtool <interface>  # Usually eth0, ens18, enp0s3, etc.

# Find your interface first:
ip link show

# Then check it:
ethtool eth0 | grep Speed

# Expected output:
# Speed: 1000Mb/s (Gigabit)
# Speed: 10000Mb/s (10 Gigabit)
# 
# If you see:
# Speed: 100Mb/s - You're limited to Fast Ethernet (check cable/switch)
# Speed: 10Mb/s - Severe issue (bad cable or auto-negotiation problem)
```

### 5. Check for Network Congestion

```bash
# Install iftop to see real-time bandwidth usage
apt-get install -y iftop

# Run it
iftop -i eth0  # Replace eth0 with your interface

# Press 'q' to quit
# Shows what's using bandwidth on your network
```

## Common Causes & Solutions

### 🔴 Issue 1: ISP Speed Limitation

**Symptom:**

```bash
speedtest-cli
Download: 5.23 Mbps  # This is just slow internet!
```

**Solution:**

- This is your internet connection speed
- Download will take longer (see docs/slow-connection-optimization.md)
- The playbook now handles this automatically
- Consider downloading overnight or during off-peak hours

**Typical Speeds:**

- Residential: 10-100 Mbps
- Business: 100-1000 Mbps
- School/Campus: Can vary wildly (1-1000 Mbps)

---

### 🔴 Issue 2: DNS Resolution Slow

**Symptom:**

```bash
time nslookup cloud-images.ubuntu.com
# Takes 5-10 seconds before resolving
```

**Cause:** Slow or unresponsive DNS server

**Solution:**

```bash
# Check current DNS servers
cat /etc/resolv.conf

# If using ISP DNS or slow DNS, switch to Google/Cloudflare
nano /etc/resolv.conf

# Replace with:
nameserver 8.8.8.8
nameserver 8.8.4.4
# or
nameserver 1.1.1.1
nameserver 1.0.0.1

# Test again
time nslookup cloud-images.ubuntu.com
# Should be < 1 second now
```

---

### 🔴 Issue 3: Network Cable/Switch Limited to 100 Mbps

**Symptom:**

```bash
ethtool eth0 | grep Speed
Speed: 100Mb/s  # Should be 1000Mb/s!
```

**Causes:**

1. **Bad Ethernet Cable** (Cat5 instead of Cat5e/Cat6)
2. **Old Switch** (only supports Fast Ethernet)
3. **Auto-negotiation issue**

**Solutions:**

#### A. Check Cable Quality

- Use Cat5e, Cat6, or better cables
- Replace any Cat5 cables
- Check for physical damage

#### B. Check Switch

```bash
# Check switch specifications
# Ensure switch supports Gigabit (1000 Mbps)
# Look for "10/100/1000" on switch label
```

#### C. Force Gigabit Speed (if auto-negotiation fails)

```bash
# Check current settings
ethtool eth0

# Force 1000 Mbps full duplex
ethtool -s eth0 speed 1000 duplex full autoneg off

# Verify
ethtool eth0 | grep Speed
# Should now show: Speed: 1000Mb/s

# Make permanent (add to /etc/network/interfaces or use systemd)
```

---

### 🔴 Issue 4: WiFi Instead of Wired Connection

**Symptom:**

```bash
ip link show
# Shows: wlan0 or similar instead of eth0
```

**Problem:** Proxmox on WiFi is MUCH slower than wired

**Solution:**

- Always use wired Ethernet for servers
- WiFi has:
  - Higher latency
  - Lower throughput
  - More packet loss
  - Unreliable for large downloads

---

### 🔴 Issue 5: ISP Throttling

**Symptom:**

- Speed test shows 100 Mbps
- But downloads from Ubuntu are only 5 Mbps
- Downloads start fast then slow down

**Causes:**

1. ISP throttles certain domains/services
2. ISP rate-limits large downloads
3. Peak usage hours (evening congestion)

**Test:**

```bash
# Test download speed from different sources
wget -O /dev/null http://speedtest.tele2.net/100MB.zip
# vs
wget -O /dev/null https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
```

**Solutions:**

1. **Try Different Time:** Download at 2-6 AM (off-peak)
2. **Use VPN:** May bypass throttling (if allowed by policy)
3. **Contact ISP:** Ask about throttling policies
4. **Use Alternative Mirror:** Try different Ubuntu mirror

```bash
# US Mirror
wget https://us.cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# UK Mirror  
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Try different ones until you find fastest
```

---

### 🔴 Issue 6: Server in a VM with Limited Resources

**Symptom:**
Proxmox itself is running as a VM (nested virtualization)

**Check:**

```bash
# Check if you're in a VM
systemd-detect-virt

# If it returns anything other than "none", you're in a VM
# Examples: kvm, vmware, virtualbox
```

**Problem:**

- VM may have limited network throughput
- Host may be rate-limiting
- Virtual network adapter has overhead

**Solution:**

- If Proxmox is a VM, ensure:
  - Virtual NIC is set to virtio (fastest)
  - No bandwidth limits set on host
  - VM has adequate CPU/RAM

---

### 🔴 Issue 7: Network Congestion (Other Users/Services)

**Symptom:**

```bash
iftop -i eth0
# Shows lots of other traffic competing for bandwidth
```

**Common Culprits:**

- Windows Update on multiple machines
- Cloud backups running
- Streaming services
- Other downloads
- CCTV/security cameras uploading

**Solution:**

```bash
# Check what's using bandwidth
iftop -i eth0

# Or use vnstat for historical data
apt-get install -y vnstat
vnstat -i eth0

# Schedule downloads during off-hours
# Or temporarily pause other services
```

---

### 🔴 Issue 8: Proxmox Storage is Slow (Not Network)

**Symptom:**

- Download speed starts high then drops
- Network speed is good
- Disk I/O is high

**Check:**

```bash
# Monitor disk I/O during download
iostat -x 1

# Look for:
# %util near 100% = disk bottleneck
# High await = slow storage
```

**Common Causes:**

1. Downloading to slow storage (HDD vs SSD)
2. Storage under heavy load
3. RAID rebuild in progress
4. Disk failure

**Solution:**

```bash
# Check storage performance
dd if=/dev/zero of=/var/tmp/test bs=1M count=1000
# Should see > 100 MB/s for HDD, > 500 MB/s for SSD

# Check SMART status
smartctl -a /dev/sda  # Replace with your disk

# Check RAID status (if applicable)
cat /proc/mdstat  # For software RAID
# or
megacli -LDInfo -Lall -aALL  # For hardware RAID
```

---

### 🔴 Issue 9: Firewall/Security Software

**Symptom:**
Downloads are slow or timeout frequently

**Check:**

```bash
# Check if firewall is blocking/slowing
iptables -L -n -v

# Check for connection tracking issues
cat /proc/sys/net/netfilter/nf_conntrack_count
cat /proc/sys/net/netfilter/nf_conntrack_max

# If count is near max, increase it
echo 131072 > /proc/sys/net/netfilter/nf_conntrack_max
```

---

### 🔴 Issue 10: Geographic Distance

**Symptom:**

- High ping times (> 150ms)
- Downloads start slow and stay slow

**Check:**

```bash
# Check latency
ping -c 20 cloud-images.ubuntu.com

# Trace route to see where delay is
traceroute cloud-images.ubuntu.com
```

**Solution:**
Use geographically closer mirrors:

```bash
# North America
https://us.cloud-images.ubuntu.com/

# Europe
https://cloud-images.ubuntu.com/

# Asia Pacific
# May need to find regional mirrors

# Check Ubuntu mirror list
https://launchpad.net/ubuntu/+cdmirrors
```

---

## Diagnostic Script

Run this comprehensive diagnostic script on your Proxmox server:

```bash
#!/bin/bash
echo "======================================"
echo "Proxmox Network Diagnostics"
echo "======================================"
echo ""

echo "1. Network Interface Status:"
ip link show
echo ""

echo "2. Interface Speeds:"
for iface in $(ip -o link show | awk -F': ' '{print $2}' | grep -E '^(eth|ens|enp)'); do
    echo -n "$iface: "
    ethtool $iface 2>/dev/null | grep "Speed:" || echo "N/A"
done
echo ""

echo "3. Current DNS Servers:"
cat /etc/resolv.conf | grep nameserver
echo ""

echo "4. Internet Speed Test:"
if command -v speedtest-cli &> /dev/null; then
    speedtest-cli --simple
else
    echo "speedtest-cli not installed. Run: apt-get install speedtest-cli"
fi
echo ""

echo "5. Ping Test to Ubuntu Cloud:"
ping -c 5 cloud-images.ubuntu.com
echo ""

echo "6. DNS Resolution Time:"
time nslookup cloud-images.ubuntu.com > /dev/null 2>&1
echo ""

echo "7. Storage Performance:"
dd if=/dev/zero of=/var/tmp/speedtest bs=1M count=100 2>&1 | grep copied
rm -f /var/tmp/speedtest
echo ""

echo "8. Current Bandwidth Usage:"
if command -v vnstat &> /dev/null; then
    vnstat -i eth0 -h
else
    echo "vnstat not installed. Run: apt-get install vnstat"
fi
echo ""

echo "======================================"
echo "Diagnostic Complete"
echo "======================================"
```

Save as `/root/network-diag.sh`, make executable, and run:

```bash
chmod +x /root/network-diag.sh
/root/network-diag.sh > /root/network-report.txt
cat /root/network-report.txt
```

---

## Quick Fixes Summary

| Issue               | Quick Fix                                        |
| ------------------- | ------------------------------------------------ |
| Slow DNS            | Change to 8.8.8.8 in `/etc/resolv.conf`          |
| 100 Mbps limit      | Check cable (needs Cat5e+) and switch            |
| ISP throttling      | Download during off-peak (2-6 AM)                |
| Network congestion  | Use `iftop` to identify and pause other services |
| Slow storage        | Check with `iostat -x 1` during download         |
| Geographic distance | Use closer mirror                                |

---

## Expected Behavior

**Normal download speeds from Ubuntu mirrors:**

| Your Internet | Expected wget Speed |
| ------------- | ------------------- |
| 10 Mbps       | ~1 MB/s             |
| 50 Mbps       | ~6 MB/s             |
| 100 Mbps      | ~12 MB/s            |
| 1 Gbps        | ~50-100 MB/s        |

**Note:** 

- 8 bits = 1 byte
- 100 Mbps internet ≈ 12 MB/s actual download speed
- Overhead reduces real speed by ~10-20%

---

## Need More Help?

Share the output of the diagnostic script above and we can pinpoint the exact issue!

**What to include:**

1. Output of `speedtest-cli`
2. Output of `ethtool eth0 | grep Speed`
3. Output of `ping -c 10 cloud-images.ubuntu.com`
4. Your internet service type (fiber, cable, DSL, etc.)
5. Network topology (direct to modem, through firewall, etc.)
