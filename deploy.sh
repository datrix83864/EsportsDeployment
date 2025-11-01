#!/bin/bash
#
# Esports LAN Infrastructure - Simple Deployment Script
# Version 2.0 - One Command Deployment
#
# Usage:
#   ./deploy.sh              # Full deployment
#   ./deploy.sh --check      # Pre-flight checks only
#   ./deploy.sh --help       # Show help
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/config.yaml"

# Logging
log_info() { echo -e "${BLUE}►${NC} $1"; }
log_success() { echo -e "${GREEN}✓${NC} $1"; }
log_warning() { echo -e "${YELLOW}!${NC} $1"; }
log_error() { echo -e "${RED}✗${NC} $1"; }
log_step() { echo -e "\n${CYAN}▶ $1${NC}\n"; }

# Banner
banner() {
    cat << "EOF"
    ╔═══════════════════════════════════════════════════╗
    ║   Esports LAN Infrastructure v2.0                 ║
    ║   Simple, Fast, Reliable                          ║
    ╚═══════════════════════════════════════════════════╝
EOF
    echo ""
}

# Help
show_help() {
    cat << EOF
Usage: $0 [OPTIONS]

Options:
  --check       Run pre-flight checks only
  --help        Show this help message
  
Examples:
  $0                # Full deployment
  $0 --check        # Verify prerequisites and config

This script will:
  1. Validate your configuration
  2. Check Proxmox connectivity
  3. Create 3 VMs (PXE, LANCache, FileServer)
  4. Configure networking and services
  5. Test connectivity
  
Estimated time: 15-20 minutes

For help: https://github.com/your-org/esports-lan/docs/quickstart.md
EOF
}

# Parse arguments
MODE="deploy"
while [[ $# -gt 0 ]]; do
    case $1 in
        --check) MODE="check"; shift ;;
        --help|-h) show_help; exit 0 ;;
        *) log_error "Unknown option: $1"; show_help; exit 1 ;;
    esac
done

# Pre-flight checks
preflight_checks() {
    log_step "Running Pre-Flight Checks"
    
    local errors=0
    
    # Check Python
    if ! command -v python3 &> /dev/null; then
        log_error "Python 3 is required"
        errors=$((errors + 1))
    else
        log_success "Python 3 found"
    fi
    
    # Check Ansible
    if ! command -v ansible &> /dev/null; then
        log_error "Ansible is required"
        log_info "  Install: sudo apt install ansible"
        errors=$((errors + 1))
    else
        local version=$(ansible --version | head -1 | cut -d' ' -f2)
        log_success "Ansible found (version $version)"
    fi
    
    # Check PyYAML
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_error "PyYAML is required"
        log_info "  Install: pip3 install pyyaml"
        errors=$((errors + 1))
    else
        log_success "PyYAML found"
    fi
    
    # Check Ansible community.general collection
    if ! ansible-galaxy collection list | grep -q "community.general"; then
        log_warning "community.general collection not found"
        log_info "  Installing automatically..."
        ansible-galaxy collection install community.general
    else
        log_success "Ansible community.general collection found"
    fi
    
    # Check config file
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "config.yaml not found"
        log_info "  Copy config.example.yaml to config.yaml and edit it"
        errors=$((errors + 1))
    else
        log_success "config.yaml found"
        
        # Validate YAML syntax
        if python3 -c "import yaml; yaml.safe_load(open('$CONFIG_FILE'))" 2>/dev/null; then
            log_success "config.yaml is valid YAML"
        else
            log_error "config.yaml has syntax errors"
            errors=$((errors + 1))
        fi
    fi
    
    # Check Proxmox connectivity
    if [[ -f "$CONFIG_FILE" ]]; then
        log_info "Testing Proxmox connectivity..."
        
        local proxmox_host=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE')).get('proxmox', {}).get('host', ''))")
        
        if [[ -n "$proxmox_host" ]]; then
            if ping -c 2 -W 2 "$proxmox_host" &> /dev/null; then
                log_success "Can reach Proxmox at $proxmox_host"
            else
                log_error "Cannot reach Proxmox at $proxmox_host"
                errors=$((errors + 1))
            fi
        else
            log_error "Proxmox host not set in config.yaml"
            errors=$((errors + 1))
        fi
    fi
    
    # Check SSH key
    local ssh_key_path=$(python3 -c "import yaml, os; cfg=yaml.safe_load(open('$CONFIG_FILE')); print(os.path.expanduser(cfg.get('advanced', {}).get('ssh_key_path', '~/.ssh/id_rsa.pub')))" 2>/dev/null || echo "~/.ssh/id_rsa.pub")
    ssh_key_path=$(eval echo "$ssh_key_path")
    
    if [[ -f "$ssh_key_path" ]]; then
        log_success "SSH key found at $ssh_key_path"
    else
        log_warning "SSH key not found at $ssh_key_path"
        # Check if SSH key exists
        if [[ ! -f ~/.ssh/id_rsa ]]; then
            ssh-keygen -t rsa -b 4096 -f ~/.ssh/id_rsa -N ""
        fi
        log_info "Generating public key..."
        ssh-keygen -y -f ~/.ssh/id_rsa > ~/.ssh/id_rsa.pub
        log_success "SSH public key generated at ~/.ssh/id_rsa.pub"
    fi
    
    echo ""
    if [[ $errors -eq 0 ]]; then
        log_success "All pre-flight checks passed!"
        return 0
    else
        log_error "$errors pre-flight check(s) failed"
        return 1
    fi
}

