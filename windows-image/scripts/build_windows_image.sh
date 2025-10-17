#!/bin/bash
#
# Windows Image Builder - Main Orchestration Script
# High School Esports LAN Infrastructure
#
# This script orchestrates the entire Windows image building process
#
# Usage:
#   ./build_windows_image.sh [--update]
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

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Configuration
ISO_PATH="$PROJECT_ROOT/windows-image/iso"
OUTPUT_PATH="$PROJECT_ROOT/windows-image/output"
CONFIG_FILE="$PROJECT_ROOT/config.yaml"

# Parse arguments
UPDATE_MODE=false
if [[ "${1:-}" == "--update" ]]; then
    UPDATE_MODE=true
fi

banner() {
    cat << "EOF"
╔═══════════════════════════════════════════════════════════╗
║  Windows 11 Image Builder                                 ║
║  High School Esports LAN Infrastructure                   ║
╚═══════════════════════════════════════════════════════════╝
EOF
    echo ""
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    local missing=()
    
    # Check for required tools
    if ! command -v qm &> /dev/null; then
        missing+=("Proxmox (qm command not found)")
    fi
    
    if ! command -v ansible &> /dev/null; then
        missing+=("Ansible")
    fi
    
    if ! command -v python3 &> /dev/null; then
        missing+=("Python 3")
    fi
    
    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools:"
        for tool in "${missing[@]}"; do
            echo "  - $tool"
        done
        exit 1
    fi
    
    log_success "All prerequisites met"
}

download_windows_iso() {
    log_info "Checking for Windows 11 ISO..."
    
    mkdir -p "$ISO_PATH"
    
    if [[ -f "$ISO_PATH/windows11.iso" ]]; then
        log_success "Windows 11 ISO found"
        return 0
    fi
    
    log_warning "Windows 11 ISO not found"
    echo ""
    echo "Please download Windows 11 ISO from:"
    echo "  https://www.microsoft.com/software-download/windows11"
    echo ""
    echo "Save it to: $ISO_PATH/windows11.iso"
    echo ""
    read -p "Press Enter when ISO is ready, or Ctrl+C to cancel..."
    
    if [[ ! -f "$ISO_PATH/windows11.iso" ]]; then
        log_error "ISO file not found at $ISO_PATH/windows11.iso"
        exit 1
    fi
    
    log_success "Windows 11 ISO ready"
}

create_builder_vm() {
    log_info "Creating Windows builder VM..."
    
    # VM ID (high number to avoid conflicts)
    VMID=9999
    
    # Check if VM already exists
    if qm status $VMID &> /dev/null; then
        log_warning "Builder VM already exists (ID: $VMID)"
        read -p "Destroy and recreate? (yes/no): " -r
        if [[ $REPLY == "yes" ]]; then
            log_info "Destroying existing VM..."
            qm stop $VMID || true
            qm destroy $VMID
        else
            log_info "Using existing VM"
            return 0
        fi
    fi
    
    log_info "Creating new VM (ID: $VMID)..."
    
    # Create VM
    qm create $VMID \
        --name "windows-builder" \
        --memory 16384 \
        --cores 4 \
        --net0 virtio,bridge=vmbr0 \
        --scsihw virtio-scsi-pci \
        --scsi0 local-lvm:200 \
        --ide2 local:iso/windows11.iso,media=cdrom \
        --ostype win11 \
        --boot order=ide2 \
        --agent 1
    
    log_success "Builder VM created (ID: $VMID)"
    
    # Start VM
    log_info "Starting builder VM..."
    qm start $VMID
    
    log_info "Windows installation will begin automatically"
    log_info "This takes 30-45 minutes..."
    log_success "Builder VM started"
}

