#!/bin/bash
#
# Esports LAN Infrastructure - Main Deployment Script
#
# This script orchestrates the deployment of all infrastructure components
# on Proxmox VE for esports events.
#
# Usage:
#   ./deploy.sh [options]
#
# Options:
#   -c, --config FILE    Configuration file (default: config.yaml)
#   -h, --help          Show this help message
#   -v, --verbose       Enable verbose output
#   -d, --dry-run       Show what would be done without making changes
#   --skip-validation   Skip configuration validation
#   --component NAME    Deploy only specific component (ipxe|lancache|fileserver|windows)
#

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"

# Default values
CONFIG_FILE="${PROJECT_ROOT}/config.yaml"
VERBOSE=false
DRY_RUN=false
SKIP_VALIDATION=false
COMPONENT=""
INTERACTIVE=false
AUTO_CONFIRM=false
INTERACTIVE_CONFIG=false

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

show_help() {
    cat << EOF
High School Esports LAN Infrastructure Deployment

Usage: $0 [options]

Options:
  -c, --config FILE      Configuration file (default: config.yaml)
  -h, --help            Show this help message
  -v, --verbose         Enable verbose output
  -d, --dry-run         Show what would be done without making changes
  --skip-validation     Skip configuration validation
  --component NAME      Deploy only specific component:
                          - ipxe: iPXE boot server
                          - lancache: LANCache server
                          - fileserver: File server and roaming profiles
                          - windows: Windows image builder
                          - all: Deploy everything (default)

Examples:
  $0                                    # Deploy everything
  $0 -c myconfig.yaml                   # Use custom config
  $0 --component lancache               # Deploy only LANCache
  $0 -d --verbose                       # Dry run with verbose output
    $0 --interactive                     # Run interactive guided mode
    $0 --yes                             # Automatically answer yes to confirmations (useful in scripts)

EOF
    exit 0
}

parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            -c|--config)
                CONFIG_FILE="$2"
                shift 2
                ;;
            -h|--help)
                show_help
                ;;
            -v|--verbose)
                VERBOSE=true
                shift
                ;;
            -d|--dry-run)
                DRY_RUN=true
                shift
                ;;
            --skip-validation)
                SKIP_VALIDATION=true
                shift
                ;;
            --component)
                COMPONENT="$2"
                shift 2
                ;;
            --interactive)
                INTERACTIVE=true
                shift
                ;;
            --configure)
                # Launch interactive configuration editor and exit
                INTERACTIVE_CONFIG=true
                shift
                ;;
            --yes)
                AUTO_CONFIRM=true
                shift
                ;;
            *)
                log_error "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing_tools=()
    
    # Check for required tools
    local required_tools=("python3" "ansible" "terraform" "git")
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        log_info "Please install missing tools and try again"
        exit 1
    fi
    
    # Check Python version
    local python_version=$(python3 --version | cut -d' ' -f2 | cut -d'.' -f1-2)
    local required_version="3.8"
    
    if [[ $(echo -e "$python_version\n$required_version" | sort -V | head -n1) != "$required_version" ]]; then
        log_error "Python $required_version or higher is required (found $python_version)"
        exit 1
    fi
    
    # Check if PyYAML is installed (needed for YAML to JSON conversion)
    if ! python3 -c "import yaml" 2>/dev/null; then
        log_warning "PyYAML not found. Attempting to install..."
        if ! python3 -m pip install pyyaml 2>/dev/null; then
            log_error "Failed to install PyYAML. Please install it manually:"
            log_info "  pip3 install pyyaml"
            exit 1
        fi
        log_success "PyYAML installed successfully"
    fi
    
    # Check if running from project root
    if [[ ! -f "${PROJECT_ROOT}/config.example.yaml" ]]; then
        log_error "Please run this script from the project root directory"
        exit 1
    fi
    
    log_success "All prerequisites met"
}

validate_config() {
    if [[ "$SKIP_VALIDATION" == true ]]; then
        log_warning "Skipping configuration validation"
        return 0
    fi
    
    log_info "Validating configuration file: $CONFIG_FILE"
    
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        log_info "Copy config.example.yaml to config.yaml and customize it"
        exit 1
    fi
    
    # Run Python validator
    if [[ -f "${SCRIPT_DIR}/validate_config.py" ]]; then
        if ! python3 "${SCRIPT_DIR}/validate_config.py" "$CONFIG_FILE"; then
            log_error "Configuration validation failed"
            exit 1
        fi
    else
        log_warning "Configuration validator not found, skipping detailed validation"
    fi
    
    log_success "Configuration validated successfully"
}

