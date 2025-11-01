#!/bin/bash
#
# VM Diagnostic and Fix Tool
# Diagnoses and fixes common cloud-init VM issues
#
# Usage:
#   ./diagnose_vms.sh
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
║  VM Diagnostic Tool                                   ║
║  Fixes cloud-init and networking issues               ║
╚═══════════════════════════════════════════════════════╝

EOF

# VM IDs to check
VMS=(100 101 102)
VM_NAMES=("pxe-server" "lancache-server" "file-server")

echo "Checking VMs..."
echo ""

for i in "${!VMS[@]}"; do
    VMID="${VMS[$i]}"
    NAME="${VM_NAMES[$i]}"
    
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "VM $VMID: $NAME"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    
    # Check if VM exists
    if ! qm status $VMID &>/dev/null; then
        log_fail "VM does not exist"
        continue
    fi
    
    # Check VM status
    STATUS=$(qm status $VMID | awk '{print $2}')
    if [[ "$STATUS" == "running" ]]; then
        log_success "VM is running"
    else
        log_warning "VM status: $STATUS"
        read -p "Start VM $VMID? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            qm start $VMID
            log_info "Started VM $VMID"
            sleep 10
        fi
    fi
    
    # Check cloud-init configuration
    log_info "Checking cloud-init config..."
    if qm config $VMID | grep -q "ipconfig0"; then
        IP_CONFIG=$(qm config $VMID | grep ipconfig0 | cut -d: -f2-)
        log_success "IP config found: $IP_CONFIG"
    else
        log_fail "No IP configuration found!"
        log_info "This VM needs cloud-init configuration"
        
        read -p "Configure cloud-init for $NAME? (y/n): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            read -p "Enter IP address (e.g., 192.168.1.10): " VM_IP
            read -p "Enter subnet CIDR (e.g., 24): " CIDR
            read -p "Enter gateway (e.g., 192.168.1.1): " GATEWAY
            
            qm set $VMID --ipconfig0 "ip=${VM_IP}/${CIDR},gw=${GATEWAY}"
            qm set $VMID --nameserver "8.8.8.8 8.8.4.4"
            qm set $VMID --ciuser ansible
            qm set $VMID --cipassword changeme
            
            log_success "Cloud-init configured. Restarting VM..."
            qm stop $VMID
            sleep 5
            qm start $VMID
            sleep 30
        fi
    fi
    
    # Check QEMU guest agent
    log_info "Checking QEMU guest agent..."
    if qm agent $VMID ping &>/dev/null; then
        log_success "Guest agent is responding"
        
        # Get network info from guest agent
        log_info "Getting network info from guest..."
        qm guest cmd $VMID network-get-interfaces 2>/dev/null | head -20 || true
    else
        log_fail "Guest agent not responding"
        log_warning "This is usually because:"
        log_warning "  1. qemu-guest-agent not installed in VM"
        log_warning "  2. Cloud-init hasn't finished"
        log_warning "  3. VM is still booting"
        
        # Try to access via console
        log_info "Checking if we can access via network..."
        
        # Extract IP from config
        if qm config $VMID | grep -q "ipconfig0"; then
            VM_IP=$(qm config $VMID | grep ipconfig0 | sed 's/.*ip=\([^,/]*\).*/\1/')
            log_info "Configured IP: $VM_IP"
            
            if ping -c 1 -W 2 $VM_IP &>/dev/null; then
                log_success "VM is pingable at $VM_IP"
                
                # Try SSH
                if timeout 5 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@$VM_IP "echo 'SSH works'" 2>/dev/null; then
                    log_success "SSH connection works!"
                    
                    # Install guest agent
                    log_info "Installing QEMU guest agent..."
                    ssh -o StrictHostKeyChecking=no ansible@$VM_IP "sudo apt-get update && sudo apt-get install -y qemu-guest-agent && sudo systemctl enable --now qemu-guest-agent" || true
                    
                    log_success "Guest agent installed"
                else
                    log_fail "Cannot SSH to $VM_IP"
                    log_info "Possible issues:"
                    log_info "  - SSH not started yet (cloud-init still running)"
                    log_info "  - Wrong credentials"
                    log_info "  - Firewall blocking"
                    
                    log_info "Manual troubleshooting:"
                    echo "  1. Open VM console in Proxmox UI"
                    echo "  2. Login (if possible)"
                    echo "  3. Check: sudo systemctl status cloud-init"
                    echo "  4. Check: sudo cloud-init status"
                    echo "  5. Check: ip addr show"
                    echo "  6. Install agent: sudo apt install qemu-guest-agent"
                fi
            else
                log_fail "VM not pingable at $VM_IP"
                log_warning "Network configuration may not have applied"
                
                echo ""
                log_info "Quick fixes to try:"
                echo "  1. Check VM console for cloud-init errors"
                echo "  2. Verify cloud-init disk is attached (should see ide2)"
                echo "  3. Restart VM: qm stop $VMID && qm start $VMID"
                echo "  4. Check cloud-init logs in VM console:"
                echo "     sudo tail -f /var/log/cloud-init.log"
            fi
        fi
    fi
    
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Diagnostic Summary"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""

echo "Common fixes for cloud-init issues:"
echo ""
echo "1. MISSING IP ADDRESS:"
echo "   qm set <VMID> --ipconfig0 'ip=192.168.1.X/24,gw=192.168.1.1'"
echo "   qm set <VMID> --nameserver '8.8.8.8 8.8.4.4'"
echo "   qm stop <VMID> && qm start <VMID>"
echo ""
echo "2. GUEST AGENT NOT RUNNING:"
echo "   ssh ansible@<VM_IP> 'sudo apt install qemu-guest-agent'"
echo "   ssh ansible@<VM_IP> 'sudo systemctl enable --now qemu-guest-agent'"
echo ""
echo "3. CLOUD-INIT STUCK:"
echo "   - Open VM console in Proxmox"
echo "   - Login and check: sudo cloud-init status"
echo "   - If stuck, run: sudo cloud-init clean && sudo reboot"
echo ""
echo "4. SSH TIMEOUT:"
echo "   - Wait longer (cloud-init takes 3-5 minutes first boot)"
echo "   - Check: sudo systemctl status ssh"
echo "   - Check: sudo systemctl status cloud-init"
echo ""
echo "5. SERIAL CONSOLE STUCK:"
echo "   - This is normal during boot"
echo "   - Switch to Monitor tab in Proxmox"
echo "   - Or use NoVNC console instead"
echo ""

echo "For detailed logs, check in VM console:"
echo "  sudo cat /var/log/cloud-init.log"
echo "  sudo cat /var/log/cloud-init-output.log"
echo "  sudo journalctl -u cloud-init"
echo ""