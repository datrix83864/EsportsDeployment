# Terraform Installation Troubleshooting

Common issues and solutions for installing Terraform.

## 🚀 Quick Fix: Use Our Install Script

```bash
# From project root
sudo ./scripts/install_prerequisites.sh
```

This script handles everything automatically!

---

## 📋 Manual Installation Methods

### Method 1: Official Repository (RECOMMENDED)

#### Ubuntu/Debian

```bash
# Add HashiCorp GPG key
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Add repository
echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
  https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
  sudo tee /etc/apt/sources.list.d/hashicorp.list

# Install
sudo apt update
sudo apt install terraform
```

#### Fedora

```bash
sudo dnf install -y dnf-plugins-core
sudo dnf config-manager --add-repo https://rpm.releases.hashicorp.com/fedora/hashicorp.repo
sudo dnf install terraform
```

#### RHEL/CentOS

```bash
sudo yum install -y yum-utils
sudo yum-config-manager --add-repo https://rpm.releases.hashicorp.com/RHEL/hashicorp.repo
sudo yum install terraform
```

---

### Method 2: Direct Download

```bash
# Set version
TERRAFORM_VERSION="1.6.6"

# Detect architecture
ARCH=$(uname -m)
case $ARCH in
    x86_64) TF_ARCH="amd64" ;;
    aarch64|arm64) TF_ARCH="arm64" ;;
esac

# Download
cd /tmp
wget https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip

# Install unzip if needed
sudo apt install unzip  # Ubuntu/Debian
# or
sudo dnf install unzip  # Fedora/RHEL

# Extract and install
unzip terraform_${TERRAFORM_VERSION}_linux_${TF_ARCH}.zip
sudo mv terraform /usr/local/bin/
chmod +x /usr/local/bin/terraform

# Verify
terraform --version
```

---

### Method 3: tfenv (Version Manager)

If you need multiple Terraform versions:

```bash
# Install tfenv
git clone https://github.com/tfutils/tfenv.git ~/.tfenv
echo 'export PATH="$HOME/.tfenv/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Install Terraform
tfenv install 1.6.6
tfenv use 1.6.6

# Verify
terraform --version
```

---

## 🐛 Common Issues & Solutions

### Issue 1: "terraform: command not found"

**Cause**: Terraform not in PATH

**Solution**:

```bash
# Check if installed
which terraform
ls -la /usr/local/bin/terraform
ls -la /usr/bin/terraform

# If found but not in PATH
echo 'export PATH="/usr/local/bin:$PATH"' >> ~/.bashrc
source ~/.bashrc

# Verify
terraform --version
```

### Issue 2: "Permission denied"

**Cause**: Terraform binary not executable

**Solution**:

```bash
sudo chmod +x /usr/local/bin/terraform
# or
sudo chmod +x /usr/bin/terraform
```

### Issue 3: GPG key error (Ubuntu/Debian)

**Error**: `NO_PUBKEY` or GPG verification failed

**Solution**:

```bash
# Remove old key
sudo rm /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Re-add key
wget -O- https://apt.releases.hashicorp.com/gpg | \
  gpg --dearmor | \
  sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg

# Try again
sudo apt update
sudo apt install terraform
```

### Issue 4: Architecture mismatch

**Error**: `cannot execute binary file: Exec format error`

**Cause**: Wrong architecture downloaded

**Solution**:

```bash
# Check your architecture
uname -m
# x86_64 = amd64
# aarch64 = arm64

# Download correct version
# Make sure TF_ARCH matches your system
```

### Issue 5: SSL certificate errors

**Error**: `SSL certificate problem`

**Solution**:

```bash
# Update ca-certificates
sudo apt update
sudo apt install ca-certificates

# Or use --no-check-certificate (not recommended for production)
wget --no-check-certificate https://...
```

---

## ✅ Verify Installation

```bash
# Check Terraform is installed
terraform --version

# Should output something like:
# Terraform v1.6.6

# Check Terraform is in PATH
which terraform

# Should output:
# /usr/local/bin/terraform
# or /usr/bin/terraform

# Test Terraform works
terraform -help
```

---

## 🔧 Ansible Installation (Bonus)

If Ansible is also giving you trouble:

### Ubuntu/Debian

```bash
sudo apt update
sudo apt install software-properties-common
sudo add-apt-repository --yes --update ppa:ansible/ansible
sudo apt install ansible
```

### Fedora/RHEL

```bash
sudo dnf install ansible
```

### Verify

```bash
ansible --version
```

---

## 🚫 If All Else Fails: Skip Terraform

**Option 1**: Create VMs manually in Proxmox

```bash
# Skip the Terraform step
# Create VMs manually through Proxmox web UI
# Then run Ansible playbooks directly
cd ansible
ansible-playbook -i inventory/hosts playbooks/deploy_ipxe.yml
```

**Option 2**: Use Proxmox CLI (qm)

```bash
# Create VM using qm command
qm create 100 --name ipxe-server --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
```

**Option 3**: Deploy without infrastructure-as-code

```bash
# Just install software on existing VMs
ssh user@vm-ip
sudo bash /path/to/ipxe/scripts/setup.sh
```

---

## 📦 Alternative: Docker Method

If you don't want to install Terraform system-wide:

```bash
# Use Terraform in Docker
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest init
docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest plan

# Create alias for convenience
echo 'alias terraform="docker run --rm -v $(pwd):/workspace -w /workspace hashicorp/terraform:latest"' >> ~/.bashrc
```

---

## 🎯 What Our Project Actually Needs

For deploying iPXE server, you have options:

### Option A: Full Automation (with Terraform)

```bash
# Requires Terraform + Ansible
./deploy.sh --component ipxe
```

### Option B: Ansible Only (skip Terraform)

```bash
# Create VM manually in Proxmox first
# Then run Ansible
cd ansible
ansible-playbook playbooks/deploy_ipxe.yml
```

### Option C: Manual (no automation tools)

```bash
# Create VM in Proxmox
# SSH to VM
# Run setup script
sudo bash ipxe/scripts/setup.sh
```

**All three work!** Choose what you're comfortable with.

---

## 💡 Pro Tips

1. **Use the install script first**: `sudo ./scripts/install_prerequisites.sh`

2. **If that fails**: Try manual installation methods above

3. **If manual fails**: Use Ansible-only approach (skip Terraform)

4. **Still stuck?**: Deploy manually, it's perfectly fine!

5. **Check versions**: Sometimes newer Terraform versions have issues
   - Stick with 1.6.x for stability
   - Avoid bleeding edge versions

---

## 📞 Still Having Issues?

### Check System Requirements

```bash
# Check OS
cat /etc/os-release

# Check architecture
uname -m

# Check available disk space
df -h

# Check internet connectivity
ping -c 3 releases.hashicorp.com
```

### Get Detailed Error

```bash
# Run with verbose output
terraform --version 2>&1 | tee terraform-error.log

# Check system logs
journalctl -xe | grep terraform
```

### Ask for Help

Create a GitHub issue with:

- Your OS and version
- Architecture (uname -m)
- Error message
- What you've tried

---

## 🎉 Success!

Once installed, verify with:

```bash
terraform --version
ansible --version
python3 --version

# All should show versions
# Then you're ready to deploy!
./deploy.sh --component ipxe
```