convert_config_for_terraform() {
    log_info "Converting YAML config to Terraform-compatible JSON..."
    
    local tf_vars_file="${PROJECT_ROOT}/terraform/terraform.tfvars.json"
    
    # Create terraform directory if it doesn't exist
    mkdir -p "${PROJECT_ROOT}/terraform"
    
    # Convert YAML to JSON using Python
    python3 - "$CONFIG_FILE" "$tf_vars_file" << 'PYTHON_SCRIPT'
import sys
import yaml
import json

config_file = sys.argv[1]
output_file = sys.argv[2]

def build_proxmox_vars(cfg):
    # cfg is the top-level config loaded from YAML
    proxmox_cfg = cfg.get('proxmox', {}) or {}
    network_cfg = cfg.get('network', {}) or {}
    # Allow proxmox IP to be provided in several places in config.yaml so
    # users can keep management IPs with other network settings. Order of
    # precedence (first non-empty wins): proxmox.host, network.proxmox_ip,
    # network.proxmox_server_ip
    host = proxmox_cfg.get('host', '') or network_cfg.get('proxmox_ip', '') or network_cfg.get('proxmox_server_ip', '')
    # Prefer explicit api_url if provided in proxmox.host; otherwise try to
    # construct from host (may be hostname or IP) and default port 8006.
    # If a short hostname is provided (e.g. "pve") we still construct a
    # URL for backward compatibility but print a warning recommending an IP
    # because name resolution may not be available on the machine running
    # this script. If the host looks like an IPv4 address (with optional
    # :port) we build a sensible https://<ip>:<port>/api2/json URL.
    api_url = ""
    if host:
        # If the host already contains a scheme, use it verbatim
        if host.startswith('http'):
            api_url = host
        else:
            import re
            # Match IPv4 optionally with :port
            m = re.match(r'^(?P<ip>\d{1,3}(?:\.\d{1,3}){3})(?::(?P<port>\d+))?$', host)
            if m:
                ip = m.group('ip')
                port = m.group('port') or '8006'
                api_url = f"https://{ip}:{port}/api2/json"
            else:
                # Host is a non-IP hostname. Build URL for compatibility but
                # warn so users prefer using numeric IPs which are static.
                api_url = f"https://{host}:8006/api2/json"
                print(f"[WARNING] proxmox.host '{host}' looks like a hostname rather than an IP.\n  Using hostnames can fail if your machine cannot resolve that name.\n  Prefer setting proxmox.host to the management IP (e.g. 192.168.1.5) or set TF_VAR_proxmox_api_url explicitly.", file=sys.stderr)

    return {
        'proxmox_api_url': api_url,
        'proxmox_api_token_id': proxmox_cfg.get('api_token_id', ''),
        'proxmox_api_token_secret': proxmox_cfg.get('api_token_secret', ''),
        'proxmox_user': proxmox_cfg.get('user', proxmox_cfg.get('username', '')),
        'proxmox_password': proxmox_cfg.get('password', ''),
        'proxmox_tls_insecure': proxmox_cfg.get('tls_insecure', True),
        'proxmox_node': proxmox_cfg.get('node_name', proxmox_cfg.get('node', '')),
        'proxmox_vm_storage': proxmox_cfg.get('vm_storage', proxmox_cfg.get('vm_storage', '')),
        'proxmox_iso_storage': proxmox_cfg.get('iso_storage', proxmox_cfg.get('iso_storage', '')),
        'network_bridge': proxmox_cfg.get('network_bridge', network_cfg.get('network_bridge', network_cfg.get('bridge', 'vmbr0'))),
    }

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f) or {}

    # Build the base tfvars with the full config for module-level access
    tf_vars = { 'config': config }

    # Merge provider-level proxmox variables so Terraform provider has explicit values
    proxmox_vars = build_proxmox_vars(config)
    # Only include non-empty keys to avoid overwriting explicit tfvars on disk
    for k, v in proxmox_vars.items():
        tf_vars[k] = v

    # Write JSON file
    with open(output_file, 'w') as f:
        json.dump(tf_vars, f, indent=2)

    print(f"Successfully converted config to {output_file}")
    sys.exit(0)

except Exception as e:
    print(f"Error converting config: {e}", file=sys.stderr)
    sys.exit(1)
PYTHON_SCRIPT
    
    if [[ $? -ne 0 ]]; then
        log_error "Failed to convert config to Terraform format"
        exit 1
    fi

    # Quick sanity check: ensure proxmox_node is set in the generated tfvars JSON
    if ! python3 -c "import json, sys
try:
    d=json.load(open('terraform/terraform.tfvars.json'))
    pn=d.get('proxmox_node','')
    if not pn:
        print('[ERROR] proxmox_node is empty in terraform/terraform.tfvars.json.', file=sys.stderr)
        print('  Please set proxmox.node_name (or proxmox.node) in config.yaml', file=sys.stderr)
        print('  Or set TF_VAR_proxmox_node environment variable', file=sys.stderr)
        sys.exit(1)
    else:
        print(f'[INFO] proxmox_node set to: {pn}', file=sys.stderr)
        sys.exit(0)
except Exception as e:
    print(f'[ERROR] Failed to validate terraform.tfvars.json: {e}', file=sys.stderr)
    sys.exit(1)
