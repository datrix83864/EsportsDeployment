# Terraform Not Creating VMs - Quick Fix Guide

## 🎯 Your Issue: `terraform apply` Runs But No VM Appears

This is usually one of 5 common problems. Let's fix it!

---

## Step 1: Check What Terraform Actually Did

```bash
cd terraform

# Check Terraform state
terraform show

# If it shows resources, Terraform thinks it created something
# If empty, Terraform didn't create anything
```

**If terraform show is empty**: Terraform never tried to create the VM.  
**If terraform show has content**: Terraform created something, but it might have failed.

---

## Step 2: Run With Debug Output

```bash
# This shows EVERYTHING Terraform is doing
TF_LOG=DEBUG terraform apply -target=module.ipxe_vm 2>&1 | tee terraform-debug.log

# Or simpler:
terraform apply -target=module.ipxe_vm -auto-approve

# Watch for errors in the output
```

**Look for**:
- ✅ "Creating..." messages
- ❌ "Error" messages  
- ❌ "Warning" messages
- ❌ Authentication failures

---

## Step 3: Common Issues & Fixes

### Issue A: Wrong Target Path ❌

**Problem**: `module.ipxe_vm` doesn't exist

**Check**:
```bash
# List what Terraform knows about
terraform state list

# If empty, try:
terraform plan

# See what it WOULD create
```

**Fix**: The resource might be named differently. Try:
```bash
# If using modules
terraform apply -target=module.ipxe_vm.proxmox_vm_qemu.ipxe_server

# If NOT using modules (more common)
terraform apply -target=proxmox_vm_qemu.ipxe_server

# Or just apply everything
terraform apply
```

### Issue B: Missing terraform.tfvars ❌

**Problem**: Terraform has no Proxmox credentials

**Check**:
```bash
ls -la terraform.tfvars
```

**Fix**:
```bash
# Copy example
cp terraform.tfvars.example terraform.tfvars

# Edit with your details
nano terraform.tfvars

# Fill in:
# - proxmox_api_url (your Proxmox IP)
# - proxmox_user (root@pam)
# - proxmox_password (your password)
```

### Issue C: Wrong Proxmox API URL ❌

**Problem**: Can't reach Proxmox

**Test**:
```bash
# Can you ping Proxmox?
ping proxmox.local
# or
ping 192.168.1.5  # Your Proxmox IP

# Can you reach the API?
curl -k https://192.168.1.5:8006/api2/json
```

**Fix** in `terraform.tfvars`:
```hcl
# Use IP, not hostname
proxmox_api_url = "https://192.168.1.5:8006/api2/json"  # Change IP!

# Make sure port 8006 is correct
# Make sure /api2/json is at the end
```

### Issue D: Authentication Failure ❌

**Problem**: Wrong username/password

**Test**:
```bash
# Try logging into Proxmox web UI with same credentials
# https://your-proxmox:8006

# Username format MUST be: root@pam (not just "root")
```

**Fix** in `terraform.tfvars`:
```hcl
proxmox_user     = "root@pam"  # Must include @pam!
proxmox_password = "your-actual-password"

# Or use API token (more secure):
proxmox_api_token_id     = "root@pam!terraform"
proxmox_api_token_secret = "your-token-secret"
```

### Issue E: Storage Pool Doesn't Exist ❌

**Problem**: Terraform can't find storage

**Check in Proxmox**:
```
Datacenter → Storage → See what storage pools exist
Common names: local-lvm, local, local-zfs, etc.
```

**Fix** in `terraform.tfvars`:
```hcl
vm_storage = "local-lvm"  # Change to YOUR storage name
```

---

## Step 4: Run Diagnostic Script

```bash
cd terraform
bash debug-proxmox.sh

# This will:
# - Test connectivity to Proxmox
# - Test API authentication
# - List nodes and storage
# - Generate correct terraform.tfvars
```

---

## Step 5: Try Simplified Approach

Instead of modules, let's try a direct resource:

Create `terraform/test-vm.tf`:
```hcl
resource "proxmox_vm_qemu" "test" {
  name        = "test-vm"
  target_node = "pve"  # Change to your node name
  
  cores   = 1
  memory  = 1024
  
  disk {
    type    = "scsi"
    storage = "local-lvm"  # Change to your storage
    size    = "10G"
  }
  
  network {
    model  = "virtio"
    bridge = "vmbr0"
  }
}
```

Then:
```bash
terraform init
terraform plan
terraform apply

# If this works, your connection is good!
# If not, check the error message
```

---

## Step 6: Check Proxmox Logs

```bash
# SSH to Proxmox server
ssh root@proxmox

# Check system logs
tail -f /var/log/syslog | grep -i qemu

# Check PVE daemon logs
journalctl -u pvedaemon -f
```

---

## 🔥 Nuclear Option: Start Fresh

If nothing works:

```bash
cd terraform

# Remove all Terraform state
rm -rf .terraform/
rm -f terraform.tfstate*
rm -f .terraform.lock.hcl

# Reinitialize
terraform init

# Try again
terraform plan
terraform apply
```

---

## ✅ Verification Checklist

Before running `terraform apply`:

- [ ] In `terraform/` directory
- [ ] `terraform init` completed successfully
- [ ] `terraform.tfvars` exists with your Proxmox details
- [ ] Can ping Proxmox host
- [ ] Can access Proxmox web UI with same credentials
- [ ] Storage pool name is correct
- [ ] Node name is correct (usually "pve")
- [ ] Network bridge exists (usually "vmbr0")

---

## 💡 Quick Test Commands

```bash
# 1. Basic connectivity
ping $(grep proxmox_api_url terraform.tfvars | cut -d'"' -f2 | cut -d'/' -f3 | cut -d':' -f1)

# 2. Terraform syntax
terraform validate

# 3. What would be created
terraform plan

# 4. Create with verbose output
terraform apply -auto-approve

# 5. Check what was created
terraform show

# 6. Check in Proxmox
# Web UI → Node → Summary → See VMs list
```

---

## 📝 Most Likely Causes (in order):

1. **Missing terraform.tfvars** (80% of cases)
2. **Wrong node name** (10%)
3. **Wrong storage name** (5%)
4. **Network/firewall issue** (3%)
5. **Other** (2%)

---

## 🆘 Still Not Working?

Run this and send me the output:

```bash
cd terraform

# Generate diagnostic info
cat > debug-info.txt << EOF
Terraform Version:
$(terraform version)

Current Directory:
$(pwd)

Files Present:
$(ls -la)

Terraform State:
$(terraform show 2>&1 | head -20)

Terraform Plan Output:
$(terraform plan 2>&1 | head -50)

Config Check:
$(grep -v password terraform.tfvars 2>&1)
EOF

cat debug-info.txt
```

Then tell me:
1. What error messages you see
2. Does `terraform plan` show it WOULD create a VM?
3. What does `terraform show` output?

**We'll get this working!** 🚀