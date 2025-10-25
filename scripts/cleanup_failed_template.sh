#!/bin/bash
#
# Cleanup failed cloud-init template creation
#
# This script removes corrupted cloud images and failed template VMs
# from a Proxmox host to allow retrying template creation.
#
# Usage:
#   ./cleanup_failed_template.sh <proxmox_host> [vmid]
#
# Examples:
#   ./cleanup_failed_template.sh root@10.100.0.5
#   ./cleanup_failed_template.sh root@10.100.0.5 101
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

if [[ $# -lt 1 ]]; then
    echo "Usage: $0 <proxmox_host> [vmid]"
    echo ""
    echo "Examples:"
    echo "  $0 root@10.100.0.5          # Clean all cloudimg temp directories"
    echo "  $0 root@10.100.0.5 101      # Clean specific VMID and its temp files"
    exit 1
fi

PROXMOX_HOST="$1"
VMID="${2:-}"

log_info "Cleaning up failed template creation on ${PROXMOX_HOST}"

# If VMID specified, clean that specific VM and temp dir
if [[ -n "${VMID}" ]]; then
    log_info "Cleaning VMID ${VMID}..."
    
    # Check if VM exists
    if ssh "${PROXMOX_HOST}" "qm status ${VMID} >/dev/null 2>&1"; then
        log_warning "VM ${VMID} exists. Destroying it..."
        ssh "${PROXMOX_HOST}" "qm destroy ${VMID} --purge || true"
        log_success "VM ${VMID} destroyed"
    else
        log_info "VM ${VMID} does not exist (already cleaned)"
    fi
    
    # Clean temp directory
    log_info "Removing temporary files for VMID ${VMID}..."
    ssh "${PROXMOX_HOST}" "rm -rf /var/tmp/cloudimg-${VMID}" || true
    log_success "Temporary files removed"
else
    # Clean all cloudimg-* directories
    log_info "Searching for all cloudimg temporary directories..."
    TEMP_DIRS=$(ssh "${PROXMOX_HOST}" "ls -d /var/tmp/cloudimg-* 2>/dev/null || true")
    
    if [[ -z "${TEMP_DIRS}" ]]; then
        log_info "No temporary cloudimg directories found"
    else
        log_warning "Found temporary directories:"
        echo "${TEMP_DIRS}"
        echo ""
        read -p "Delete all these directories? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            ssh "${PROXMOX_HOST}" "rm -rf /var/tmp/cloudimg-*" || true
            log_success "All temporary directories removed"
        else
            log_info "Cleanup cancelled"
        fi
    fi
fi

log_success "Cleanup complete! You can now retry template creation."