" 2>&1; then
        log_error "proxmox_node validation failed"
        exit 1
    fi
    
    log_success "Config converted to Terraform JSON format"
}

preflight_checks() {
    log_info "Running preflight checks..."
    
    # Check Proxmox connectivity (if script exists)
    if [[ -f "${SCRIPT_DIR}/preflight_check.sh" ]]; then
        if ! bash "${SCRIPT_DIR}/preflight_check.sh" "$CONFIG_FILE"; then
            log_error "Preflight checks failed"
            exit 1
        fi
    else
        log_warning "Preflight check script not found, skipping"
    fi
    
    log_success "Preflight checks completed"
}

ensure_cloudinit_template() {
    # Skip in dry-run
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY RUN] Skipping cloud-init template check/creation"
        return 0
    fi

    log_info "Checking for Proxmox cloud-init template..."

    # Read proxmox host/node/storage and optional template name from config.yaml
    local proxmox_host proxmox_node proxmox_storage template_name image_url ssh_target use_api_token

    # Get proxmox host/node/storage/template/image/api flag from config via Python
    # Use a '|' delimiter so empty fields don't collapse when splitting on whitespace.
    IFS='|' read -r proxmox_host proxmox_node proxmox_storage template_name image_url use_api_token < <(python3 - "$CONFIG_FILE" <<'PY'
import sys,yaml
cfg = yaml.safe_load(open(sys.argv[1])) or {}
pm = cfg.get('proxmox', {}) or {}
host = pm.get('host','')
node = pm.get('node_name', pm.get('node','pve'))
storage = pm.get('vm_storage', 'local-lvm')
tpl = pm.get('template_name', '') or ''
img = pm.get('ubuntu_image_url') or 'https://cloud-images.ubuntu.com/jammy/current/jammy-server-cloudimg-amd64.img'
# detect if API token is configured (prefer API token for terraform but can't create template with it here)
api = bool(pm.get('api_token_id') or pm.get('api_token'))
print('|'.join([str(x) for x in [host,node,storage,tpl,img, int(api)]]))
PY
)

    # If api token is set in config we avoid trying SSH-based creation (user likely using token-only workflow)
    if [[ "$use_api_token" == 1 ]]; then
        log_info "Proxmox API token detected in config; skipping SSH-based template creation. Ensure template exists or set ubuntu_iso."
        return 0
    fi

    # Determine ssh target: allow PROXMOX_SSH_TARGET env override, otherwise default to root@host
    if [[ -n "${PROXMOX_SSH_TARGET:-}" ]]; then
        ssh_target="$PROXMOX_SSH_TARGET"
    else
        if [[ -z "$proxmox_host" ]]; then
            log_warning "Proxmox host not set in config; cannot auto-create template. Set proxmox.host in config.yaml or set PROXMOX_SSH_TARGET env variable."
            return 0
        fi
        ssh_target="root@${proxmox_host}"
    fi

    # Choose a sensible default template name if not provided
    if [[ -z "$template_name" ]]; then
        template_name="ubuntu-22.04-cloudinit"
    fi

    # Check remotely if template exists (using qm list and grep for exact name)
    if ssh "${ssh_target}" "qm list 2>/dev/null | awk '{for(i=2;i<=NF;i++) printf \"%s \",\$i; print \"\"}' | grep -F \"${template_name}\" >/dev/null 2>&1"; then
        log_success "Cloud-init template '${template_name}' already present on ${ssh_target}"
        
        # Validate the template is actually bootable
        log_info "Validating template configuration..."
        TEMPLATE_VMID=$(ssh "${ssh_target}" "qm list 2>/dev/null | grep -F \"${template_name}\" | awk '{print \$1}'")
        
        if [[ -n "${TEMPLATE_VMID}" ]]; then
            # Check if template has a valid boot disk
            BOOT_DISK=$(ssh "${ssh_target}" "qm config ${TEMPLATE_VMID} 2>/dev/null | grep -E '^(scsi0|ide0|sata0):' | head -1" || echo "")
            
            if [[ -z "${BOOT_DISK}" ]]; then
                log_error "Template '${template_name}' exists but has NO BOOT DISK configured!"
                log_error "This will cause VMs to fail to boot (infinite boot loop)."
                log_info "Removing invalid template and recreating..."
                ssh "${ssh_target}" "qm destroy ${TEMPLATE_VMID} --purge || true"
            else
                log_success "Template validated: Boot disk present (${BOOT_DISK})"
                return 0
            fi
        else
            log_warning "Could not determine template VMID for validation"
            return 0
        fi
    fi

    log_warning "Template '${template_name}' not found on ${ssh_target}. Attempting to create it using helper script..."


    if [[ ! -f "${SCRIPT_DIR}/ansible/playbooks/create_proxmox_template.yml" ]]; then
        log_error "Ansible playbook not found: ${SCRIPT_DIR}/ansible/playbooks/create_proxmox_template.yml"
        log_info "Create a cloud-init template manually or upload an ISO and set ubuntu_iso in terraform.tfvars"
        return 0
    fi

    # Run Ansible playbook against the Proxmox host (use ssh_target as inventory)
    log_info "Running Ansible playbook to create template '${template_name}' on ${ssh_target}"
    # Build temporary inventory file
    inv_file="/tmp/proxmox_inv_$$.ini"
    echo "[proxmox]" > "$inv_file"
    echo "${ssh_target}" >> "$inv_file"

    ansible-playbook -i "$inv_file" "${SCRIPT_DIR}/ansible/playbooks/create_proxmox_template.yml" \
        -e "storage=${proxmox_storage}" \
        -e "template_name=${template_name}" \
        -e "image_url=${image_url}" \
        ${VERBOSE:+-vvv} || {
        rm -f "$inv_file"
        log_error "Ansible playbook failed to create template '${template_name}'."
        offer_iso_alternative
        
        # Ask user if they want to download ISO instead
        if [[ "$INTERACTIVE" == true ]] || [[ -t 0 ]]; then
            echo ""
            read -p "Would you like to download Ubuntu Server ISO instead? (y/N): " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "Starting Ubuntu Server ISO download..."
                if [[ -f "${SCRIPT_DIR}/scripts/download_ubuntu_iso.sh" ]]; then
                    bash "${SCRIPT_DIR}/scripts/download_ubuntu_iso.sh" "${proxmox_host}" "${ssh_target}" "local" "22.04"
                    log_info "ISO download complete. Please add 'ubuntu_iso: \"local:iso/ubuntu-22.04.5-live-server-amd64.iso\"' to config.yaml"
                else
                    log_error "ISO download script not found at ${SCRIPT_DIR}/scripts/download_ubuntu_iso.sh"
                fi
            fi
        fi
        return 1
    }

    rm -f "$inv_file"

    # Re-check
    if ssh "${ssh_target}" "qm list 2>/dev/null | awk '{for(i=2;i<=NF;i++) printf \"%s \",\$i; print \"\"}' | grep -F \"${template_name}\" >/dev/null 2>&1"; then
        log_success "Cloud-init template '${template_name}' created successfully"
        
        # Validate the newly created template
        log_info "Validating newly created template..."
        TEMPLATE_VMID=$(ssh "${ssh_target}" "qm list 2>/dev/null | grep -F \"${template_name}\" | awk '{print \$1}'")
        
        if [[ -n "${TEMPLATE_VMID}" ]]; then
            BOOT_DISK=$(ssh "${ssh_target}" "qm config ${TEMPLATE_VMID} 2>/dev/null | grep -E '^(scsi0|ide0|sata0):' | head -1" || echo "")
            
            if [[ -z "${BOOT_DISK}" ]]; then
                log_error "Template was created but has NO BOOT DISK! VMs will fail to boot."
                log_error "This usually means the cloud image download was corrupted or incomplete."
                offer_iso_alternative
                return 1
            else
                log_success "Template validation passed: Boot disk configured (${BOOT_DISK})"
            fi
        fi
    else
        log_error "Template creation attempted but '${template_name}' still not found. Please inspect Proxmox host."
        offer_iso_alternative
        return 1
    fi
}

