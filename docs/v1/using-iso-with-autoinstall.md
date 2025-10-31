# Using Ubuntu Server ISO with Autoinstall

## Overview

By default, this project uses cloud-init templates for **fully automated** VM deployment. However, if cloud-init templates consistently fail, you can use Ubuntu Server ISO with **autoinstall** configuration.

⚠️ **WARNING:** This is significantly more complex than cloud-init and should only be used as a last resort.

## Why Cloud-Init is Better

| Feature       | Cloud-Init Template     | ISO with Autoinstall             |
| ------------- | ----------------------- | -------------------------------- |
| Setup Time    | 2 minutes (automated)   | 15-30 min per VM                 |
| Configuration | Automatic via Terraform | Requires custom autoinstall file |
| Network Setup | Automatic               | Manual or autoinstall config     |
| User Creation | Automatic               | Manual or autoinstall config     |
| SSH Keys      | Automatic               | Manual or autoinstall config     |
| Complexity    | Low                     | High                             |
| Maintenance   | Easy                    | Difficult                        |

## When to Use ISO

Only use ISO if:
1. Cloud-init template creation repeatedly fails after trying all fixes
2. You have specific requirements that cloud-init doesn't support
3. You're willing to invest significant time in autoinstall configuration

## Option 1: Manual Installation (Not Recommended)

With a plain ISO, you'll need to:

1. **For Each VM:**
   - Boot from ISO
   - Go through Ubuntu installer manually
   - Set hostname, network, users, SSH
   - Wait 15-30 minutes
   - Configure Ansible connectivity

2. **Problems:**
   - No automation
   - Error-prone
   - Time-consuming (45-90 minutes for 3 VMs)
   - Defeats the purpose of this project

## Option 2: Autoinstall Configuration (Advanced)

Ubuntu's autoinstall allows unattended installation from ISO.

### Requirements

- Ubuntu Server 20.04+ ISO
- Custom autoinstall configuration file
- HTTP server to serve autoinstall config
- Modified boot parameters

### Steps

#### 1. Create Autoinstall Configuration

Create `autoinstall/user-data.yaml`:

```yaml
#cloud-config
autoinstall:
  version: 1
  
  # Locale and keyboard
  locale: en_US.UTF-8
  keyboard:
    layout: us
  
  # Network configuration
  network:
    version: 2
    ethernets:
      ens18:  # Adjust interface name
        dhcp4: no
        addresses:
          - 192.168.1.10/24  # Will need to be dynamic
        gateway4: 192.168.1.1
        nameservers:
          addresses:
            - 8.8.8.8
            - 8.8.4.4
  
  # Storage
  storage:
    layout:
      name: lvm
  
  # User account
  identity:
    hostname: ipxe-server
    username: ansible
    password: "$6$rounds=4096$salted$hash"  # Generate with: mkpasswd -m sha-512
  
  # SSH
  ssh:
    install-server: yes
    allow-pw: yes
    authorized-keys:
      - ssh-rsa AAAAB3... your-key-here
  
  # Packages
  packages:
    - openssh-server
    - python3
    - qemu-guest-agent
  
  # Post-install commands
  late-commands:
    - echo 'ansible ALL=(ALL) NOPASSWD:ALL' > /target/etc/sudoers.d/ansible

  # Disable snapd auto-refresh during install
  refresh-installer:
    update: no
```

#### 2. Host Autoinstall Config

You need an HTTP server accessible during installation:

```bash
# On your deployment machine or a web server
cd autoinstall
python3 -m http.server 8000

# Make accessible to Proxmox network
# URL will be: http://YOUR_IP:8000/user-data.yaml
```

#### 3. Modify ISO Boot Parameters

In Proxmox, when creating the VM, you'd need to:

1. Attach the ISO
2. Modify boot parameters to include autoinstall URL
3. Start VM and hope it works

**Problem:** Terraform doesn't easily support modifying boot parameters for each VM with different IPs.

### Why This Is Impractical

1. **Per-VM Configuration:** Each VM needs different:
   - Hostname
   - IP address
   - Network settings

2. **Templating Nightmare:** You'd need to:
   - Generate unique autoinstall file per VM
   - Serve each file separately
   - Modify Terraform to handle boot parameters

3. **Complexity:** This is MORE complex than just fixing cloud-init!

## Recommended Solution

**Don't use ISO with autoinstall.** Instead:

### Fix Cloud-Init Issues

The recent updates to the deployment scripts now include:

1. ✅ Cloud image validation (checksum, size, format)
2. ✅ Automatic retry on corrupted downloads
3. ✅ Template boot disk validation
4. ✅ Automatic template recreation
5. ✅ Clear error messages

**Try deployment again:**

```bash
# The enhanced script will validate everything
./deploy.sh

# If it still fails, check the detailed guide
cat docs/troubleshooting-boot-issues.md
```

### If Cloud-Init Still Fails

If cloud-init absolutely doesn't work in your environment:

1. **Diagnose the root cause:**
   - Network issues downloading images?
   - Proxmox storage problems?
   - Proxmox version incompatibility?

2. **Fix the underlying issue** rather than working around it

3. **Manual template creation** as documented in `docs/troubleshooting-boot-issues.md`

## Hybrid Approach (Not Recommended)

You could theoretically:

1. Install Ubuntu from ISO manually on **one** VM
2. Configure it properly (network, ansible user, SSH)
3. Convert that VM to a template
4. Use that template instead of cloud-init

**Steps:**

```bash
# 1. Create VM manually from ISO
# 2. Install Ubuntu, configure networking, create ansible user
# 3. Install cloud-init and qemu-guest-agent
sudo apt update
sudo apt install cloud-init qemu-guest-agent

# 4. Clean the VM
sudo cloud-init clean
sudo rm -rf /var/lib/cloud/*
sudo truncate -s 0 /etc/machine-id
sudo rm /etc/ssh/ssh_host_*

# 5. Shut down VM
sudo poweroff

# 6. Convert to template on Proxmox
qm template <VMID>
```

Then use this template name in your config.

**Problem:** You still did manual work, and you'll need to maintain this template.

## Bottom Line

**Just use cloud-init.** The issues you experienced should now be fixed with:

- Checksum validation
- Automatic corruption detection
- Template validation
- Clear error messages

If problems persist, the root cause is likely:
- Network connectivity issues
- Proxmox configuration problems
- Storage problems

These need to be fixed anyway, regardless of whether you use ISO or cloud-init.

## Need Help?

See:
- `docs/troubleshooting-boot-issues.md` - Complete boot troubleshooting
- `docs/troubleshooting.md` - General issues
- `BOOT_FIX_SUMMARY.md` - What was fixed

The cloud-init approach is **dramatically simpler** once it's working correctly, which the recent fixes should ensure.