wait_for_installation() {
    log_info "Waiting for Windows installation to complete..."
    log_info "This may take 30-60 minutes"
    echo ""
    echo "Monitor progress:"
    echo "  - Proxmox web UI: https://proxmox:8006"
    echo "  - VM Console (ID: 9999)"
    echo ""
    echo "Installation stages:"
    echo "  1. Windows Setup (15-20 min)"
    echo "  2. First boot and OOBE (5-10 min)"
    echo "  3. Auto-logon as buildadmin (automatic)"
    echo "  4. FirstLogonCommands run (10-15 min)"
    echo "  5. Ready for configuration"
    echo ""
    
    # Poll for completion marker
    local attempts=0
    local max_attempts=120  # 2 hours max
    
    while [[ $attempts -lt $max_attempts ]]; do
        # Check if optimization script created its report
        # (This would require guest agent or SSH access)
        # For now, we'll wait for user confirmation
        
        attempts=$((attempts + 1))
        sleep 60  # Check every minute
        
        # Every 10 minutes, prompt user
        if [[ $((attempts % 10)) -eq 0 ]]; then
            echo ""
            read -p "Is Windows installation complete? (yes/no/cancel): " -r
            case $REPLY in
                yes)
                    log_success "Installation complete"
                    return 0
                    ;;
                cancel)
                    log_error "Build cancelled by user"
                    exit 1
                    ;;
                *)
                    log_info "Continuing to wait..."
                    ;;
            esac
        fi
    done
    
    log_error "Installation timeout (2 hours)"
    exit 1
}

run_configuration_scripts() {
    log_info "Running configuration scripts on builder VM..."
    
    # At this point, scripts should have run via FirstLogonCommands
    # in autounattend.xml
    
    log_info "Scripts run automatically via autounattend.xml:"
    echo "  1. optimize.ps1 - Windows optimizations"
    echo "  2. install_apps.ps1 - Install game clients"
    echo "  3. configure_profiles.ps1 - Configure roaming profiles"
    echo ""
    
    log_info "Verify scripts completed successfully in VM console"
    read -p "Are all scripts complete? (yes/no): " -r
    
    if [[ $REPLY != "yes" ]]; then
        log_error "Scripts not complete. Check VM console for errors."
        exit 1
    fi
    
    log_success "Configuration scripts completed"
}

sysprep_and_capture() {
    log_info "Preparing to sysprep and capture image..."
    
    echo ""
    echo "Manual steps required:"
    echo "  1. Connect to VM console"
    echo "  2. Run: C:\Windows\System32\Sysprep\sysprep.exe"
    echo "  3. Select:"
    echo "     - System Cleanup Action: Enter System Out-of-Box Experience (OOBE)"
    echo "     - Generalize: Checked"
    echo "     - Shutdown Options: Shutdown"
    echo "  4. Click OK"
    echo "  5. VM will shutdown when complete (takes 5-10 minutes)"
    echo ""
    
    read -p "Press Enter when you've started Sysprep..." -r
    
    log_info "Waiting for VM to shutdown..."
    
    # Wait for VM to stop
    local attempts=0
    while [[ $attempts -lt 60 ]]; do
        if ! qm status 9999 | grep -q "running"; then
            log_success "VM shutdown complete"
            break
        fi
        sleep 10
        attempts=$((attempts + 1))
    done
    
    if qm status 9999 | grep -q "running"; then
        log_error "VM did not shutdown. Check sysprep status."
        exit 1
    fi
    
    log_info "Capturing image..."
    
    # Export VM disk
    mkdir -p "$OUTPUT_PATH"
    
    log_info "Exporting VM disk to WIM format..."
    log_warning "This requires Windows tools (DISM) on a Windows machine"
    echo ""
    echo "On a Windows machine with DISM:"
    echo "  1. Mount the VM disk (use Proxmox backup/export)"
    echo "  2. Run: dism /Capture-Image /ImageFile:install.wim /CaptureDir:E:\ /Name:\"Windows 11 Esports\" /Description:\"Tournament Image\" /Compress:max"
    echo "  3. Copy install.wim to: $OUTPUT_PATH/"
    echo ""
    
    read -p "Press Enter when WIM file is ready at $OUTPUT_PATH/install.wim..." -r
    
    if [[ ! -f "$OUTPUT_PATH/install.wim" ]]; then
        log_error "install.wim not found at $OUTPUT_PATH/"
        exit 1
    fi
    
    log_success "Image captured successfully"
}