offer_iso_alternative() {
    log_warning "=============================================="
    log_warning "Cloud-init template creation failed or is invalid."
    log_warning "=============================================="
    log_info ""
    log_info "You have two options to proceed:"
    log_info ""
    log_info "OPTION 1: Download and use Ubuntu Server ISO instead"
    log_info "  Run: ./scripts/download_ubuntu_iso.sh ${proxmox_host} root@${proxmox_host} local 22.04"
    log_info "  Then add to config.yaml under 'proxmox' section:"
    log_info "    ubuntu_iso: 'local:iso/ubuntu-22.04.5-live-server-amd64.iso'"
    log_info ""
    log_info "OPTION 2: Manually create the cloud-init template on Proxmox"
    log_info "  SSH to Proxmox and run:"
    log_info "    cd /var/tmp && wget ${image_url}"
    log_info "    VMID=\$(pvesh get /cluster/nextid)"
    log_info "    qm create \${VMID} --name ${template_name} --memory 2048 --cores 2"
    log_info "    qm importdisk \${VMID} $(basename ${image_url}) ${proxmox_storage}"
    log_info "    qm set \${VMID} --scsi0 ${proxmox_storage}:vm-\${VMID}-disk-0"
    log_info "    qm set \${VMID} --boot order=scsi0"
    log_info "    qm template \${VMID}"
    log_info ""
    log_warning "=============================================="
}

