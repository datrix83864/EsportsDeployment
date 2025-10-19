# Slow Connection Optimization

## Problem

If you have a slow internet connection, downloading the ~700MB Ubuntu cloud image can take a long time and may timeout before completing.

## Solution Applied

The Ansible playbook has been optimized for slow connections with these settings:

### Wget Configuration

```bash
wget --progress=bar:force:noscroll \
     --tries=20 \                    # Retry up to 20 times
     --read-timeout=3600 \           # 1 hour read timeout
     --dns-timeout=300 \             # 5 minute DNS timeout
     --connect-timeout=300 \         # 5 minute connect timeout
     --waitretry=30 \                # Wait 30 seconds between retries
     -c \                            # Continue partial downloads (resume)
     -O "image.img" \
     "url"
```

### Key Features

1. **No Hard Timeout on Active Downloads**
   - As long as data is being received, the download won't timeout
   - `--read-timeout=3600` allows up to 1 hour of no data before timeout
   - This is effectively "no timeout" for active downloads

2. **Resume Support (`-c`)**
   - If the download is interrupted, it will resume from where it left off
   - You won't lose progress on disconnections
   - Can pause and resume later

3. **20 Retry Attempts**
   - Automatically retries up to 20 times on failure
   - Exponential backoff with `--waitretry=30`
   - Very resilient to network hiccups

4. **Ansible Retry Layer**
   - Even if wget exhausts all retries, Ansible will retry 3 more times
   - Total: Up to 60 attempts before giving up (20 wget × 3 Ansible)

## Expected Download Times

| Connection Speed | Time for 700MB | Will Complete? |
| ---------------- | -------------- | -------------- |
| 1 Mbps           | ~90 minutes    | ✅ Yes          |
| 2 Mbps           | ~45 minutes    | ✅ Yes          |
| 5 Mbps           | ~18 minutes    | ✅ Yes          |
| 10 Mbps          | ~9 minutes     | ✅ Yes          |
| 50 Mbps          | ~2 minutes     | ✅ Yes          |
| 100 Mbps         | ~1 minute      | ✅ Yes          |

Even on a 1 Mbps connection, the download will complete successfully!

## What You'll See

### On a Slow Connection

```
⬇️  Starting download... (this may take a while on slow connections)
  0% [                                        ] 0K
  1% [                                        ] 7M     ETA: 45m 30s
  5% [=>                                      ] 35M    ETA: 38m 15s
 10% [===>                                    ] 70M    ETA: 32m 10s
 25% [=========>                              ] 175M   ETA: 22m 45s
 50% [====================>                   ] 350M   ETA: 11m 20s
 75% [==============================>         ] 525M   ETA: 5m 30s
 90% [====================================>   ] 630M   ETA: 2m 10s
100% [========================================] 700M   
✓ Download completed successfully (700 MiB)
```

### Progress Indicators

- **Percentage**: Shows how much is complete
- **Progress Bar**: Visual representation
- **Data Downloaded**: Current amount transferred
- **ETA**: Estimated time remaining (updates as download progresses)

## If Download Gets Interrupted

Don't worry! The download will automatically resume:

```
⬇️  Starting download...
 25% [=========>                              ] 175M   
# Network hiccup or interruption occurs
--2025-10-19 10:30:45--  Continuing in background...
 25% [=========>                              ] 175M   # Resumes from 175M, not 0!
 30% [===========>                            ] 210M   
 50% [====================>                   ] 350M   
# Continues...
```

The `-c` flag ensures partial downloads are saved and resumed.

## Manual Download (If Needed)

If you have persistent network issues or extremely slow connection, you can pre-download the image:

### Option 1: Download on Different Machine

If you have access to a faster connection elsewhere:

1. **Download on fast machine:**
   ```bash
   wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
   ```

2. **Transfer to Proxmox host** (via USB drive, SCP, etc.):
   ```bash
   # Via SCP from your machine
   scp jammy-server-cloudimg-amd64.img root@<proxmox-ip>:/var/tmp/
   
   # Or via USB drive
   # Copy file to USB, plug into Proxmox server, mount and copy
   ```

3. **Place in correct location on Proxmox:**
   ```bash
   ssh root@<proxmox-ip>
   mkdir -p /var/tmp/cloudimg-manual
   mv /var/tmp/jammy-server-cloudimg-amd64.img /var/tmp/cloudimg-manual/
   ```

