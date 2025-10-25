# Troubleshooting: Missing Cloud-Init Drive

## Problem

When inspecting a cloud-init template in Proxmox, clicking on the "Cloud-Init" tab shows:
```
No CloudInit Drive found
```

VMs cloned from this template may boot but **cannot be properly configured** because cloud-init has nowhere to read its configuration from.

## Symptoms

- ✅ Template exists and shows in Proxmox
- ✅ VMs can be cloned from template
- ✅ VMs boot successfully (no boot loop)
- ❌ Cloud-init tab shows "No CloudInit Drive found"
- ❌ SSH keys not injected into VMs
- ❌ Network configuration not applied automatically
- ❌ Hostname not set correctly
- ❌ Cannot login to VMs (no SSH keys or passwords configured)

## Root Cause

The cloud-init drive (typically `ide2`) was not added to the template during creation. The Proxmox cloud-init drive is a special virtual CD-ROM device that contains the cloud-init configuration data (user-data, meta-data, network-config).

Without this drive, cloud-init inside the VM has no way to read its configuration, so it cannot:
- Inject SSH public keys
- Configure network interfaces
- Set hostname
- Run user-defined scripts
- Resize root filesystem

## How Cloud-Init Works in Proxmox

1. **Cloud-Init Drive (ide2)**: Virtual CD-ROM that Proxmox automatically generates with cloud-init data
2. **Boot Disk (scsi0)**: The actual OS disk with Ubuntu cloud image
3. **Boot Process**:
   - VM boots from scsi0 (Ubuntu cloud image)
   - Cloud-init service starts inside VM
   - Cloud-init looks for configuration on ide2 (cloudinit drive)
   - Cloud-init applies configuration (SSH keys, network, etc.)
   - Cloud-init marks itself as complete
   - VM is ready for login

## Solution

### Option 1: Recreate Template with Fixed Playbook (Recommended)

The Ansible playbook has been fixed to include the cloud-init drive. Delete the broken template and recreate it:

```bash
# On Proxmox host, delete broken template
VMID=$(qm list | grep ubuntu-22.04-cloudinit | awk '{print $1}')
qm destroy ${VMID} --purge

# From deployment machine, recreate template
./deploy.sh
```

The updated playbook now includes:
```yaml
- name: Add cloud-init drive
  shell: qm set {{ vmid }} --ide2 {{ storage }}:cloudinit
```

### Option 2: Manually Fix Existing Template

If you want to fix the existing template without recreating:

```bash
# Find template VMID
VMID=$(qm list | grep ubuntu-22.04-cloudinit | awk '{print $1}')

# Convert template back to VM temporarily
qm template ${VMID} --revert

# Add cloud-init drive
qm set ${VMID} --ide2 local-lvm:cloudinit

# Convert back to template
qm template ${VMID}

# Verify cloud-init drive exists
qm config ${VMID} | grep ide2
# Should show: ide2: local-lvm:cloudinit
```

### Option 3: Manual Template Creation

Create a cloud-init template manually with all required components:

```bash
# Download cloud image
cd /var/tmp
wget https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img

# Get next available VMID
VMID=$(pvesh get /cluster/nextid)

# Create VM
qm create ${VMID} --name ubuntu-22.04-cloudinit --memory 2048 --cores 2

# Import disk
qm importdisk ${VMID} jammy-server-cloudimg-amd64.img local-lvm

# Attach disk as scsi0
qm set ${VMID} --scsi0 local-lvm:vm-${VMID}-disk-0

# Add cloud-init drive (CRITICAL!)
qm set ${VMID} --ide2 local-lvm:cloudinit

# Set boot order
qm set ${VMID} --boot order=scsi0

# Enable QEMU agent
qm set ${VMID} --agent 1

# Optional: Enable serial console for debugging
qm set ${VMID} --serial0 socket --vga serial0

# Convert to template
qm template ${VMID}

# Verify configuration
qm config ${VMID}
```

Expected output should include:
```
scsi0: local-lvm:vm-9000-disk-0,size=2G
ide2: local-lvm:cloudinit
boot: order=scsi0
agent: 1
```

## Verification

After fixing, verify the template has cloud-init configured:

```bash
# Find template VMID
VMID=$(qm list | grep ubuntu-22.04-cloudinit | awk '{print $1}')

# Check for cloud-init drive
qm config ${VMID} | grep -E "^ide2:"

# Should output something like:
# ide2: local-lvm:cloudinit
```

In Proxmox web UI:
1. Select the template VM
2. Click "Cloud-Init" tab
3. Should show fields for: User, Password, DNS, SSH Keys, etc.
4. Should **NOT** show "No CloudInit Drive found"

## Testing with a Cloned VM

To verify cloud-init works in cloned VMs:

```bash
# Clone template to test VM
qm clone ${TEMPLATE_VMID} 999 --name test-cloudinit --full

# Configure cloud-init settings
qm set 999 --sshkey ~/.ssh/id_rsa.pub
qm set 999 --ipconfig0 ip=dhcp
qm set 999 --ciuser ubuntu

# Start VM
qm start 999

# Wait for boot (30-60 seconds)
# Check cloud-init status inside VM
ssh ubuntu@<vm-ip> cloud-init status

# Should show:
# status: done

# Check cloud-init logs
ssh ubuntu@<vm-ip> sudo cat /var/log/cloud-init.log

# Clean up test VM
qm stop 999
qm destroy 999 --purge
```

## Related Issues

- **Boot Loop**: Missing scsi0 (boot disk) - see [fix-no-bootable-drive.md](./fix-no-bootable-drive.md)
- **Checksum Errors**: Download corruption - see [troubleshooting-checksum-mismatch.md](./troubleshooting-checksum-mismatch.md)
- **Authentication**: SSH vs API tokens - see [authentication-explained.md](./authentication-explained.md)

## Prevention

The deployment script now automatically validates templates for:
1. ✅ Boot disk (scsi0, ide0, or sata0)
2. ✅ Cloud-init drive (ide2 with cloudinit)

If either is missing, the template is automatically destroyed and recreated.

To manually validate before deployment:

```bash
./deploy.sh --skip-validation
# Will still validate template configuration before proceeding
```

## Additional Resources

- [Proxmox Cloud-Init Documentation](https://pve.proxmox.com/wiki/Cloud-Init_Support)
- [Ubuntu Cloud Images](https://cloud-images.ubuntu.com/)
- [Cloud-Init Documentation](https://cloudinit.readthedocs.io/)