deploy_component() {
    local component=$1
    
    log_info "Deploying component: $component"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY RUN] Would deploy $component"
        return 0
    fi
    
    case $component in
        ipxe)
            log_info "Deploying iPXE boot server..."
            cd "${PROJECT_ROOT}/ansible"
            ansible-playbook -i inventory/hosts playbooks/deploy_ipxe.yml \
                -e "@${CONFIG_FILE}" \
                ${VERBOSE:+-vvv}
            ;;
        lancache)
            log_info "Deploying LANCache server..."
            cd "${PROJECT_ROOT}/ansible"
            ansible-playbook -i inventory/hosts playbooks/deploy_lancache.yml \
                -e "@${CONFIG_FILE}" \
                ${VERBOSE:+-vvv}
            ;;
        fileserver)
            log_info "Deploying file server..."
            cd "${PROJECT_ROOT}/ansible"
            ansible-playbook -i inventory/hosts playbooks/deploy_fileserver.yml \
                -e "@${CONFIG_FILE}" \
                ${VERBOSE:+-vvv}
            ;;
        windows)
            log_info "Deploying Windows image builder..."
            cd "${PROJECT_ROOT}/ansible"
            ansible-playbook -i inventory/hosts playbooks/deploy_windows_builder.yml \
                -e "@${CONFIG_FILE}" \
                ${VERBOSE:+-vvv}
            ;;
        all)
            log_info "Deploying all components..."
            cd "${PROJECT_ROOT}/ansible"
            ansible-playbook -i inventory/hosts playbooks/deploy_all.yml \
                -e "@${CONFIG_FILE}" \
                ${VERBOSE:+-vvv}
            ;;
        *)
            log_error "Unknown component: $component"
            log_info "Valid components: ipxe, lancache, fileserver, windows, all"
            exit 1
            ;;
    esac
    
    log_success "Component $component deployed successfully"
}

provision_infrastructure() {
    log_info "Provisioning infrastructure with Terraform..."
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY RUN] Would provision infrastructure"
        return 0
    fi
    
    # Check if terraform directory exists
    if [[ ! -d "${PROJECT_ROOT}/terraform" ]]; then
        log_warning "Terraform directory not found, skipping infrastructure provisioning"
        return 0
    fi
    
    cd "${PROJECT_ROOT}/terraform"
    
    # Initialize Terraform with retry (provider downloads can fail on transient network issues)
    log_info "Initializing Terraform..."
    local init_attempts=0
    local init_max=3
    local init_success=false
    while [ $init_attempts -lt $init_max ]; do
        init_attempts=$((init_attempts+1))
        if terraform init; then
            init_success=true
            break
        else
            log_warning "terraform init failed (attempt $init_attempts/$init_max). Retrying in $((init_attempts*5))s..."
            sleep $((init_attempts*5))
        fi
    done

    if [[ "$init_success" != true ]]; then
        log_error "Terraform initialization failed after $init_max attempts."
        log_info "Common causes: network connectivity to provider registries (github.com), transient DNS issues, or firewall blocking outbound HTTPS."
        log_info "Remedies:"
        log_info "  - Ensure the machine has outbound internet access to github.com:443"
        log_info "  - Run 'terraform init' manually inside the terraform/ directory to see full output"
        log_info "  - Consider using a provider mirror or plugin cache (set TF_PLUGIN_CACHE_DIR)"
        log_info "  - If rate-limited or blocked, mirror providers locally using 'terraform providers mirror' on a machine that can reach the registry"
        exit 1
    fi
    
    # Plan deployment using the converted JSON file
    log_info "Planning infrastructure changes..."
    terraform plan \
        -var-file="terraform.tfvars.json" \
        -out=tfplan
    
    # Apply if not in dry run
    if [[ "$DRY_RUN" != true ]]; then
        log_info "Applying infrastructure changes..."
        terraform apply tfplan
        rm -f tfplan
    fi
    
    log_success "Infrastructure provisioned successfully"
}

