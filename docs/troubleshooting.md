# Troubleshooting Guide

## Quick Links

- **[Boot Issues & Infinite Boot Loops](troubleshooting-boot-issues.md)** - VMs can't find bootable media
- [Configuration Issues](#configuration-issues)
- [Network Issues](#network-issues)
- [Terraform Issues](#terraform-issues)
- [Ansible Issues](#ansible-issues)

## Common Issues by Symptom

### VMs Won't Boot / Infinite Boot Loop

**See the dedicated guide:** [Troubleshooting Boot Issues](troubleshooting-boot-issues.md)

This covers:
- "No bootable media" errors
- Cloud-init template problems
- Corrupted cloud image downloads
- How to use Ubuntu Server ISO as alternative

### Configuration Issues

#### Config File Not Found

**Symptom:** `Configuration file not found: config.yaml`

**Solution:**
```bash
# Copy the example config
cp config.example.yaml config.yaml

# Edit with your settings
nano config.yaml
```

#### Invalid YAML Syntax

**Symptom:** `yaml.scanner.ScannerError` or similar parsing errors

**Solution:**
```bash
# Validate YAML syntax
python3 -c "import yaml; yaml.safe_load(open('config.yaml'))"

# Common issues:
# - Incorrect indentation (use spaces, not tabs)
# - Missing quotes around special characters
# - Unescaped colons in values
```

### Network Issues

#### Cannot Reach Proxmox

**Symptom:** SSH connection errors, timeout connecting to Proxmox

**Solution:**
```bash
# Test SSH connectivity
ssh root@<proxmox-ip> "qm list"

# If this fails, check:
# 1. Proxmox host is online
# 2. SSH service is running
# 3. Firewall allows SSH (port 22)
# 4. Network connectivity from deployment machine
ping <proxmox-ip>
```

#### VMs Can't Get IP Addresses

**Symptom:** VMs created but no IP assigned, can't connect via SSH

**Solution:**
1. Check network bridge configuration in config.yaml
2. Verify VLAN settings if applicable
3. Ensure DHCP server is running on network
4. Check VM network adapter in Proxmox console

### Terraform Issues

#### Template Not Found

**Symptom:** `Error creating VM: template 'ubuntu-22.04-cloudinit' not found`

**Solution:** See [Troubleshooting Boot Issues](troubleshooting-boot-issues.md) - this is the main boot issue guide.

#### API Authentication Failed

**Symptom:** `401 Unauthorized` or authentication errors

**Solution:**
```yaml
# In config.yaml, verify Proxmox credentials:
proxmox:
  host: "192.168.1.5"  # Use IP, not hostname
  api_token_id: "user@realm!tokenid"
  api_token_secret: "your-secret-here"
  # OR use username/password (less secure):
  user: "root@pam"
  password: "your-password"
```

#### Insufficient Permissions

**Symptom:** `403 Forbidden` errors when creating VMs

**Solution:**
```bash
# On Proxmox, ensure API token has necessary permissions
# GUI: Datacenter > Permissions > API Tokens
# Required: VM.Allocate, VM.Config.*, Datastore.Allocate
```

### Ansible Issues

#### Playbook Not Found

**Symptom:** `ERROR! the playbook: ansible/playbooks/deploy_all.yml could not be found`

**Solution:**
```bash
# Ensure you're in the project root directory
cd /path/to/EsportsDeployment

# Verify playbook exists
ls -la ansible/playbooks/
```

#### Cannot Connect to Hosts

**Symptom:** `UNREACHABLE! => {"changed": false, "msg": "Failed to connect to the host"`

**Solution:**
1. VMs must be created by Terraform first
2. Verify VMs are running and have IP addresses
3. Check SSH keys are configured correctly
4. Test manual SSH connection:
   ```bash
   ssh -i ~/.ssh/your_key ansible@<vm-ip>
   ```

## Advanced Troubleshooting

### Enable Verbose Logging

```bash
# Deploy with verbose output
./deploy.sh --verbose

# Terraform debug
export TF_LOG=DEBUG
cd terraform && terraform apply
```

### Check System Logs

```bash
# Proxmox logs
ssh root@<proxmox-ip> "tail -f /var/log/pve/tasks/active"

# Terraform logs
cat terraform/terraform-plugin-proxmox.log

# Deployment script creates logs in current directory
```

### Validate Configuration

```bash
# Run preflight checks
./scripts/preflight_check.sh

# Validate config syntax
python3 scripts/validate_config.py config.yaml
```

### Clean State and Retry

Sometimes starting fresh helps:

```bash
# Remove Terraform state (WARNING: loses track of created resources)
cd terraform
rm -rf .terraform terraform.tfstate*
terraform init

# Or destroy and recreate
terraform destroy
terraform apply
```

### Manual Verification Steps

1. **Check Proxmox Web UI**
   - Access https://<proxmox-ip>:8006
   - Verify VMs are created
   - Check VM console for boot messages

2. **Verify Network Configuration**
   ```bash
   # From a VM (if accessible)
   ip addr show
   ip route show
   ping 8.8.8.8
   ```

3. **Check Storage**
   ```bash
   # On Proxmox
   pvesm status
   df -h
   ```

## Getting Help

If you're still stuck:

1. **Gather Information**
   - Full error message
   - Output of `./deploy.sh --verbose`
   - Relevant config.yaml sections (redact passwords!)
   - Proxmox version: `ssh root@<proxmox-ip> pveversion`

2. **Check Common Causes**
   - [ ] Cloud-init template exists and is valid
   - [ ] Network connectivity to Proxmox
   - [ ] Sufficient storage space
   - [ ] Correct permissions for API user
   - [ ] Valid YAML syntax in config.yaml
   - [ ] SSH keys properly configured

3. **Review Documentation**
   - [Getting Started Guide](getting-started.md)
   - [Configuration Reference](configuration.md)
   - [Boot Issues Guide](troubleshooting-boot-issues.md)

4. **Report Issues**
   - Include all gathered information
   - Describe what you expected vs what happened
   - Note any recent changes to configuration
