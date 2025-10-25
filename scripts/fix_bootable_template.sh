#!/bin/bash
#
# Fix Non-Bootable Cloud-Init Template
#
# This script diagnoses and fixes cloud-init templates that have no boot disk,
# which causes VMs to display "no bootable drive" errors.
#
# Usage:
#   ./fix_bootable_template.sh <proxmox_host> <template_name>
#
# Examples:
#   ./fix_bootable_template.sh root@10.100.0.5 ubuntu-22.04-cloudinit
#

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

if [[ $# -lt 2 ]]; then
    echo "Usage: $0 <proxmox_host> <template_name>"
    echo ""
    echo "Examples:"
    echo "  $0 root@10.100.0.5 ubuntu-22.04-cloudinit"
    exit 1
fi

PROXMOX_HOST="$1"
TEMPLATE_NAME="$2"

log_info "╔════════════════════════════════════════════════════════════════╗"
log_info "║  Diagnosing Cloud-Init Template Boot Issues                   ║"
log_info "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Step 1: Find the template VMID
log_info "Step 1: Finding template VMID..."
TEMPLATE_VMID=$(ssh "${PROXMOX_HOST}" "qm list 2>/dev/null | grep -F '${TEMPLATE_NAME}' | awk '{print \$1}'" || echo "")

if [[ -z "${TEMPLATE_VMID}" ]]; then
    log_error "Template '${TEMPLATE_NAME}' not found on ${PROXMOX_HOST}"
    log_info "Available templates:"
    ssh "${PROXMOX_HOST}" "qm list | grep -i template || echo 'No templates found'"
    exit 1
fi

log_success "Found template: VMID ${TEMPLATE_VMID}"
echo ""

# Step 2: Check template configuration
log_info "Step 2: Checking template configuration..."
TEMPLATE_CONFIG=$(ssh "${PROXMOX_HOST}" "qm config ${TEMPLATE_VMID}")

echo "Current Configuration:"
echo "════════════════════════════════════════════════════════════════"
echo "${TEMPLATE_CONFIG}"
echo "════════════════════════════════════════════════════════════════"
echo ""

# Step 3: Check for boot disk
log_info "Step 3: Checking for boot disk..."
BOOT_DISK=$(echo "${TEMPLATE_CONFIG}" | grep -E '^(scsi0|ide0|sata0|virtio0):' | head -1 || echo "")

if [[ -z "${BOOT_DISK}" ]]; then
    log_error "❌ NO BOOT DISK FOUND!"
    log_error "This template has no disk attached, which causes 'no bootable drive' errors."
    echo ""
    
    # Check if disk exists in storage
    log_info "Checking for orphaned disks in storage..."
    STORAGE=$(ssh "${PROXMOX_HOST}" "pvesm status | grep -v DIR | awk 'NR>1 {print \$1}' | head -1")
    log_info "Checking storage: ${STORAGE}"
    
    DISK_SEARCH=$(ssh "${PROXMOX_HOST}" "find /var/lib/vz -name 'vm-${TEMPLATE_VMID}-disk-*' 2>/dev/null || true")
    
    if [[ -n "${DISK_SEARCH}" ]]; then
        log_warning "Found orphaned disk(s):"
        echo "${DISK_SEARCH}"
        echo ""
        log_info "The disk exists but is not attached to the template!"
        log_info "This happens when 'qm importdisk' succeeds but 'qm set --scsi0' fails."
        echo ""
        
        read -p "Attempt to attach existing disk? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            log_info "Attaching disk to template..."
            ssh "${PROXMOX_HOST}" "qm set ${TEMPLATE_VMID} --scsi0 ${STORAGE}:vm-${TEMPLATE_VMID}-disk-0"
            ssh "${PROXMOX_HOST}" "qm set ${TEMPLATE_VMID} --boot order=scsi0"
            log_success "Disk attached successfully!"
            
            # Verify
            NEW_CONFIG=$(ssh "${PROXMOX_HOST}" "qm config ${TEMPLATE_VMID} | grep -E '^scsi0:'")
            log_success "New configuration: ${NEW_CONFIG}"
            exit 0
        fi
    else
        log_error "No disk found for VMID ${TEMPLATE_VMID}"
    fi
    
    echo ""
    log_warning "════════════════════════════════════════════════════════════════"
    log_warning "  TEMPLATE IS BROKEN - MUST BE RECREATED"
    log_warning "════════════════════════════════════════════════════════════════"
    echo ""
    log_info "The template must be deleted and recreated with a valid disk."
    log_info ""
    log_info "To fix this issue:"
    log_info "  1. Delete the broken template"
    log_info "  2. Clean up temporary files"
    log_info "  3. Recreate the template"
    echo ""
    
    read -p "Delete broken template and cleanup? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        log_info "Deleting broken template..."
        ssh "${PROXMOX_HOST}" "qm destroy ${TEMPLATE_VMID} --purge || true"
        log_success "Template deleted"
        
        log_info "Cleaning up temporary files..."
        ssh "${PROXMOX_HOST}" "rm -rf /var/tmp/cloudimg-*"
        log_success "Cleanup complete"
        
        echo ""
        log_success "════════════════════════════════════════════════════════════════"
        log_success "  Cleanup Complete - Ready to Recreate Template"
        log_success "════════════════════════════════════════════════════════════════"
        echo ""
        log_info "Next steps:"
        log_info "  1. Run: ./deploy.sh"
        log_info "     (This will automatically recreate the template)"
        log_info ""
        log_info "  OR if template creation keeps failing:"
        log_info "  1. Download Ubuntu ISO instead:"
        log_info "     ./scripts/download_ubuntu_iso.sh ${PROXMOX_HOST} ${PROXMOX_HOST} local 22.04"
        log_info "  2. Add to config.yaml:"
        log_info "     proxmox:"
        log_info "       ubuntu_iso: 'local:iso/ubuntu-22.04.5-live-server-amd64.iso'"
        log_info "  3. Run: ./deploy.sh"
        exit 0
    else
        log_info "Cleanup cancelled. Template remains broken."
        exit 1
    fi
else
    log_success "✅ Boot disk found: ${BOOT_DISK}"
    
    # Check boot order
    BOOT_ORDER=$(echo "${TEMPLATE_CONFIG}" | grep -E '^boot:' || echo "")
    if [[ -z "${BOOT_ORDER}" ]]; then
        log_warning "⚠️  No boot order configured"
        log_info "Adding boot order configuration..."
        ssh "${PROXMOX_HOST}" "qm set ${TEMPLATE_VMID} --boot order=scsi0"
        log_success "Boot order configured"
    else
        log_success "✅ Boot order configured: ${BOOT_ORDER}"
    fi
    
    echo ""
    log_success "════════════════════════════════════════════════════════════════"
    log_success "  Template is properly configured and bootable!"
    log_success "════════════════════════════════════════════════════════════════"
fi