create_inventory() {
    log_info "Creating Ansible inventory..."
    
    # Parse config and create inventory
    # This will be implemented when we build the actual playbooks
    local inventory_file="${PROJECT_ROOT}/ansible/inventory/hosts"
    
    if [[ "$DRY_RUN" == true ]]; then
        log_warning "[DRY RUN] Would create inventory at $inventory_file"
        return 0
    fi
    
    # Create inventory directory if it doesn't exist
    mkdir -p "${PROJECT_ROOT}/ansible/inventory"
    
    log_info "Inventory will be created at: $inventory_file"
    # Read common host IPs from config.yaml using Python (safe YAML parsing)
    IPXE_IP="$(python3 -c 'import sys,yaml
cfg = yaml.safe_load(open(sys.argv[1]))
net = cfg.get("network", {})
print(net.get("ipxe_server_ip", ""))' "$CONFIG_FILE")" || IPXE_IP=""

    LANCACHE_IP="$(python3 -c 'import sys,yaml
cfg = yaml.safe_load(open(sys.argv[1]))
net = cfg.get("network", {})
print(net.get("lancache_server_ip", ""))' "$CONFIG_FILE")" || LANCACHE_IP=""

    FILESERVER_IP="$(python3 -c 'import sys,yaml
cfg = yaml.safe_load(open(sys.argv[1]))
net = cfg.get("network", {})
print(net.get("file_server_ip", ""))' "$CONFIG_FILE")" || FILESERVER_IP=""

    # Optional: allow a per-host ansible_user to be specified under ansible: in config
    ANSIBLE_USER="ansible"

    # Write inventory file
    cat > "$inventory_file" <<EOF
# Ansible Inventory
# Generated by deploy.sh

[ipxe_server]
$( [[ -n "$IPXE_IP" ]] && echo "$IPXE_IP ansible_user=${ANSIBLE_USER} ansible_become=yes" || echo "# ipxe_server IP not set in config.yaml; add it under network.ipxe_server_ip" )

[lancache_server]
$( [[ -n "$LANCACHE_IP" ]] && echo "$LANCACHE_IP ansible_user=${ANSIBLE_USER} ansible_become=yes" || echo "# lancache_server IP not set in config.yaml; add it under network.lancache_server_ip" )

[file_server]
$( [[ -n "$FILESERVER_IP" ]] && echo "$FILESERVER_IP ansible_user=${ANSIBLE_USER} ansible_become=yes" || echo "# file_server IP not set in config.yaml; add it under network.file_server_ip" )

[all:vars]
ansible_python_interpreter=/usr/bin/python3
EOF

    # Ensure inventory is readable
    chmod 0644 "$inventory_file" || true

    log_success "Inventory created at: $inventory_file"
}

show_summary() {
    log_info "Deployment Summary"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
    echo "Configuration: $CONFIG_FILE"
    echo "Component:     ${COMPONENT:-all}"
    echo "Dry Run:       $DRY_RUN"
    echo ""
    
    if [[ "$DRY_RUN" != true ]]; then
        echo "Your infrastructure is being deployed!"
        echo ""
        echo "Next Steps:"
        echo "  1. Monitor the Ansible playbook output for any errors"
        echo "  2. Verify VMs are running in Proxmox web interface"
        echo "  3. Test PXE boot from a client machine"
        echo "  4. Build Windows image: ./scripts/build_windows_image.sh"
        echo "  5. Review documentation in docs/ for detailed guides"
        echo ""
        echo "Troubleshooting:"
        echo "  - Check logs in /var/log/ on each VM"
        echo "  - Use ./scripts/troubleshoot.sh for common issues"
        echo "  - Refer to docs/troubleshooting.md"
    else
        echo "[DRY RUN] No changes were made"
        echo "Run without -d/--dry-run to perform actual deployment"
    fi
    
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║        Esports LAN Infrastructure Deployment              ║
║  Automated PXE Boot, LANCache, and File Server Setup      ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

prompt_confirm() {
    # prompt_confirm <message>
    local msg="$1"
    if [[ "$AUTO_CONFIRM" == true ]]; then
        log_info "Auto-confirm enabled; proceeding: $msg"
        return 0
    fi
    # Read from /dev/tty to avoid issues when stdin is redirected
    while true; do
        read -r -p "$msg [y/N]: " yn < /dev/tty || return 1
        case "$yn" in
            [Yy]* ) return 0 ;;
            [Nn]*|"" ) return 1 ;;
            * ) echo "Please answer y or n." ;;
        esac
    done
}

interactive_menu() {
    echo "Interactive deployment menu"
    echo "----------------------------"
    PS3='Select an action: '
    options=("Validate config" "Convert config for Terraform" "Preflight checks" "Ensure cloud-init template" "Provision infrastructure (Terraform)" "Create Ansible inventory" "Deploy component" "Full deploy (all)" "Edit configuration" "Show summary" "Quit")
    select opt in "${options[@]}"; do
        case $REPLY in
            1)
                validate_config || true
                ;;
            2)
                convert_config_for_terraform || true
                ;;
            3)
                preflight_checks || true
                ;;
            4)
                ensure_cloudinit_template || true
                ;;
            5)
                if prompt_confirm "About to run 'terraform apply' (may change infrastructure). Continue?"; then
                    provision_infrastructure || true
                else
                    log_info "Skipping Terraform apply"
                fi
                ;;
            6)
                create_inventory || true
                ;;
            7)
                echo "Available components: ipxe, lancache, fileserver, windows, all"
                read -r -p "Component to deploy: " comp < /dev/tty
                deploy_component "${comp}" || true
                ;;
            8)
                if prompt_confirm "About to run full deploy (Terraform + Ansible). Continue?"; then
                    provision_infrastructure || true
                    create_inventory || true
                    deploy_component all || true
                else
                    log_info "Skipping full deploy"
                fi
                ;;
            9)
                interactive_config_editor || true
                ;;
            10)
                show_summary || true
                ;;
            11)
                break
                ;;
            *) echo "Invalid option." ;;
        esac
        echo ""
    done
}

