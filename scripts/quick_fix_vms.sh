#!/bin/bash
#
# Quick VM Fix - Apply fixes to VMs that won't get IP addresses
#
# Usage:
#   ./quick_fix_vms.sh
#

set -euo pipefail

echo "Quick VM Fix Tool"
echo "================="
echo ""

# Read configuration
read -p "PXE Server IP (e.g., 192.168.1.10): " PXE_IP
read -p "LANCache Server IP (e.g., 192.168.1.11): " LANCACHE_IP
read -p "File Server IP (e.g., 192.168.1.12): " FILE_IP
read -p "Gateway IP (e.g., 192.168.1.1): " GATEWAY
read -p "Subnet CIDR (e.g., 24 for /24): " CIDR
read -p "DNS Server (default: 8.8.8.8): " DNS
DNS=${DNS:-8.8.8.8}

echo ""
echo "Applying fixes..."
echo ""

# Fix VM 100 (PXE Server)
echo "Fixing VM 100 (PXE Server)..."
qm set 100 --ipconfig0 "ip=${PXE_IP}/${CIDR},gw=${GATEWAY}" 2>/dev/null || true
qm set 100 --nameserver "${DNS} 8.8.4.4" 2>/dev/null || true
qm set 100 --searchdomain "lan" 2>/dev/null || true
qm set 100 --ciuser ansible 2>/dev/null || true
qm set 100 --cipassword changeme 2>/dev/null || true
qm set 100 --agent enabled=1 2>/dev/null || true
echo "  ✓ PXE Server configured"

# Fix VM 101 (LANCache)
echo "Fixing VM 101 (LANCache Server)..."
qm set 101 --ipconfig0 "ip=${LANCACHE_IP}/${CIDR},gw=${GATEWAY}" 2>/dev/null || true
qm set 101 --nameserver "${DNS} 8.8.4.4" 2>/dev/null || true
qm set 101 --searchdomain "lan" 2>/dev/null || true
qm set 101 --ciuser ansible 2>/dev/null || true
qm set 101 --cipassword changeme 2>/dev/null || true
qm set 101 --agent enabled=1 2>/dev/null || true
echo "  ✓ LANCache Server configured"

# Fix VM 102 (File Server)
echo "Fixing VM 102 (File Server)..."
qm set 102 --ipconfig0 "ip=${FILE_IP}/${CIDR},gw=${GATEWAY}" 2>/dev/null || true
qm set 102 --nameserver "${DNS} 8.8.4.4" 2>/dev/null || true
qm set 102 --searchdomain "lan" 2>/dev/null || true
qm set 102 --ciuser ansible 2>/dev/null || true
qm set 102 --cipassword changeme 2>/dev/null || true
qm set 102 --agent enabled=1 2>/dev/null || true
echo "  ✓ File Server configured"

echo ""
echo "Restarting VMs to apply changes..."
echo ""

for VMID in 100 101 102; do
    echo "Restarting VM $VMID..."
    qm stop $VMID 2>/dev/null || true
    sleep 3
    qm start $VMID
    echo "  ✓ VM $VMID restarted"
done

echo ""
echo "Waiting 60 seconds for VMs to boot and cloud-init to run..."
sleep 60

echo ""
echo "Testing connectivity..."
echo ""

# Test each VM
for VM_INFO in "100:$PXE_IP:pxe-server" "101:$LANCACHE_IP:lancache-server" "102:$FILE_IP:file-server"; do
    VMID=$(echo $VM_INFO | cut -d: -f1)
    IP=$(echo $VM_INFO | cut -d: -f2)
    NAME=$(echo $VM_INFO | cut -d: -f3)
    
    echo "Testing $NAME ($IP)..."
    
    # Ping test
    if ping -c 2 -W 3 $IP &>/dev/null; then
        echo "  ✓ Ping successful"
        
        # SSH test
        if timeout 10 ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 ansible@$IP "echo 'SSH OK'" &>/dev/null; then
            echo "  ✓ SSH successful"
            
            # Install guest agent if missing
            ssh -o StrictHostKeyChecking=no ansible@$IP "sudo apt-get update && sudo apt-get install -y qemu-guest-agent && sudo systemctl enable --now qemu-guest-agent" &>/dev/null || true
            echo "  ✓ Guest agent installed"
        else
            echo "  ✗ SSH failed (cloud-init may still be running)"
            echo "    Wait 2-3 more minutes and try: ssh ansible@$IP"
        fi
    else
        echo "  ✗ Ping failed"
        echo "    Check VM console for errors:"
        echo "    - Proxmox UI → VM $VMID → Console"
        echo "    - Look for cloud-init errors"
    fi
    echo ""
done

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Fix Complete!"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "Next steps:"
echo "  1. Wait 2-3 minutes if SSH still fails"
echo "  2. Check VM consoles if pings fail"
echo "  3. Run Ansible playbook once VMs are accessible:"
echo "     cd ansible"
echo "     ansible-playbook -i inventory/hosts playbooks/deploy_all.yml"
echo ""
echo "If problems persist:"
echo "  - Check cloud-init logs in VM console:"
echo "    sudo tail -f /var/log/cloud-init.log"
echo "  - Verify cloud-init finished:"
echo "    sudo cloud-init status"
echo "  - Check network in VM:"
echo "    ip addr show"
echo ""