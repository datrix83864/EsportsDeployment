# Cloud-Init Template Creation Troubleshooting

## Checksum Mismatch Error

### Symptom
```
CHECKSUM_MISMATCH: Image is corrupted!
Expected: 1ec24d20ccaf18428526a9d270f529d905bc3517731d16643564e1e19c179e62
Actual:   7af0e4546f4d759ef98b6a0862187a9cd2da87240187c3bba71c6b8006613dc0
```

### Root Cause
The downloaded Ubuntu cloud image file doesn't match the expected SHA256 checksum. This typically happens when:

1. **Partial Download**: Network interruption caused an incomplete download
2. **Corrupted Download**: Data corruption during transfer
3. **URL Mismatch**: Using `/current/` symlink URL that changed between download and checksum fetch
4. **Disk Space**: Insufficient space prevented complete download

### Quick Fix

#### Option 1: Automatic Cleanup and Retry (Recommended)

Run the deployment script again in interactive mode:

```bash
./deploy.sh --interactive
```

The script will now:
1. Detect the failed template creation
2. Offer to clean up corrupted files automatically
3. Retry the download and template creation

#### Option 2: Manual Cleanup

If you prefer manual control:

```bash
# Clean up the corrupted files
./scripts/cleanup_failed_template.sh root@<proxmox-ip>

# Or clean a specific VMID
./scripts/cleanup_failed_template.sh root@<proxmox-ip> 101

# Then retry deployment
./deploy.sh
```

#### Option 3: Direct SSH Cleanup

SSH to Proxmox and manually clean:

```bash
ssh root@<proxmox-ip>

# Remove all temporary cloud image directories
rm -rf /var/tmp/cloudimg-*

# Remove the failed VM if it exists
qm destroy 101 --purge  # Replace 101 with actual VMID
```

### Prevention

To avoid this issue in future deployments:

1. **Use a Specific Image URL** instead of `/current/`:
   
   In your `config.yaml`:
   ```yaml
   proxmox:
     ubuntu_image_url: 'https://cloud-images.ubuntu.com/jammy/20241025/jammy-server-cloudimg-amd64.img'
   ```
   
   Replace `20241025` with the latest date from: https://cloud-images.ubuntu.com/jammy/

2. **Check Network Stability**: Ensure reliable connection to cloud-images.ubuntu.com

3. **Verify Disk Space**: Ensure Proxmox has >5GB free space in `/var/tmp/`

4. **Use Local ISO Instead**: If cloud images continue to fail, switch to ISO-based deployment:
   
   ```bash
   # Download Ubuntu Server ISO
   ./scripts/download_ubuntu_iso.sh <proxmox-ip> root@<proxmox-ip> local 22.04
   
   # Add to config.yaml
   proxmox:
     ubuntu_iso: 'local:iso/ubuntu-22.04.5-live-server-amd64.iso'
   ```

### Understanding the Fix

The updated Ansible playbook now:

1. **Graceful Checksum Handling**: If checksum can't be found in SHA256SUMS (common with `/current/` URLs), it skips checksum verification but still validates file size
2. **Automatic Cleanup**: On checksum mismatch, corrupted files are automatically deleted
3. **Better Error Messages**: Clear indication of what went wrong and how to fix it
4. **Retry Support**: Built-in retry mechanism with cleanup in interactive mode

### Technical Details

The checksum mismatch occurs because:

- URL: `https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img`
- This is a **symlink** pointing to the latest dated release
- SHA256SUMS contains checksums for dated files (e.g., `jammy-server-cloudimg-amd64-20241025.img`)
- When we download via symlink, the filename doesn't match what's in SHA256SUMS

The fix allows graceful fallback to file size validation when exact checksum match isn't available.

### Still Having Issues?

If the problem persists:

1. Check Proxmox logs: `ssh root@<proxmox-ip> 'journalctl -xe'`
2. Verify network: `ssh root@<proxmox-ip> 'wget -O- https://cloud-images.ubuntu.com/jammy/current/'`
3. Check disk space: `ssh root@<proxmox-ip> 'df -h /var/tmp'`
4. Open an issue with full error output