interactive_config_editor() {
    # Prompts user for common configuration values and writes them to config.yaml
    local cfg_file="${PROJECT_ROOT}/config.yaml"

    # Ensure config file exists (copy example if not)
    if [[ ! -f "$cfg_file" ]]; then
        if [[ -f "${PROJECT_ROOT}/config.example.yaml" ]]; then
            cp "${PROJECT_ROOT}/config.example.yaml" "$cfg_file"
            log_info "Created $cfg_file from example"
        else
            log_error "No config.example.yaml found to base new config on"
            return 1
        fi
    fi

    echo "Interactive configuration editor"
    echo "Press Enter to keep current value in brackets"

    # Helper to read a value with a default from config.yaml using python
    read_with_default() {
        local key_path="$1" # e.g. proxmox.host or network.ipxe_server_ip
        local cur
        cur=$(python3 - <<PY
import yaml,sys
cfg=yaml.safe_load(open('$cfg_file')) or {}
keys='${key_path}'.split('.')
v=cfg
for k in keys:
    if isinstance(v,dict):
        v=v.get(k,None)
    else:
        v=None
print('' if v is None else v)
PY
)
        local prompt="$2"
        local val
        read -r -p "$prompt [$cur]: " val < /dev/tty
        if [[ -z "$val" ]]; then
            printf "%s" "$cur"
        else
            printf "%s" "$val"
        fi
    }

    # Collect values
    prox_host=$(read_with_default "proxmox.host" "Proxmox host (IP or hostname)")
    prox_node=$(read_with_default "proxmox.node_name" "Proxmox node name")
    prox_vm_storage=$(read_with_default "proxmox.vm_storage" "Proxmox VM storage")
    ipxe_ip=$(read_with_default "network.ipxe_server_ip" "iPXE server IP")
    lancache_ip=$(read_with_default "network.lancache_server_ip" "LANCache server IP")
    fileserver_ip=$(read_with_default "network.file_server_ip" "File server IP")

    # Confirm and write back using Python to safely merge
    echo ""
    echo "About to write the following values to $cfg_file:"
    echo "  proxmox.host = $prox_host"
    echo "  proxmox.node_name = $prox_node"
    echo "  proxmox.vm_storage = $prox_vm_storage"
    echo "  network.ipxe_server_ip = $ipxe_ip"
    echo "  network.lancache_server_ip = $lancache_ip"
    echo "  network.file_server_ip = $fileserver_ip"

    if ! prompt_confirm "Write these values to $cfg_file?"; then
        log_info "Aborting configuration update"
        return 0
    fi

    # Merge and write using Python
    python3 - <<PY
import yaml,sys
cfg_path = '$cfg_file'
cfg = yaml.safe_load(open(cfg_path)) or {}
def set_path(cfg, path, val):
    keys = path.split('.')
    d = cfg
    for k in keys[:-1]:
        if k not in d or not isinstance(d[k], dict):
            d[k] = {}
        d = d[k]
    d[keys[-1]] = val

set_path(cfg, 'proxmox.host', '${prox_host}')
set_path(cfg, 'proxmox.node_name', '${prox_node}')
set_path(cfg, 'proxmox.vm_storage', '${prox_vm_storage}')
set_path(cfg, 'network.ipxe_server_ip', '${ipxe_ip}')
set_path(cfg, 'network.lancache_server_ip', '${lancache_ip}')
set_path(cfg, 'network.file_server_ip', '${fileserver_ip}')

with open(cfg_path, 'w') as f:
    yaml.safe_dump(cfg, f, default_flow_style=False)

print('Wrote updated configuration to', cfg_path)
PY

    # Regenerate terraform vars JSON
    convert_config_for_terraform || true
    log_success "Configuration update complete"
}

main() {
    banner
    
    # Parse command line arguments
    parse_arguments "$@"

    # If non-interactive configure requested, run that and exit
    if [[ "$INTERACTIVE_CONFIG" == true ]]; then
        interactive_config_editor
        exit 0
    fi
    
    # Set default component if not specified
    if [[ -z "$COMPONENT" ]]; then
        COMPONENT="all"
    fi
    
    # Enable verbose mode for Ansible if requested
    if [[ "$VERBOSE" == true ]]; then
        export ANSIBLE_STDOUT_CALLBACK=debug
        export ANSIBLE_VERBOSE=true
    fi
    
    # Main deployment flow
    check_prerequisites
    validate_config
    
    # Validate required config fields for automated deployment
    validate_required_fields
    
    # Convert YAML config to Terraform JSON format
    convert_config_for_terraform
    
    preflight_checks

    # Ensure cloud-init template exists on Proxmox (create it if missing and SSH access is available)
    ensure_cloudinit_template
    
    log_info "Starting deployment process..."
    
    # If interactive mode requested, present menu and exit
    if [[ "$INTERACTIVE" == true ]]; then
        interactive_menu
        log_info "Interactive session complete"
        exit 0
    fi

    # Provision VMs with Terraform
    provision_infrastructure
    
    # Create Ansible inventory
    create_inventory
    
    # Deploy components
    deploy_component "$COMPONENT"
    
    # Show summary
    show_summary
    
    log_success "Deployment completed successfully!"
    
    exit 0
}

