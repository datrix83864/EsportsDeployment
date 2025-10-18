#!/bin/bash
#
# Debug Terraform → Proxmox Connection
# Checks common issues preventing Terraform from creating VMs
#

set -euo pipefail

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

cat << "EOF"
╔═══════════════════════════════════════════════════════╗
║  Terraform → Proxmox Connection Debugger             ║
╚═══════════════════════════════════════════════════════╝

EOF

ERRORS=0

# Check 1: Terraform installed
log_info "Checking Terraform installation..."
if command -v terraform &> /dev/null; then
    VERSION=$(terraform --version | head -1)
    log_success "Terraform installed: $VERSION"
else
    log_fail "Terraform not found"
    ERRORS=$((ERRORS + 1))
fi

# Check 2: In terraform directory
log_info "Checking current directory..."
if [[ -f "main.tf" ]] || [[ -f "providers.tf" ]]; then
    log_success "In terraform directory"
else
    log_fail "Not in terraform directory. Run: cd terraform/"
    ERRORS=$((ERRORS + 1))
fi

# Check 3: Config file exists
log_info "Checking for config.yaml..."
if [[ -f "../config.yaml" ]]; then
    log_success "config.yaml found"
else
    log_fail "config.yaml not found. Copy config.example.yaml to config.yaml"
    ERRORS=$((ERRORS + 1))
fi

# Check 4: Terraform initialized
log_info "Checking Terraform initialization..."
if [[ -d ".terraform" ]]; then
    log_success "Terraform initialized"
else
    log_warning "Terraform not initialized. Run: terraform init"
fi

# Check 5: Proxmox provider configured
log_info "Checking Proxmox provider..."
if grep -q "telmate/proxmox" .terraform.lock.hcl 2>/dev/null; then
    log_success "Proxmox provider installed"
else
    log_warning "Proxmox provider not found. Run: terraform init"
fi

echo ""
log_info "Checking Proxmox connection settings..."
echo ""

# Ask for Proxmox details
read -p "Proxmox host (e.g., proxmox.local or 192.168.1.5): " PROXMOX_HOST
read -p "Proxmox API port (default 8006): " PROXMOX_PORT
PROXMOX_PORT=${PROXMOX_PORT:-8006}
read -p "Proxmox user (e.g., root@pam): " PROXMOX_USER
read -s -p "Proxmox password: " PROXMOX_PASSWORD
echo ""

# Check 6: Network connectivity
log_info "Testing network connectivity to Proxmox..."
if ping -c 2 "$PROXMOX_HOST" &> /dev/null; then
    log_success "Can ping Proxmox host"
else
    log_fail "Cannot ping Proxmox host at $PROXMOX_HOST"
    ERRORS=$((ERRORS + 1))
fi

# Check 7: HTTPS connectivity
log_info "Testing HTTPS connectivity..."
if curl -k -s "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json" &> /dev/null; then
    log_success "Can reach Proxmox API"
else
    log_fail "Cannot reach Proxmox API at https://${PROXMOX_HOST}:${PROXMOX_PORT}"
    log_warning "Check firewall and API port"
    ERRORS=$((ERRORS + 1))
fi

# Check 8: API Authentication
log_info "Testing API authentication..."
TOKEN=$(curl -k -s -d "username=${PROXMOX_USER}&password=${PROXMOX_PASSWORD}" \
    "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/access/ticket" | \
    python3 -c "import sys, json; print(json.load(sys.stdin).get('data', {}).get('ticket', ''))" 2>/dev/null)

if [[ -n "$TOKEN" ]]; then
    log_success "Successfully authenticated to Proxmox API"
else
    log_fail "Authentication failed"
    log_warning "Check username/password"
    ERRORS=$((ERRORS + 1))
fi

# Check 9: Node exists
log_info "Checking Proxmox nodes..."
if [[ -n "$TOKEN" ]]; then
    NODES=$(curl -k -s -H "Authorization: PVEAuthCookie=$TOKEN" \
        "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes" | \
        python3 -c "import sys, json; data = json.load(sys.stdin).get('data', []); print(' '.join([n['node'] for n in data]))" 2>/dev/null)
    
    if [[ -n "$NODES" ]]; then
        log_success "Found nodes: $NODES"
    else
        log_fail "No nodes found"
        ERRORS=$((ERRORS + 1))
    fi
fi

# Check 10: Storage pools
log_info "Checking storage pools..."
if [[ -n "$TOKEN" ]] && [[ -n "$NODES" ]]; then
    FIRST_NODE=$(echo $NODES | awk '{print $1}')
    STORAGE=$(curl -k -s -H "Authorization: PVEAuthCookie=$TOKEN" \
        "https://${PROXMOX_HOST}:${PROXMOX_PORT}/api2/json/nodes/${FIRST_NODE}/storage" | \
        python3 -c "import sys, json; data = json.load(sys.stdin).get('data', []); print(' '.join([s['storage'] for s in data]))" 2>/dev/null)
    
    if [[ -n "$STORAGE" ]]; then
        log_success "Found storage: $STORAGE"
    else
        log_warning "No storage found"
    fi
fi

echo ""
echo "Summary:"
echo "--------"
if [[ $ERRORS -eq 0 ]]; then
    log_success "All checks passed! Connection to Proxmox working."
    echo ""
    echo "Next steps:"
    echo "  1. Create terraform.tfvars file with your Proxmox credentials"
    echo "  2. Run: terraform plan"
    echo "  3. Run: terraform apply"
else
    log_fail "$ERRORS error(s) found. Fix the issues above."
fi

# Generate terraform.tfvars template
if [[ $ERRORS -eq 0 ]]; then
    echo ""
    log_info "Generating terraform.tfvars..."
    
    cat > terraform.tfvars << EOF
# Proxmox Connection Settings
# DO NOT COMMIT THIS FILE TO GIT!

proxmox_host = "$PROXMOX_HOST"
proxmox_port = $PROXMOX_PORT
proxmox_user = "$PROXMOX_USER"
proxmox_password = "$PROXMOX_PASSWORD"
proxmox_node = "${FIRST_NODE:-pve}"

# Skip TLS verification (self-signed certs)
proxmox_tls_insecure = true
EOF
    
    log_success "Created terraform.tfvars"
    log_warning "Make sure terraform.tfvars is in .gitignore!"
fi