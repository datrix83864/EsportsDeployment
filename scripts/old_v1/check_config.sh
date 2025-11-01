#!/bin/bash
#
# Configuration Checker
# Validates config.yaml before running deploy.sh
#
# Usage: ./scripts/check_config.sh
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[✓]${NC} $1"; }
log_fail() { echo -e "${RED}[✗]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[!]${NC} $1"; }

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config.yaml"

ERRORS=0
WARNINGS=0

echo "╔═══════════════════════════════════════════════════════╗"
echo "║  Configuration Checker                                 ║"
echo "╚═══════════════════════════════════════════════════════╝"
echo ""

# Check if config.yaml exists
log_info "Checking for config.yaml..."
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_fail "config.yaml not found!"
    echo "  Create it from the example:"
    echo "    cp config.example.yaml config.yaml"
    exit 1
fi
log_success "config.yaml exists"

# Check if Python and PyYAML are available
log_info "Checking Python dependencies..."
if ! python3 -c "import yaml" 2>/dev/null; then
    log_fail "PyYAML not installed!"
    echo "  Install with: pip3 install pyyaml"
    exit 1
fi
log_success "Python and PyYAML available"

echo ""
log_info "Validating Proxmox configuration..."

# Check Proxmox settings
python3 - "$CONFIG_FILE" <<'PYTHON_CHECK'
import sys
import yaml

config_file = sys.argv[1]
errors = 0
warnings = 0

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f) or {}
except Exception as e:
    print(f"✗ Failed to parse YAML: {e}")
    sys.exit(1)

proxmox = config.get('proxmox', {}) or {}

# Check node_name
node_name = proxmox.get('node_name', '') or proxmox.get('node', '')
if not node_name:
    print("✗ proxmox.node_name is NOT set!")
    print("  Add to config.yaml:")
    print("    proxmox:")
    print("      node_name: 'pve'  # or your Proxmox node name")
    errors += 1
else:
    print(f"✓ proxmox.node_name = '{node_name}'")

# Check host
host = proxmox.get('host', '')
if not host:
    print("✗ proxmox.host is NOT set!")
    print("  Add to config.yaml:")
    print("    proxmox:")
    print("      host: '192.168.1.5'  # your Proxmox IP")
    errors += 1
else:
    print(f"✓ proxmox.host = '{host}'")
    # Check if it's an IP address
    import re
    if not re.match(r'^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$', host):
        print(f"! WARNING: proxmox.host looks like a hostname, not an IP")
        print(f"  Prefer using IP address for reliability")
        warnings += 1

# Check storage
vm_storage = proxmox.get('vm_storage', '')
if not vm_storage:
    print("✗ proxmox.vm_storage is NOT set!")
    print("  Add to config.yaml:")
    print("    proxmox:")
    print("      vm_storage: 'local-lvm'  # or your storage name")
    errors += 1
else:
    print(f"✓ proxmox.vm_storage = '{vm_storage}'")

# Check network bridge
network_bridge = proxmox.get('network_bridge', config.get('network', {}).get('bridge', ''))
if not network_bridge:
    print("! WARNING: network_bridge not set, will use default 'vmbr0'")
    warnings += 1
else:
    print(f"✓ network_bridge = '{network_bridge}'")

print("")
if errors > 0:
    print(f"✗ Found {errors} error(s) and {warnings} warning(s)")
    sys.exit(1)
elif warnings > 0:
    print(f"✓ Configuration valid with {warnings} warning(s)")
    sys.exit(0)
else:
    print("✓ All Proxmox settings configured correctly!")
    sys.exit(0)

PYTHON_CHECK

if [[ $? -ne 0 ]]; then
    ERRORS=$((ERRORS + 1))
fi

echo ""
log_info "Validating network configuration..."

python3 - "$CONFIG_FILE" <<'PYTHON_CHECK'
import sys
import yaml

config_file = sys.argv[1]
errors = 0

try:
    with open(config_file, 'r') as f:
        config = yaml.safe_load(f) or {}
except:
    sys.exit(1)

network = config.get('network', {}) or {}

# Check required IPs
required_ips = ['ipxe_server_ip', 'lancache_server_ip', 'file_server_ip', 'gateway']
for ip_field in required_ips:
    ip = network.get(ip_field, '')
    if not ip:
        print(f"✗ network.{ip_field} is NOT set!")
        errors += 1
    else:
        print(f"✓ network.{ip_field} = '{ip}'")

print("")
if errors > 0:
    print(f"✗ Found {errors} network configuration error(s)")
    sys.exit(1)
else:
    print("✓ Network configuration looks good!")
    sys.exit(0)

PYTHON_CHECK

if [[ $? -ne 0 ]]; then
    ERRORS=$((ERRORS + 1))
fi

echo ""
if [[ $ERRORS -eq 0 ]]; then
    log_success "Configuration validation passed!"
    echo ""
    echo "You can now run:"
    echo "  ./deploy.sh --component ipxe"
    echo ""
    exit 0
else
    log_fail "Configuration validation failed with $ERRORS error(s)"
    echo ""
    echo "Fix the errors above and try again."
    exit 1
fi