validate_required_fields() {
    log_info "Validating required configuration fields..."

    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        exit 1
    fi

    python3 - <<PY
import sys, yaml, os, subprocess
cfg_path = '$CONFIG_FILE'
cfg = yaml.safe_load(open(cfg_path))
errors = []

# Network checks
net = cfg.get('network', {})
for key in ['ipxe_server_ip','lancache_server_ip','file_server_ip','gateway']:
    if not net.get(key):
        errors.append(f"network.{key} is missing or empty in config.yaml")

# VM checks
vms = cfg.get('vms', {})
for vm in ['ipxe_server','lancache_server','file_server']:
    vmcfg = vms.get(vm, {})
    if not vmcfg.get('cores'):
        errors.append(f"vms.{vm}.cores is missing or empty")
    if not vmcfg.get('memory'):
        errors.append(f"vms.{vm}.memory is missing or empty")
    if not vmcfg.get('disk_size') and not vmcfg.get('data_disk_size'):
        if vm == 'file_server':
            if not vmcfg.get('data_disk_size'):
                errors.append(f"vms.{vm}.data_disk_size or disk_size is missing or empty")
        else:
            errors.append(f"vms.{vm}.disk_size is missing or empty")

# SSH keys: auto-generate if missing
ssh_key = cfg.get('ssh_public_key') or cfg.get('ssh_public_keys') or None
ssh_priv_path = os.path.expanduser('~/.ssh/esports_deploy_key')
ssh_pub_path = ssh_priv_path + '.pub'
if not ssh_key:
    # If pub key file exists, load it; otherwise generate a keypair
    if os.path.exists(ssh_pub_path):
        with open(ssh_pub_path, 'r') as f:
            pub = f.read().strip()
            cfg['ssh_public_key'] = pub
    else:
        try:
            print('[INFO] No ssh_public_key found in config. Generating keypair at ~/.ssh/esports_deploy_key')
            os.makedirs(os.path.dirname(ssh_priv_path), exist_ok=True)
            # Use ssh-keygen to generate an unencrypted key
            subprocess.check_call(['ssh-keygen', '-t', 'rsa', '-b', '4096', '-N', '', '-f', ssh_priv_path])
            with open(ssh_pub_path, 'r') as f:
                pub = f.read().strip()
            cfg['ssh_public_key'] = pub
            # Write back to config.yaml to persist the public key (best-effort)
            try:
                with open(cfg_path, 'w') as f:
                    yaml.safe_dump(cfg, f, default_flow_style=False)
                print(f"[INFO] Injected generated ssh_public_key into {cfg_path}")
            except Exception as e:
                print(f"[WARNING] Could not write public key to {cfg_path}: {e}")
        except Exception as e:
            errors.append(f"Failed to generate SSH keypair: {e}")

# Provider credentials: check environment variables for TF_VAR_ or variables in config
env_id = os.environ.get('TF_VAR_proxmox_api_token_id')
env_secret = os.environ.get('TF_VAR_proxmox_api_token_secret')
cfg_token = None
if isinstance(cfg, dict) and cfg.get('proxmox'):
    cfg_token = cfg['proxmox'].get('api_token_id') or cfg['proxmox'].get('api_token')

if not (env_id and env_secret) and not cfg_token:
    # Don't fail; provide actionable guidance instead
    print('\n[WARNING] Proxmox API token not found.')
    print('  - You can set environment variables TF_VAR_proxmox_api_token_id and TF_VAR_proxmox_api_token_secret')
    print('  - Or add proxmox.api_token_id and proxmox.api_token to your config.yaml')
    print('\nTo create a Proxmox API token:')
    print('  1. In the Proxmox web UI go to Datacenter -> Permissions -> API Tokens')
    print('  2. Create a token for a user with sufficient permissions and copy the token id and secret')
    print('  3. Export them on your shell:')
    print('       export TF_VAR_proxmox_api_token_id=tokenid@pve')
    print('       export TF_VAR_proxmox_api_token_secret=tokensecret')
    print('  4. Or add them under proxmox: in config.yaml')

if errors:
    print('\n[ERROR] Required configuration validation failed:')
    for e in errors:
        print('  -', e)
    sys.exit(2)
else:
    print('[SUCCESS] Required configuration fields present or auto-generated')
    sys.exit(0)
PY

    if [[ $? -ne 0 ]]; then
        log_error "Required configuration validation failed. See messages above."
        exit 1
    fi
}

# Handle errors
trap 'log_error "An error occurred during deployment. Check the output above for details."; exit 1' ERR

# Run main function
main "$@"