deploy_to_ipxe() {
    log_info "Deploying image to iPXE server..."
    
    # Get iPXE server IP from config
    local ipxe_ip=$(python3 -c "import yaml; print(yaml.safe_load(open('$CONFIG_FILE'))['network']['ipxe_server_ip'])")
    
    log_info "Copying image to iPXE server ($ipxe_ip)..."
    
    scp "$OUTPUT_PATH/install.wim" "ansible@$ipxe_ip:/srv/images/windows11/"
    
    log_success "Image deployed to iPXE server"
    
    # Also need boot.wim from Windows ISO
    log_info "Extracting boot files from ISO..."
    log_warning "Manual step: Extract boot.wim from ISO sources folder"
    echo ""
    echo "Copy from ISO:"
    echo "  - sources/boot.wim → /srv/images/windows11/sources/boot.wim"
    echo "  - Boot/BCD → /srv/images/windows11/Boot/BCD"
    echo "  - bootmgr.exe → /srv/images/windows11/bootmgr.exe"
    echo ""
    
    read -p "Press Enter when boot files are copied..." -r
}

cleanup() {
    log_info "Cleaning up..."
    
    read -p "Delete builder VM? (yes/no): " -r
    if [[ $REPLY == "yes" ]]; then
        log_info "Deleting builder VM..."
        qm destroy 9999
        log_success "Builder VM deleted"
    else
        log_info "Builder VM kept (ID: 9999)"
    fi
    
    if [[ $UPDATE_MODE == true ]]; then
        # Backup old image
        if [[ -f "$OUTPUT_PATH/install.wim.old" ]]; then
            rm "$OUTPUT_PATH/install.wim.old"
        fi
        if [[ -f "$OUTPUT_PATH/install.wim" ]]; then
            mv "$OUTPUT_PATH/install.wim" "$OUTPUT_PATH/install.wim.old"
        fi
    fi
    
    log_success "Cleanup complete"
}

show_summary() {
    cat << EOF

${GREEN}========================================
Windows Image Build Complete!
========================================${NC}

Image Location: $OUTPUT_PATH/install.wim
Deployed to: iPXE Server

Next Steps:
1. Test image on one client machine:
   - PXE boot
   - Select "Boot Windows 11"
   - Verify image loads
   - Test roaming profile
   - Install a game via LANCache

2. If successful, deploy to all machines

3. Create user accounts on file server:
   ssh ansible@192.168.1.12
   sudo create-bulk-users player 200 password123

Testing Checklist:
- [ ] Image boots successfully
- [ ] All game clients present
- [ ] Discord/TeamSpeak installed
- [ ] Roaming profile loads
- [ ] G: drive accessible
- [ ] LANCache DNS working
- [ ] Steam downloads games
- [ ] Profile persists after reboot

Troubleshooting:
- Image won't boot: Check boot files in /srv/images/windows11/
- Profile won't load: Test file server connection
- LANCache not working: Check DNS settings

Image Details:
- Windows 11 Pro
- Pre-installed: Steam, Epic, Riot, Discord, TeamSpeak
- Roaming profiles: Enabled
- Folder redirection: Configured
- Optimizations: Applied

Build Time: ~2-4 hours
Image Size: ~12-15GB compressed

EOF
}

main() {
    banner
    
    check_prerequisites
    download_windows_iso
    
    if [[ $UPDATE_MODE == true ]]; then
        log_info "Running in UPDATE mode"
    fi
    
    create_builder_vm
    wait_for_installation
    run_configuration_scripts
    sysprep_and_capture
    deploy_to_ipxe
    cleanup
    show_summary
    
    log_success "Build process complete!"
    exit 0
}

# Error handler
trap 'log_error "An error occurred. Check the output above."; exit 1' ERR

main "$@"