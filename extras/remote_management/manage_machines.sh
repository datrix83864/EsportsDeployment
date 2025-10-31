#!/bin/bash
#
# Machine Management Script
# Remote power management for tournament machines
#
# Usage:
#   ./manage_machines.sh --action [shutdown|reboot|lock|unlock|wol] --target [all|cluster|machine]
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$PROJECT_ROOT/config.yaml"
MAC_FILE="$PROJECT_ROOT/config/mac-addresses.yaml"

# Network settings
NETWORK_RANGE="192.168.1.0/24"
BROADCAST="192.168.1.255"

show_help() {
    cat << EOF
Machine Management Script

Usage:
  $0 --action <action> --target <target> [options]

Actions:
  shutdown      Shut down machines gracefully
  reboot        Reboot machines
  lock          Lock user sessions
  unlock        Unlock user sessions  
  wol           Wake-on-LAN (power on)
  disable       Disable network (isolate machine)
  enable        Enable network

Targets:
  all           All tournament machines
  cluster NAME  Specific cluster (e.g., "gryffindor", "slytherin")
  machine NAME  Specific machine by name or IP
  ip IP_ADDRESS Specific IP address
  range START-END IP range (e.g., 100-150)

Clusters:
  Define clusters in config/clusters.yaml for grouped management

Options:
  --confirm     Skip confirmation prompts (dangerous!)
  --wait SECONDS Wait time between actions (default: 2)
  --dry-run     Show what would be done without doing it

Examples:
  # Shut down all machines
  $0 --action shutdown --target all

  # Reboot specific machine
  $0 --action reboot --target machine ENTERPRISE

  # Lock a cluster
  $0 --action lock --target cluster gryffindor

  # Wake machines in IP range
  $0 --action wol --target range 100-120

  # Disable network for specific machine
  $0 --action disable --target ip 192.168.1.105

EOF
}

# Parse arguments
ACTION=""
TARGET=""
TARGET_VALUE=""
CONFIRM=false
WAIT_TIME=2
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --action)
            ACTION="$2"
            shift 2
            ;;
        --target)
            TARGET="$2"
            if [[ "$2" != "all" ]]; then
                TARGET_VALUE="${3:-}"
                shift
            fi
            shift 2
            ;;
        --confirm)
            CONFIRM=true
            shift
            ;;
        --wait)
            WAIT_TIME="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            show_help
            exit 1
            ;;
    esac
done

# Validate required arguments
if [[ -z "$ACTION" ]] || [[ -z "$TARGET" ]]; then
    log_error "Missing required arguments"
    show_help
    exit 1
fi

# Get list of target IPs based on target type
get_target_ips() {
    local target=$1
    local value=$2
    local ips=()
    
    case $target in
        all)
            # Get all IPs in DHCP range
            local start=$(echo "$NETWORK_RANGE" | cut -d'/' -f1 | cut -d'.' -f4)
            for i in {100..254}; do
                ips+=("192.168.1.$i")
            done
            ;;
        
        cluster)
            # Read cluster definition from file
            if [[ -f "$PROJECT_ROOT/config/clusters.yaml" ]]; then
                # Parse YAML for cluster IPs (simplified)
                ips=($(grep -A 100 "^$value:" "$PROJECT_ROOT/config/clusters.yaml" | grep "  - " | sed 's/  - //' | head -50))
            else
                log_error "Clusters file not found: $PROJECT_ROOT/config/clusters.yaml"
                exit 1
            fi
            ;;
        
        machine)
            # Look up machine name in MAC addresses file
            if [[ -f "$MAC_FILE" ]]; then
                # Get IP for named machine (would need proper YAML parsing)
                log_warning "Machine name lookup not yet implemented, use IP or range"
                exit 1
            fi
            ;;
        
        ip)
            ips=("$value")
            ;;
        
        range)
            # Parse range like "100-150"
            local start=$(echo "$value" | cut -d'-' -f1)
            local end=$(echo "$value" | cut -d'-' -f2)
            for i in $(seq $start $end); do
                ips+=("192.168.1.$i")
            done
            ;;
        
        *)
            log_error "Invalid target: $target"
            exit 1
            ;;
    esac
    
    echo "${ips[@]}"
}

# Check if machine is online
is_online() {
    local ip=$1
    ping -c 1 -W 1 "$ip" &> /dev/null
}

# Shutdown machine
action_shutdown() {
    local ip=$1
    log_info "Shutting down $ip..."
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "[DRY RUN] Would shutdown $ip"
        return 0
    fi
    
    # Use SSH or WMI/PowerShell for Windows
    # Method 1: SSH (if configured)
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "administrator@$ip" "shutdown /s /t 10" 2>/dev/null || \
    # Method 2: WinRM (if enabled)
    curl -u "administrator:password" --ntlm "http://$ip:5985/wsman" \
        -H "Content-Type: application/soap+xml;charset=UTF-8" \
        -d '<s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body><Shutdown/></s:Body></s:Envelope>' 2>/dev/null || \
    # Method 3: Wake-on-LAN magic packet (shutdown)
    log_warning "Could not connect to $ip - may need manual shutdown"
}