# Ensure SSH keys exist
ensure_ssh_keys() {
    log_step "Checking SSH Keys"
    
    local ssh_key_path=$(python3 -c "import yaml, os; cfg=yaml.safe_load(open('$CONFIG_FILE')); print(os.path.expanduser(cfg.get('advanced', {}).get('ssh_key_path', '~/.ssh/id_rsa')))" 2>/dev/null || echo "~/.ssh/id_rsa")
    ssh_key_path=$(eval echo "$ssh_key_path")
    
    if [[ ! -f "$ssh_key_path" ]]; then
        log_warning "SSH key not found at $ssh_key_path"
        log_info "Generating SSH key pair..."
        
        ssh-keygen -t rsa -b 4096 -f "$ssh_key_path" -N "" -C "esports-lan-deployment"
        
        log_success "SSH key generated at $ssh_key_path"
    else
        log_success "SSH key found at $ssh_key_path"
    fi
    
    # Verify public key exists
    if [[ ! -f "${ssh_key_path}" ]]; then
        log_error "Public key not found at ${ssh_key_path}.pub"
        return 1
    fi
    
    log_info "Public key: $(cat ${ssh_key_path} | cut -d' ' -f1-2)..."
}

# Validate configuration
validate_config() {
    log_step "Validating Configuration"
    
    python3 - "$CONFIG_FILE" << 'PYTHON'
import sys
import yaml

config_file = sys.argv[1]
errors = []
warnings = []

try:
    with open(config_file) as f:
        config = yaml.safe_load(f)
except Exception as e:
    print(f"✗ Failed to load config: {e}")
    sys.exit(1)

# Check required sections
required = {
    'organization': ['name'],
    'proxmox': ['host', 'node', 'storage'],
    'network': ['subnet', 'gateway', 'pxe_server', 'lancache_server', 'file_server'],
}

for section, fields in required.items():
    if section not in config:
        errors.append(f"Missing section: {section}")
        continue
    for field in fields:
        if field not in config[section] or not config[section][field]:
            errors.append(f"Missing required field: {section}.{field}")

# Check Proxmox auth
proxmox = config.get('proxmox', {})
has_password = proxmox.get('password')
has_token = proxmox.get('api_token_id') and proxmox.get('api_token_secret')
if not has_password and not has_token:
    errors.append("Must provide either proxmox.password or API token credentials")

# Check IPs
network = config.get('network', {})
servers = ['pxe_server', 'lancache_server', 'file_server']
for server in servers:
    ip = network.get(server)
    if ip:
        # Basic IP validation
        parts = ip.split('.')
        if len(parts) != 4 or not all(p.isdigit() and 0 <= int(p) <= 255 for p in parts):
            errors.append(f"Invalid IP address: network.{server} = {ip}")

# Report
if errors:
    print("\n✗ Configuration Errors:")
    for error in errors:
        print(f"  - {error}")
    sys.exit(1)

if warnings:
    print("\n! Configuration Warnings:")
    for warning in warnings:
        print(f"  - {warning}")

print("\n✓ Configuration is valid")
sys.exit(0)
PYTHON
    
    if [[ $? -eq 0 ]]; then
        log_success "Configuration validated"
        return 0
    else
        return 1
    fi
}

