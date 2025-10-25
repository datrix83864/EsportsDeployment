# Non-Bootable Template Quick Fix Guide

## Problem
VMs created from cloud-init template show **"no bootable drive"** error and boot loop endlessly.

## Root Cause
The cloud-init template was created but has **no boot disk attached**. This happens when:
1. Cloud image download was corrupted (checksum mismatch)
2. `qm importdisk` failed silently
3. `qm set --scsi0` command didn't attach the disk properly

## Immediate Fix

### Quick Command (Copy & Paste)
Replace `10.100.0.5` with your Proxmox IP:

```bash
# Run the diagnostic and fix script
chmod +x scripts/fix_bootable_template.sh
./scripts/fix_bootable_template.sh root@10.100.0.5 ubuntu-22.04-cloudinit
```

### Manual Fix (If you prefer SSH)

```bash
# SSH to Proxmox
ssh root@10.100.0.5

# Find the template VMID
qm list | grep ubuntu-22.04-cloudinit
# Example output: 101  ubuntu-22.04-cloudinit  0     0       0.00    0

# Check configuration (replace 101 with your VMID)
qm config 101

# If NO scsi0/ide0/sata0 line appears, the template is broken!

# Delete the broken template
qm destroy 101 --purge

# Clean up temp files
rm -rf /var/tmp/cloudimg-*

# Exit SSH
exit
```

Then recreate the template:

```bash
# Back on your machine, run deployment again
./deploy.sh
```

## Step-by-Step Solution

### Option 1: Automatic Fix (Recommended)

```bash
# 1. Run the fix script
./scripts/fix_bootable_template.sh root@<proxmox-ip> ubuntu-22.04-cloudinit

# 2. Follow the prompts to delete and cleanup

# 3. Recreate template
./deploy.sh

# 4. If template creation still fails, the cloud image is corrupted
#    Switch to ISO-based deployment (see Option 2)
```

### Option 2: Switch to ISO-Based Deployment (Most Reliable)

If cloud-init template keeps failing:

```bash
# 1. Download Ubuntu Server ISO
./scripts/download_ubuntu_iso.sh <proxmox-ip> root@<proxmox-ip> local 22.04

# 2. Edit config.yaml and add:
proxmox:
  ubuntu_iso: 'local:iso/ubuntu-22.04.5-live-server-amd64.iso'

# 3. Run deployment
./deploy.sh
```

### Option 3: Manual Template Creation

If you want full control:

```bash
ssh root@<proxmox-ip>

# Download image manually
cd /var/tmp
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Get next VMID
VMID=$(pvesh get /cluster/nextid)
echo "Using VMID: $VMID"

# Create VM
qm create $VMID --name ubuntu-22.04-cloudinit --memory 2048 --cores 2

# Import disk - THIS IS THE CRITICAL STEP
qm importdisk $VMID jammy-server-cloudimg-amd64.img local-lvm

# ⚠️ VERIFY the import worked:
ls -lh /dev/zvol/local-lvm/vm-$VMID-disk-0
# If this file doesn't exist, the import failed!

# Attach the disk - THIS IS WHERE IT USUALLY FAILS
qm set $VMID --scsi0 local-lvm:vm-$VMID-disk-0

# Set boot order - CRITICAL FOR BOOTING
qm set $VMID --boot order=scsi0

# Enable QEMU agent
qm set $VMID --agent 1

# Add cloud-init drive (optional but recommended)
qm set $VMID --ide2 local-lvm:cloudinit

# Convert to template
qm template $VMID

# VERIFY the template has a boot disk:
qm config $VMID | grep scsi0
# Should show: scsi0: local-lvm:vm-XXX-disk-0,size=2G

# If scsi0 line is missing, THE TEMPLATE IS BROKEN!
```

## Verification

After fixing, verify the template is correct:

```bash
ssh root@<proxmox-ip>

# Find template VMID
VMID=$(qm list | grep ubuntu-22.04-cloudinit | awk '{print $1}')

# Check configuration
qm config $VMID

# Look for these CRITICAL lines:
# ✅ scsi0: local-lvm:vm-XXX-disk-0,size=2G
# ✅ boot: order=scsi0

# If both are present, template is good!
# If scsi0 is missing, DELETE AND RECREATE
```

## After Fix - Recreate VMs

Once template is fixed, you need to recreate the VMs:

```bash
# Option A: Use Terraform to recreate
cd terraform
terraform destroy  # Remove broken VMs
terraform apply    # Create new VMs from fixed template

# Option B: Manual recreation
ssh root@<proxmox-ip>
qm destroy 102 103 104  # Destroy broken VMs (adjust VMIDs)
exit

# Then run deployment to create new VMs
./deploy.sh
```

## Prevention

To prevent this in future:

1. **Always verify template after creation:**
   ```bash
   qm config <template-vmid> | grep scsi0
   ```

2. **Use ISO instead of cloud-init** if your network has issues downloading cloud images

3. **Add this to config.yaml** to use a specific dated image instead of `/current/`:
   ```yaml
   proxmox:
     ubuntu_image_url: 'https://cloud-images.ubuntu.com/jammy/20241025/jammy-server-cloudimg-amd64.img'
   ```

## Still Having Issues?

If problems persist:

1. **Check Proxmox logs:**
   ```bash
   ssh root@<proxmox-ip> 'journalctl -xe | tail -100'
   ```

2. **Check disk space:**
   ```bash
   ssh root@<proxmox-ip> 'df -h'
   ```

3. **Try ISO-based deployment** (Option 2 above) - most reliable method

4. **Open an issue** with:
   - Output of `qm config <template-vmid>`
   - Output of `qm list`
   - Any error messages from deployment