4. **Run deployment** - The playbook will detect the existing file and skip download!

### Option 2: Download Directly on Proxmox

SSH to your Proxmox host and download there:

```bash
ssh root@<proxmox-ip>

# Create directory
mkdir -p /var/tmp/cloudimg-manual
cd /var/tmp/cloudimg-manual

# Start download (can take hours on slow connection, but will complete)
wget -c https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# You can disconnect and let it run
# To check progress later:
ls -lh jammy-server-cloudimg-amd64.img

# The file will be used by the next deployment run
```

### Option 3: Screen Session (For Overnight Downloads)

Start the download in a screen session so you can disconnect:

```bash
ssh root@<proxmox-ip>

# Install screen if not present
apt-get install -y screen

# Start screen session
screen -S download

# Start download
mkdir -p /var/tmp/cloudimg-manual
cd /var/tmp/cloudimg-manual
wget -c https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Detach from screen: Press Ctrl+A, then D
# Close SSH, download continues in background

# Later, reconnect and check progress:
ssh root@<proxmox-ip>
screen -r download  # Reattach to see progress

# When complete, exit screen
exit
```

## Bandwidth Optimization Tips

### 1. Schedule During Off-Peak Hours

Download when network is less congested:
- Late night / early morning
- Weekends
- School holidays

### 2. Pause Other Network Activity

- Stop streaming services
- Pause cloud backups
- Disable Windows Update temporarily
- Close browser tabs with auto-refresh

### 3. Use Wired Connection

If downloading from your deployment machine:
- Use Ethernet instead of WiFi
- WiFi can be slower and less reliable

### 4. Check for ISP Throttling

Some ISPs throttle certain types of traffic:
- Large downloads may be rate-limited
- Try downloading at different times
- Use VPN if throttling is suspected

## Monitoring Download Progress

### From Ansible Output

The playbook shows live progress:
```
⬇️  Starting download...
 15% [=====>                                  ] 105M   ETA: 28m 30s
```

### From Proxmox Host

SSH to Proxmox and check file size:

```bash
# Watch file grow in real-time
watch -n 5 'ls -lh /var/tmp/cloudimg-*/jammy-server-cloudimg-amd64.img'

# Or check once
ls -lh /var/tmp/cloudimg-*/jammy-server-cloudimg-amd64.img

# Expected final size: ~730-750MB
```

## Troubleshooting

### Download Keeps Failing

If download repeatedly fails even with retries:

1. **Check DNS Resolution:**
   ```bash
   nslookup cloud-images.ubuntu.com
   ```

2. **Test Connectivity:**
   ```bash
   ping -c 5 cloud-images.ubuntu.com
   ```

3. **Try Alternative Mirror:**
   Edit the playbook or use environment variable to set different URL:
   ```bash
   # US Mirror
   https://us.cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
   
   # UK Mirror
   https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img
   ```

4. **Check Disk Space:**
   ```bash
   df -h /var/tmp
   # Need at least 1GB free
   ```

### Download Stalls (No Progress)

If progress stops and doesn't resume:

1. **Check Network:**
   ```bash
   ping -c 5 8.8.8.8
   ```

2. **Kill and Restart:**
   ```bash
   # Find wget process
   ps aux | grep wget
   
   # Kill it
   kill <pid>
   
   # Re-run deployment - will resume from where it left off
   ```

### Extremely Slow (< 100 KB/s)

For connections slower than 1 Mbps:

1. **Consider ISO Alternative:**
   - Download Ubuntu Server ISO once (may take hours)
   - Use for deployments
   - See `docs/using-iso-with-autoinstall.md`

2. **Use Local Mirror:**
   - If your organization has local Ubuntu mirrors
   - Much faster on campus networks

## Summary

The playbook is now optimized for slow connections:

- ✅ **No timeout** as long as data is being received
- ✅ **Automatic resume** on interruptions
- ✅ **20 retries** with exponential backoff
- ✅ **3 Ansible retries** for ultimate resilience
- ✅ **Progress display** so you know it's working
- ✅ **Works on 1 Mbps** connections (just takes longer)

Even on the slowest connections, the download will eventually complete. Just be patient and let it run!

**Pro Tip:** If you know you have a slow connection, start the deployment and let it run overnight. You'll wake up to a completed template! 🌙 → 🌅
