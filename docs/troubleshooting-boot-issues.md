# VM Boot Issues and Cloud-Init Template Troubleshooting

## Overview

This guide helps resolve common boot issues with Proxmox VMs, particularly the "infinite boot loop" problem where VMs can't find bootable media.

## Common Issue: Infinite Boot Loop (No Bootable Media)

### Symptoms

- VMs start but immediately show "No bootable device" or similar error
- VMs continuously reboot without reaching an OS
- Terraform successfully creates VMs but they never come online
- Cloud-init never completes initialization

### Root Causes

1. **Invalid or Missing Cloud-Init Template**
   - Template exists in Proxmox but has no boot disk attached
   - Cloud image download was corrupted or incomplete
   - Template was created incorrectly

2. **Corrupted Cloud Image Download**
   - Network issues during download
   - Incomplete file transfer
   - Invalid image URL or outdated link

3. **Wrong Boot Order Configuration**
   - VM configured to boot from wrong device
   - Boot disk not properly attached
   - SCSI/IDE/SATA controller mismatch

## Diagnostic Steps

### 1. Check Template Validity

SSH to your Proxmox host and run:

```bash
# List all VMs and templates
qm list

# Find your template (look for one with "ubuntu" or "cloud" in the name)
# Note the VMID (first column)

# Check template configuration
qm config <VMID>

# Look for boot disk configuration (should see scsi0, ide0, or sata0)
# Example of correct config:
#   scsi0: local-lvm:vm-100-disk-0,size=32G
#   boot: order=scsi0
```

### 2. Verify Cloud Image Integrity

Our deployment script now automatically verifies cloud images, but you can manually check:

```bash
# On Proxmox host, check if cloud image was properly imported
ls -lh /var/tmp/cloudimg-*/

# If images exist, verify their size (should be > 200MB)
# Check for SHA256SUMS file to verify integrity
```

### 3. Check VM Boot Configuration

For a VM that won't boot:

```bash
# On Proxmox host
qm config <VM_ID>

# Verify:
# 1. Boot disk is attached (scsi0, ide0, etc.)
# 2. Boot order is set: boot: order=scsi0
# 3. BIOS type: bios: seabios or ovmf
```

## Solutions

### Solution 1: Recreate Cloud-Init Template (Recommended)

The deployment script now includes validation. To force recreation:

```bash
# 1. SSH to Proxmox and remove the invalid template
ssh root@<proxmox-host>
qm list | grep -i ubuntu  # Find the template VMID
qm destroy <VMID> --purge

# 2. Re-run deployment - it will recreate the template
./deploy.sh
```

The script now:

- Downloads cloud images with progress indicator
- Verifies checksums automatically
- Validates file integrity
- Checks template boot disk configuration
- Offers to download ISO as alternative if template creation fails

### Solution 2: Use Ubuntu Server ISO Instead

If cloud-init templates continue to fail, use a standard Ubuntu Server ISO:

```bash
# Download and upload ISO to Proxmox
./scripts/download_ubuntu_iso.sh <proxmox-host> root@<proxmox-host> local 22.04

# This script will:
# - Download the official Ubuntu Server ISO
# - Verify its checksum
# - Upload it to Proxmox
# - Provide the configuration string to use
```

Then add to your `config.yaml`:

```yaml
proxmox:
  host: "192.168.1.5"
  node_name: "pve"
  ubuntu_iso: "local:iso/ubuntu-22.04.5-live-server-amd64.iso"
  # Remove or comment out template_name when using ISO
  # template_name: "ubuntu-22.04-cloudinit"
```

**Note:** Using an ISO instead of cloud-init means:

- VMs may require manual installation (unless using autoinstall)
- Deployment will take longer
- You may need to configure networking manually
- Consider this a fallback option when cloud-init templates fail

### Solution 3: Manual Template Creation

If automated template creation fails, create manually:

```bash
ssh root@<proxmox-host>

# Set variables
VMID=$(pvesh get /cluster/nextid)
STORAGE="local-lvm"  # or your storage name
TEMPLATE_NAME="ubuntu-22.04-cloudinit"
IMAGE_URL="https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"

# Download and verify cloud image
cd /var/tmp
wget "${IMAGE_URL}"
wget "${IMAGE_URL%/*}/SHA256SUMS"

# Verify checksum
IMAGE_FILE=$(basename "${IMAGE_URL}")
EXPECTED=$(grep "${IMAGE_FILE}" SHA256SUMS | awk '{print $1}')
ACTUAL=$(sha256sum "${IMAGE_FILE}" | awk '{print $1}')

if [ "${EXPECTED}" != "${ACTUAL}" ]; then
  echo "ERROR: Checksum mismatch! Re-download the image."
  exit 1
fi

echo "✓ Checksum verified"

# Create VM
qm create ${VMID} --name "${TEMPLATE_NAME}" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0

# Import disk
qm importdisk ${VMID} "${IMAGE_FILE}" ${STORAGE}

# Attach disk and configure boot
qm set ${VMID} --scsi0 ${STORAGE}:vm-${VMID}-disk-0
qm set ${VMID} --boot order=scsi0
qm set ${VMID} --agent 1
qm set ${VMID} --ostype l26

# Add cloud-init drive
qm set ${VMID} --ide2 ${STORAGE}:cloudinit

# Convert to template
qm template ${VMID}

# Verify
qm config ${VMID} | grep -E "(scsi0|boot)"
```

### Solution 4: Use Existing VM as Template

If you have a working Ubuntu VM:

```bash
# On Proxmox host
qm clone <source-vm-id> <new-vmid> --name ubuntu-22.04-cloudinit --full
qm template <new-vmid>
```

## Prevention

### Automated Validation

The deployment script now includes:

1. **Download Verification**
   - Checksum validation for all cloud images
   - File size validation (must be > 200MB)
   - File type validation (QCOW2/disk image format)
   - Automatic re-download on corruption

2. **Template Validation**
   - Checks if template has boot disk configured
   - Validates boot order settings
   - Removes and recreates invalid templates
   - Offers ISO alternative on failure

3. **Helpful Error Messages**
   - Clear indication of what went wrong
   - Specific commands to fix issues
   - Alternative solutions provided

### Best Practices

1. **Use Static IPs for Proxmox**
   - Avoid hostnames that require DNS resolution
   - Configure `proxmox.host` with IP address: `192.168.1.5`

2. **Test SSH Access First**

   ```bash
   ssh root@<proxmox-host> "qm list"
   ```

3. **Verify Network Connectivity**
   - Ensure deployment machine can reach cloud-images.ubuntu.com
   - Check firewall rules
   - Verify proxy settings if applicable

4. **Monitor Disk Space**
   - Ensure Proxmox has enough space for cloud images (~2GB per image)
   - Check storage before deployment:

     ```bash
     ssh root@<proxmox-host> "df -h"
     ```

5. **Keep Templates Updated**
   - Ubuntu updates cloud images regularly
   - Recreate templates periodically for security updates
   - Remove old unused templates to save space

## Troubleshooting Commands Reference

```bash
# List all VMs and templates
ssh root@<proxmox-host> "qm list"

# Check specific VM/template configuration
ssh root@<proxmox-host> "qm config <VMID>"

# Check VM boot disk
ssh root@<proxmox-host> "qm config <VMID> | grep -E '(scsi|ide|sata|boot)'"

# View VM console (for boot errors)
# Access Proxmox web UI: https://<proxmox-host>:8006
# Navigate to VM > Console

# Check cloud-init status (if VM boots)
ssh user@<vm-ip> "cloud-init status"

# Remove a template or VM
ssh root@<proxmox-host> "qm destroy <VMID> --purge"

# Check Proxmox storage
ssh root@<proxmox-host> "pvesm status"

# View detailed VM information
ssh root@<proxmox-host> "qm showcmd <VMID>"
```

## Getting Help

If issues persist after trying these solutions:

1. **Check Logs**
   - Deployment script output
   - Terraform logs: `terraform-plugin-proxmox.log`
   - Proxmox logs: `/var/log/pve/tasks/`

2. **Gather Information**
   - Output of `qm config <VMID>`
   - Screenshot of boot error from Proxmox console
   - Full deployment script output
   - Network configuration

3. **Common Configuration Issues**
   - Verify `config.yaml` has all required fields
   - Check network settings match your environment
   - Ensure SSH keys are properly configured
   - Confirm Proxmox credentials are correct

4. **Report Issues**
   - Include error messages and logs
   - Describe steps taken before issue occurred
   - Specify environment details (Proxmox version, network setup)
