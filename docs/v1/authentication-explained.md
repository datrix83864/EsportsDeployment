# Proxmox Authentication - SSH vs API Tokens

## TL;DR

**You need BOTH for automated deployment:**
- **SSH access** (`root@<proxmox-ip>`) - For template creation
- **API Token** - For Terraform VM provisioning

## Why Both?

### SSH Access (Required for Template Creation)

The deployment script needs SSH access to create the cloud-init template because:

1. **Template creation requires `qm` commands** that aren't fully available via API
2. **File operations** (downloading cloud image, importing disk) need direct shell access
3. **Ansible playbook** runs commands like:
   - `qm create` - Create VM
   - `qm importdisk` - Import cloud image to storage
   - `qm set --scsi0` - Attach boot disk
   - `qm template` - Convert VM to template

**These operations are NOT available via Proxmox API tokens.**

### API Token (Required for Terraform)

Terraform uses API tokens (not SSH) to:
- Clone VMs from template
- Configure VM settings (CPU, RAM, network)
- Manage VM lifecycle (start, stop, destroy)

## Configuration Options

### Option 1: API Token + SSH (Recommended for "Clone & Go")

**Best for:** Users who want to clone the repo and have it "just work"

```yaml
# config.yaml
proxmox:
  host: 10.100.0.5
  node_name: pve
  vm_storage: local-lvm
  
  # API Token for Terraform
  api_token_id: terraform@pve!mytoken
  api_token_secret: xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx
  
  # SSH will be attempted to root@<host> for template creation
  # No additional config needed - script automatically uses root@10.100.0.5
```

**Prerequisites:**
- SSH key-based authentication configured for `root@<proxmox-ip>`
- Or password authentication enabled (will prompt for password)

**Flow:**
1. Script SSHs to Proxmox → Creates template
2. Terraform uses API token → Provisions VMs from template
3. Done! ✅

### Option 2: Username/Password (Less Secure)

**Best for:** Testing or environments where API tokens aren't available

```yaml
# config.yaml
proxmox:
  host: 10.100.0.5
  node_name: pve
  vm_storage: local-lvm
  
  # User/pass for both Terraform AND template creation attempts via API
  user: root@pam
  password: your_password
```

**Note:** This still requires SSH access for template creation! The username/password is used by Terraform, but template creation will fail without SSH.

### Option 3: Environment Variables Override

**Best for:** CI/CD or when you don't want credentials in config files

```bash
# Set these in your environment
export TF_VAR_proxmox_api_token_id="terraform@pve!mytoken"
export TF_VAR_proxmox_api_token_secret="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
export PROXMOX_SSH_TARGET="root@10.100.0.5"

# Then run deployment
./deploy.sh
```

## Setting Up SSH Access

### Quick Setup

```bash
# On your machine (where you run deploy.sh)
ssh-copy-id root@10.100.0.5

# Test it
ssh root@10.100.0.5 'echo "SSH works!"'

# If this works, you're ready!
```

### Secure Setup (SSH Key)

```bash
# 1. Generate SSH key (if you don't have one)
ssh-keygen -t ed25519 -C "proxmox-deploy"

# 2. Copy to Proxmox
ssh-copy-id -i ~/.ssh/id_ed25519.pub root@10.100.0.5

# 3. Test connection
ssh -i ~/.ssh/id_ed25519 root@10.100.0.5 'qm list'
```

## Creating API Tokens

### Via Proxmox Web UI

1. Navigate to **Datacenter** → **Permissions** → **API Tokens**
2. Click **Add**
3. Fill in:
   - **User:** `root@pam` (or your user)
   - **Token ID:** `terraform` (or any name)
   - **Privilege Separation:** ✅ **Uncheck** (token needs same permissions as user)
4. Click **Add**
5. **COPY THE SECRET** - You only see it once!

### Required Permissions

The API token needs these permissions on the Proxmox node:

- `VM.Allocate`
- `VM.Clone`
- `VM.Config.Disk`
- `VM.Config.CPU`
- `VM.Config.Memory`
- `VM.Config.Network`
- `VM.PowerMgmt`
- `Datastore.AllocateSpace`

**Easiest:** Use `root@pam` token with privilege separation disabled.

## Common Issues

### "Template not found" with API Token Configured

**Old Behavior (BUG - FIXED):**
- Script detected API token
- Skipped template creation
- Terraform failed: "template not found"

**New Behavior (FIXED):**
- Script detects API token ✅
- **Still creates template via SSH** ✅
- Terraform uses API token to provision VMs ✅

### "Permission denied" when creating template

**Cause:** SSH access not configured

**Fix:**
```bash
ssh-copy-id root@<proxmox-ip>
```

### "API token not found" when running Terraform

**Cause:** API token not configured in config.yaml or environment

**Fix:**
```yaml
# Add to config.yaml
proxmox:
  api_token_id: terraform@pve!mytoken
  api_token_secret: your-secret-here
```

## Security Best Practices

### 1. Use Dedicated API Token for Terraform

Don't use your main root password:

```yaml
# ❌ DON'T
proxmox:
  user: root@pam
  password: root_password

# ✅ DO
proxmox:
  api_token_id: terraform@pve!deploy
  api_token_secret: generated-token-secret
```

### 2. Use SSH Keys, Not Passwords

```bash
# ❌ DON'T: SSH password authentication
# (requires manual password entry or storing in scripts)

# ✅ DO: SSH key authentication
ssh-copy-id root@<proxmox-ip>
```

### 3. Restrict SSH Key

Add to `~/.ssh/config`:

```
Host proxmox-deploy
    HostName 10.100.0.5
    User root
    IdentityFile ~/.ssh/proxmox_deploy_key
    # Only allow specific commands (advanced)
    # PermitRootLogin without-password
```

### 4. Use Separate Token Per Environment

```yaml
# Production
proxmox:
  api_token_id: terraform-prod@pve!token

# Development
proxmox:
  api_token_id: terraform-dev@pve!token
```

## Workflow Summary

```
┌─────────────────────────────────────────────┐
│  User Runs: ./deploy.sh                     │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  Script Checks: Template Exists?            │
│  Method: SSH to root@<proxmox-ip>           │
│  Command: qm list | grep template           │
└────────────────┬────────────────────────────┘
                 │
        ┌────────┴────────┐
        │                 │
    NO  │                 │  YES
        ▼                 ▼
┌───────────────┐   ┌──────────────┐
│ Create        │   │ Validate     │
│ Template      │   │ Boot Disk    │
│ via Ansible   │   │ via SSH      │
│ (SSH)         │   └──────┬───────┘
└───────┬───────┘          │
        │                  │
        └────────┬─────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│  Terraform Provisions VMs                   │
│  Method: API Token                          │
│  Actions: Clone from template, configure    │
└─────────────────────────────────────────────┘
```

## Key Takeaway

**SSH is for template creation (one-time setup)**  
**API token is for VM management (ongoing operations)**

Both are needed for fully automated "clone and go" deployment! 🚀
