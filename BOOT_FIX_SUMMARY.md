# Boot Issue Fixes - Summary

## Changes Made

This update adds comprehensive validation and alternative solutions for the VM boot loop issue where VMs couldn't find bootable media.

## What Was Added

### 1. Enhanced Cloud Image Validation (`scripts/create_proxmox_cloudinit_template.sh`)

The cloud-init template creation script now includes:

- **Checksum Verification**: Downloads SHA256SUMS from Ubuntu and validates image integrity
- **Automatic Retry**: Re-downloads corrupted files automatically
- **File Format Validation**: Checks if the downloaded file is a valid disk image
- **Size Validation**: Ensures files are not truncated (must be > 200MB)
- **Detailed Error Messages**: Clear feedback when validation fails

### 2. Ubuntu ISO Download Script (`scripts/download_ubuntu_iso.sh`)

New script to download and prepare Ubuntu Server ISO as an alternative to cloud-init templates:

**Features:**

- Downloads official Ubuntu Server ISO (supports 20.04, 22.04, 24.04)
- Verifies checksum before upload
- Uploads to Proxmox ISO storage
- Validates upload integrity
- Provides configuration instructions

**Usage:**

```bash
./scripts/download_ubuntu_iso.sh <proxmox-host> root@<proxmox-host> local 22.04
```

### 3. Enhanced Deploy Script Validation (`deploy.sh`)

The main deployment script now:

**Template Validation:**

- Checks if existing templates have boot disks configured
- Removes and recreates invalid templates automatically
- Validates newly created templates before proceeding

**Fallback Options:**

- Offers to download Ubuntu ISO if template creation fails
- Provides manual template creation instructions
- Interactive prompts for next steps

**Better Error Messages:**

- Clear explanation of what went wrong
- Specific commands to fix issues
- Alternative solutions offered

### 4. Comprehensive Documentation

**New File: `docs/troubleshooting-boot-issues.md`**

Complete guide covering:

- Symptoms and root causes of boot issues
- Step-by-step diagnostic procedures
- Multiple solution paths (template recreation, ISO alternative, manual creation)
- Prevention best practices
- Command reference
- Troubleshooting workflows

**Updated: `docs/troubleshooting.md`**

General troubleshooting guide with:

- Quick links to specific issues
- Common issues organized by symptom
- Network, Terraform, and Ansible troubleshooting
- Verbose logging instructions
- Getting help checklist

**Updated: `README.md`**

Added link to boot troubleshooting guide in documentation section.

## How It Works

### Automatic Validation Flow

```
1. Deploy script runs
   ↓
2. Check if cloud-init template exists
   ↓
3. If exists → Validate it has boot disk
   ├─ Valid → Continue
   └─ Invalid → Remove & recreate
   ↓
4. If doesn't exist → Create template
   ├─ Download cloud image
   ├─ Verify checksum
   ├─ Validate file format
   └─ Import to Proxmox
   ↓
5. Validate newly created template
   ├─ Success → Continue deployment
   └─ Failed → Offer ISO alternative
```

### Using ISO Alternative

If cloud-init templates fail, users can now:

1. **Download Ubuntu Server ISO:**
   ```bash
   ./scripts/download_ubuntu_iso.sh 192.168.1.5 root@192.168.1.5 local 22.04
   ```

2. **Update config.yaml:**
   ```yaml
   proxmox:
     ubuntu_iso: "local:iso/ubuntu-22.04.5-live-server-amd64.iso"
     # Remove or comment out template_name
   ```

3. **Re-run deployment:**
   ```bash
   ./deploy.sh
   ```

## Why This Solves the Boot Loop

The infinite boot loop was caused by:

1. **Invalid cloud images**: Downloaded files were corrupted
2. **Missing boot disks**: Templates existed but had no bootable media attached
3. **No verification**: System assumed templates were valid without checking

Our fixes:

- ✅ Verify cloud images before using them
- ✅ Validate templates have bootable disks
- ✅ Automatically fix invalid templates
- ✅ Provide ISO fallback when cloud images fail
- ✅ Give users clear instructions to resolve issues

## Testing the Fixes

### Scenario 1: Corrupted Cloud Image

**Before:** VMs created but infinite boot loop
**After:** 

1. Checksum validation fails
2. Automatic re-download triggered
3. If still fails, offers ISO alternative
4. Clear error messages guide user

### Scenario 2: Invalid Template

**Before:** Deploy succeeds but VMs can't boot
**After:**

1. Template validation detects missing boot disk
2. Template automatically removed
3. Fresh template created with validation
4. Deploy only continues if template is valid

### Scenario 3: Network Issues Downloading Cloud Image

**Before:** Partial download creates invalid template
**After:**

1. File size validation catches incomplete download
2. Checksum verification fails
3. User offered ISO alternative
4. Instructions provided for manual fix

## Migration for Existing Deployments

If you already have VMs with boot issues:

1. **Check your templates:**
   ```bash
   ssh root@<proxmox-ip> "qm list | grep -i template"
   ssh root@<proxmox-ip> "qm config <VMID> | grep -E '(scsi|boot)'"
   ```

2. **If template is invalid, remove it:**
   ```bash
   ssh root@<proxmox-ip> "qm destroy <VMID> --purge"
   ```

3. **Re-run deployment:**
   ```bash
   ./deploy.sh
   ```
   
   The enhanced script will:
   - Create a new validated template
   - Or offer to download ISO if that fails

## Configuration Options

### Use Cloud-Init Template (Default)

```yaml
proxmox:
  host: "192.168.1.5"
  node_name: "pve"
  vm_storage: "local-lvm"
  template_name: "ubuntu-22.04-cloudinit"  # Optional, defaults to this
  ubuntu_image_url: "https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img"
```

### Use Ubuntu Server ISO (Alternative)

```yaml
proxmox:
  host: "192.168.1.5"
  node_name: "pve"
  vm_storage: "local-lvm"
  iso_storage: "local"
  ubuntu_iso: "local:iso/ubuntu-22.04.5-live-server-amd64.iso"
  # Don't set template_name when using ISO
```

## Future Improvements

Potential enhancements for consideration:

- [ ] Support for other Linux distributions
- [ ] Automated ISO download during deployment
- [ ] Cloud-init autoinstall configuration for ISOs
- [ ] Template versioning and automatic updates
- [ ] Health check script for existing deployments
- [ ] Automated template cleanup for old versions

## Files Modified

- `scripts/create_proxmox_cloudinit_template.sh` - Added validation
- `deploy.sh` - Enhanced template checking and error handling
- `README.md` - Added boot troubleshooting link
- `docs/troubleshooting.md` - General troubleshooting guide
- `docs/troubleshooting-boot-issues.md` - NEW: Dedicated boot issue guide
- `scripts/download_ubuntu_iso.sh` - NEW: ISO download utility

## Questions & Support

If you encounter boot issues:

1. Check `docs/troubleshooting-boot-issues.md` first
2. Run deployment with verbose flag: `./deploy.sh --verbose`
3. Gather diagnostic info and check error messages
4. Use the provided commands to validate your setup

The enhanced error messages will guide you to the right solution.