# Display configuration summary
show_config_summary() {
    log_step "Configuration Summary"
    
    python3 - "$CONFIG_FILE" << 'PYTHON'
import yaml

with open('config.yaml') as f:
    cfg = yaml.safe_load(f)

org = cfg.get('organization', {})
px = cfg.get('proxmox', {})
net = cfg.get('network', {})
res = cfg.get('resources', {})

print(f"Organization: {org.get('name', 'N/A')}")
print(f"Proxmox Host: {px.get('host', 'N/A')} (node: {px.get('node', 'N/A')})")
print(f"Network: {net.get('subnet', 'N/A')}")
print(f"\nServers to Deploy:")
print(f"  • PXE/DHCP:  {net.get('pxe_server', 'N/A')}")
print(f"  • LANCache:  {net.get('lancache_server', 'N/A')}")
print(f"  • FileServer: {net.get('file_server', 'N/A')}")
print(f"\nClient DHCP Range: {net.get('dhcp_start', 'N/A')} - {net.get('dhcp_end', 'N/A')}")

pxe_mem = res.get('pxe_server', {}).get('memory', 0)
cache_mem = res.get('lancache_server', {}).get('memory', 0)
file_mem = res.get('file_server', {}).get('memory', 0)
total_mem = (pxe_mem + cache_mem + file_mem) / 1024
print(f"\nTotal RAM Required: {total_mem:.1f}GB")
PYTHON
    
    echo ""
}

# Main deployment
deploy() {
    log_step "Starting Deployment"
    
    log_info "This will take approximately 15-20 minutes"
    log_info "Progress will be shown below"
    echo ""
    
    # Run Ansible playbook
    cd "$SCRIPT_DIR/ansible"
    
    local ansible_args="-i inventory/proxmox -e @../config.yaml"
    
    # Add verbosity if requested
    if [[ "${VERBOSE:-false}" == "true" ]]; then
        ansible_args="$ansible_args -vvv"
    fi
    
    if ansible-playbook deploy.yml $ansible_args; then
        log_success "Deployment completed successfully!"
        return 0
    else
        log_error "Deployment failed"
        return 1
    fi
}

# Display post-deployment info
show_completion_info() {
    log_step "Deployment Complete!"
    
    python3 - "$CONFIG_FILE" << 'PYTHON'
import yaml

with open('config.yaml') as f:
    cfg = yaml.safe_load(f)

net = cfg.get('network', {})
pxe = net.get('pxe_server', '')
cache = net.get('lancache_server', '')
file = net.get('file_server', '')

print("""
╔═══════════════════════════════════════════════════════╗
║              Deployment Successful! 🎉                ║
╚═══════════════════════════════════════════════════════╝

Your infrastructure is ready:

🖥️  Servers:
   • PXE/DHCP:    http://{pxe}
   • LANCache:    http://{cache}
   • FileServer:  \\\\{file}\\profiles

📋 Next Steps:

1. Configure your network switch for PXE boot:
   • Set DHCP server: {pxe}
   • Or disable switch DHCP and let this server handle it

2. Test with one client machine:
   • Boot from network (F12 on most systems)
   • Should see PXE boot menu
   • Select "Boot from network"

3. Create user accounts:
   ssh ansible@{file}
   sudo create-user player001 password123

4. Optional: Create bulk users
   ssh ansible@{file}
   sudo create-bulk-users player 200 password123

📚 Documentation: ./docs/quickstart.md

🔍 Check server status:
   ssh ansible@{pxe}  'systemctl status dnsmasq'
   ssh ansible@{cache} 'docker ps'
   ssh ansible@{file}  'smbstatus'

❓ Having issues?
   ./docs/troubleshooting.md
   
""".format(pxe=pxe, cache=cache, file=file))
PYTHON
}

# Main execution
main() {
    banner
    
    # Run pre-flight checks
    if ! preflight_checks; then
        log_error "Pre-flight checks failed. Please fix the issues above."
        exit 1
    fi

    # Ensure SSH keys exist
    if ! ensure_ssh_keys; then
        log_error "SSH key setup failed"
        exit 1
    fi
    
    # Validate configuration
    if ! validate_config; then
        log_error "Configuration validation failed. Please fix config.yaml"
        exit 1
    fi
    
    # Show configuration summary
    show_config_summary
    
    # If check mode, stop here
    if [[ "$MODE" == "check" ]]; then
        log_success "Pre-flight checks complete. Ready to deploy!"
        echo ""
        echo "Run './deploy.sh' to start deployment"
        exit 0
    fi
    
    # Confirm deployment
    echo ""
    read -p "Start deployment? (yes/no): " -r
    if [[ ! $REPLY =~ ^[Yy](es)?$ ]]; then
        log_info "Deployment cancelled"
        exit 0
    fi
    
    # Deploy
    if deploy; then
        show_completion_info
        exit 0
    else
        log_error "Deployment failed. Check errors above."
        exit 1
    fi
}

# Handle errors
trap 'log_error "An unexpected error occurred. Check output above."; exit 1' ERR

# Run
main "$@"