# Reboot machine
action_reboot() {
    local ip=$1
    log_info "Rebooting $ip..."
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "[DRY RUN] Would reboot $ip"
        return 0
    fi
    
    ssh -o ConnectTimeout=5 -o StrictHostKeyChecking=no "administrator@$ip" "shutdown /r /t 10" 2>/dev/null || \
    log_warning "Could not connect to $ip"
}

# Lock user session
action_lock() {
    local ip=$1
    log_info "Locking session on $ip..."
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "[DRY RUN] Would lock $ip"
        return 0
    fi
    
    ssh -o ConnectTimeout=5 "administrator@$ip" "rundll32.exe user32.dll,LockWorkStation" 2>/dev/null || \
    log_warning "Could not lock $ip"
}

# Wake-on-LAN
action_wol() {
    local ip=$1
    log_info "Sending Wake-on-LAN to $ip..."
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "[DRY RUN] Would send WOL to $ip"
        return 0
    fi
    
    # Need MAC address for WOL
    # Look up in MAC addresses file or ARP cache
    local mac=$(arp -n "$ip" | grep "$ip" | awk '{print $3}')
    
    if [[ -z "$mac" ]]; then
        log_warning "MAC address not found for $ip"
        return 1
    fi
    
    # Send WOL magic packet
    wakeonlan "$mac" || \
    etherwake "$mac" || \
    log_warning "WOL tools not installed (install wakeonlan or etherwake)"
}

# Disable network (via DHCP or switch management)
action_disable() {
    local ip=$1
    log_info "Disabling network for $ip..."
    
    if [[ $DRY_RUN == true ]]; then
        log_warning "[DRY RUN] Would disable network for $ip"
        return 0
    fi
    
    # Method 1: Disable network adapter via PowerShell
    ssh -o ConnectTimeout=5 "administrator@$ip" \
        "powershell.exe -Command \"Disable-NetAdapter -Name 'Ethernet' -Confirm:\$false\"" 2>/dev/null || \
    
    # Method 2: Add to DHCP deny list (would need dnsmasq modification)
    log_warning "Network disable may require manual intervention"
}

# Confirmation prompt
confirm_action() {
    if [[ $CONFIRM == true ]]; then
        return 0
    fi
    
    local count=$1
    echo ""
    log_warning "About to perform action '$ACTION' on $count machine(s)"
    log_warning "Target: $TARGET ${TARGET_VALUE:-}"
    echo ""
    read -p "Are you sure? Type 'yes' to confirm: " -r
    
    if [[ $REPLY != "yes" ]]; then
        log_info "Cancelled by user"
        exit 0
    fi
}

# Main execution
main() {
    log_info "Machine Management Tool"
    echo ""
    
    # Get target IPs
    IPS=($(get_target_ips "$TARGET" "$TARGET_VALUE"))
    
    log_info "Action: $ACTION"
    log_info "Target: $TARGET ${TARGET_VALUE:-}"
    log_info "Machines: ${#IPS[@]}"
    echo ""
    
    # Confirm action
    confirm_action "${#IPS[@]}"
    
    # Filter to online machines (except for WOL)
    if [[ "$ACTION" != "wol" ]]; then
        log_info "Checking which machines are online..."
        ONLINE_IPS=()
        for ip in "${IPS[@]}"; do
            if is_online "$ip"; then
                ONLINE_IPS+=("$ip")
            fi
        done
        log_info "Online machines: ${#ONLINE_IPS[@]}/${#IPS[@]}"
        IPS=("${ONLINE_IPS[@]}")
    fi
    
    if [[ ${#IPS[@]} -eq 0 ]]; then
        log_error "No target machines found or online"
        exit 1
    fi
    
    # Perform action on each IP
    local success=0
    local failed=0
    
    for ip in "${IPS[@]}"; do
        case $ACTION in
            shutdown)
                action_shutdown "$ip" && ((success++)) || ((failed++))
                ;;
            reboot)
                action_reboot "$ip" && ((success++)) || ((failed++))
                ;;
            lock)
                action_lock "$ip" && ((success++)) || ((failed++))
                ;;
            wol)
                action_wol "$ip" && ((success++)) || ((failed++))
                ;;
            disable)
                action_disable "$ip" && ((success++)) || ((failed++))
                ;;
            *)
                log_error "Unknown action: $ACTION"
                exit 1
                ;;
        esac
        
        sleep "$WAIT_TIME"
    done
    
    echo ""
    log_success "Complete: $success successful, $failed failed"
}

main "$@"